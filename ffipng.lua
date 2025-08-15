--ffipng.lua
local ffi = require("ffi")
local bit = require("bit")

local Png = {}
Png.__index = Png

local DEFLATE_MAX_BLOCK_SIZE = 65535
local WRITE_BUFFER_SIZE = 32768

local band, bxor, rshift, lshift, bnot, bor = bit.band, bit.bxor, bit.rshift, bit.lshift, bit.bnot, bit.bor
local min, ceil = math.min, math.ceil
local ffi_cast = ffi.cast

local crc_table = ffi.new("uint32_t[256]")
for i = 0, 255 do
    local c = i
    for j = 0, 7 do
        if band(c, 1) == 1 then
            c = bxor(rshift(c, 1), 0xEDB88320)
        else
            c = rshift(c, 1)
        end
    end
    crc_table[i] = c
end

local function putBigUint32(val, buf, offset)
    buf[offset] = band(rshift(val, 24), 0xFF)
    buf[offset + 1] = band(rshift(val, 16), 0xFF)
    buf[offset + 2] = band(rshift(val, 8), 0xFF)
    buf[offset + 3] = band(val, 0xFF)
end

---Writes bytes to the output buffer
---@param data userdata|table The data to write
---@param index number|nil The index of the first byte to write
---@param len number|nil The number of bytes to write
function Png:writeBytes(data, index, len)
    index = index or 1
    len = len or #data

    local output = self.output
    local buffer = self.write_buffer
    local buffer_pos = self.buffer_pos

    if type(data) == "table" then
        local end_idx = index + len - 1
        local i = index

        while i <= end_idx do
            local available_buffer = WRITE_BUFFER_SIZE - buffer_pos
            local chunk_size = min(available_buffer, end_idx - i + 1)

            for j = 0, chunk_size - 1 do
                buffer[buffer_pos + j] = data[i + j]
            end

            buffer_pos = buffer_pos + chunk_size
            i = i + chunk_size

            if buffer_pos >= WRITE_BUFFER_SIZE or i > end_idx then
                output[#output + 1] = ffi.string(buffer, buffer_pos)
                buffer_pos = 0
            end
        end
    else
        output[#output + 1] = ffi.string(ffi_cast("uint8_t*", data) + index - 1, len)
    end

    self.buffer_pos = buffer_pos
end

---Initializes the CRC
function Png:initCrc()
    self.crc = 0xFFFFFFFF
end

---Updates the CRC
---@param data userdata|table The data to update the CRC with
---@param index number|nil The index of the first byte to update
---@param len number|nil The number of bytes to update
function Png:crc32(data, index, len)
    local crc = self.crc

    if type(data) == "table" then
        local end_idx = index + len - 1
        local i = index

        while i <= end_idx - 15 do
            for j = 0, 15 do
                crc = bxor(rshift(crc, 8), crc_table[band(bxor(crc, data[i + j]), 0xFF)])
            end
            i = i + 16
        end

        while i <= end_idx do
            crc = bxor(rshift(crc, 8), crc_table[band(bxor(crc, data[i]), 0xFF)])
            i = i + 1
        end
    else
        local ptr = ffi_cast("uint8_t*", data) + index - 1
        for i = 0, len - 1 do
            crc = bxor(rshift(crc, 8), crc_table[band(bxor(crc, ptr[i]), 0xFF)])
        end
    end

    self.crc = bnot(crc)
end

---Finalizes the CRC, returning the result
function Png:finalizeCrc()
    return self.crc
end

---Updates the Adler32
---@param data userdata|table The data to update the Adler32 with
---@param index number|nil The index of the first byte to update
---@param len number|nil The number of bytes to update
function Png:adler32(data, index, len)
    local s1 = band(self.adler, 0xFFFF)
    local s2 = rshift(self.adler, 16)

    if type(data) == "table" then
        local pos = index
        local remaining = len

        while remaining > 0 do
            local current_chunk = min(5552, remaining)
            local end_pos = pos + current_chunk - 1

            local i = pos
            while i <= end_pos - 7 do
                local sum = data[i] + data[i + 1] + data[i + 2] + data[i + 3] +
                    data[i + 4] + data[i + 5] + data[i + 6] + data[i + 7]
                s1 = s1 + sum
                s2 = s2 + s1 * 8 - (data[i] * 7 + data[i + 1] * 6 + data[i + 2] * 5 +
                    data[i + 3] * 4 + data[i + 4] * 3 + data[i + 5] * 2 + data[i + 6])
                i = i + 8
            end

            while i <= end_pos do
                s1 = s1 + data[i]
                s2 = s2 + s1
                i = i + 1
            end

            s1 = s1 % 65521
            s2 = s2 % 65521

            pos = end_pos + 1
            remaining = remaining - current_chunk
        end
    else
        local ptr = ffi_cast("uint8_t*", data) + index - 1
        for i = 0, len - 1 do
            s1 = (s1 + ptr[i]) % 65521
            s2 = (s2 + s1) % 65521
        end
    end

    self.adler = bor(lshift(s2, 16), s1)
end

---Writes pixels to the PNG file
---@param pixels table The pixels to write
function Png:write(pixels)
    local count = #pixels
    local pixelPointer = 1
    local lineSize = self.lineSize
    local uncompRemain = self.uncompRemain
    local deflateFilled = self.deflateFilled
    local positionX = self.positionX
    local positionY = self.positionY
    local height = self.height

    local filterByte = self.filterByte or { 0 }
    local header = self.header_buffer or {}
    self.filterByte = filterByte
    self.header_buffer = header

    while count > 0 and not self.done do
        if deflateFilled == 0 then
            local size = min(DEFLATE_MAX_BLOCK_SIZE, uncompRemain)
            local isLast = (uncompRemain <= DEFLATE_MAX_BLOCK_SIZE) and 1 or 0

            header[1] = band(isLast, 0xFF)
            header[2] = band(size, 0xFF)
            header[3] = band(rshift(size, 8), 0xFF)
            header[4] = band(bxor(size, 0xFFFF), 0xFF)
            header[5] = band(rshift(bxor(size, 0xFFFF), 8), 0xFF)

            self:writeBytes(header, 1, 5)
            self:crc32(header, 1, 5)
        end

        if positionX == 0 then
            self:writeBytes(filterByte)
            self:crc32(filterByte, 1, 1)
            self:adler32(filterByte, 1, 1)
            positionX = 1
            uncompRemain = uncompRemain - 1
            deflateFilled = deflateFilled + 1
        else
            local n = min(
                DEFLATE_MAX_BLOCK_SIZE - deflateFilled,
                lineSize - positionX,
                count
            )

            self:writeBytes(pixels, pixelPointer, n)
            self:crc32(pixels, pixelPointer, n)
            self:adler32(pixels, pixelPointer, n)

            count = count - n
            pixelPointer = pixelPointer + n
            positionX = positionX + n
            uncompRemain = uncompRemain - n
            deflateFilled = deflateFilled + n
        end

        if deflateFilled >= DEFLATE_MAX_BLOCK_SIZE then
            deflateFilled = 0
        end

        if positionX == lineSize then
            positionX = 0
            positionY = positionY + 1

            if positionY == height then
                if self.buffer_pos > 0 then
                    local output = self.output
                    output[#output + 1] = ffi.string(self.write_buffer, self.buffer_pos)
                end

                local footer = self.footer_buffer or {}
                putBigUint32(self.adler, footer, 1)
                self:crc32(footer, 1, 4)
                local final_crc = self:finalizeCrc()
                putBigUint32(final_crc, footer, 5)

                footer[9] = 0x00; footer[10] = 0x00; footer[11] = 0x00; footer[12] = 0x00
                footer[13] = 0x49; footer[14] = 0x45; footer[15] = 0x4E; footer[16] = 0x44
                footer[17] = 0xAE; footer[18] = 0x42; footer[19] = 0x60; footer[20] = 0x82

                self:writeBytes(footer, 1, 8)
                self:writeBytes(footer, 9, 12)

                self.footer_buffer = footer
                self.done = true
                break
            end
        end
    end

    self.uncompRemain = uncompRemain
    self.deflateFilled = deflateFilled
    self.positionX = positionX
    self.positionY = positionY
end

local PNG_SIGNATURE = ffi.new("uint8_t[8]", { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A })
local IHDR_TYPE = ffi.new("uint8_t[4]", { 0x49, 0x48, 0x44, 0x52 })
local IDAT_TYPE = ffi.new("uint8_t[4]", { 0x49, 0x44, 0x41, 0x54 })
local DEFLATE_HEADER = ffi.new("uint8_t[2]", { 0x08, 0x1D })

local function begin(width, height, colorMode)
    colorMode = colorMode or "rgb"

    local bytesPerPixel, colorType
    if colorMode == "rgb" then
        bytesPerPixel, colorType = 3, 2
    elseif colorMode == "rgba" then
        bytesPerPixel, colorType = 4, 6
    else
        error("Invalid colorMode: " .. tostring(colorMode))
    end

    local state = setmetatable({
        width = width,
        height = height,
        done = false,
        output = {},
        lineSize = width * bytesPerPixel + 1,
        positionX = 0,
        positionY = 0,
        deflateFilled = 0,
        crc = 0,
        adler = 1,

        write_buffer = ffi.new("uint8_t[?]", WRITE_BUFFER_SIZE),
        buffer_pos = 0,
    }, Png)

    state.uncompRemain = state.lineSize * height
    local numBlocks = ceil(state.uncompRemain / DEFLATE_MAX_BLOCK_SIZE)
    local idatSize = numBlocks * 5 + 6 + state.uncompRemain

    local header = {}
    local idx = 1

    for i = 0, 7 do
        header[idx] = PNG_SIGNATURE[i]
        idx = idx + 1
    end

    putBigUint32(13, header, idx)
    idx = idx + 4

    for i = 0, 3 do
        header[idx] = IHDR_TYPE[i]
        idx = idx + 1
    end

    putBigUint32(width, header, idx)
    idx = idx + 4
    putBigUint32(height, header, idx)
    idx = idx + 4

    header[idx] = 8
    header[idx + 1] = colorType
    header[idx + 2] = 0
    header[idx + 3] = 0
    header[idx + 4] = 0
    idx = idx + 5

    state:initCrc()
    state:crc32(header, 13, 17)
    local ihdr_crc = state:finalizeCrc()

    putBigUint32(ihdr_crc, header, idx)
    idx = idx + 4

    putBigUint32(idatSize, header, idx)
    idx = idx + 4

    for i = 0, 3 do
        header[idx] = IDAT_TYPE[i]
        idx = idx + 1
    end

    header[idx] = DEFLATE_HEADER[0]
    header[idx + 1] = DEFLATE_HEADER[1]

    state:writeBytes(header)

    state:initCrc()
    state:crc32(header, idx - 4, 6)

    return state
end

---Returns the PNG data to be written to a file
function Png:getData()
    return table.concat(self.output)
end

---Creates a new Png object
---@param width number
---@param height number
---@param colorMode string One of "rgb" or "rgba"
function Png.new(width, height, colorMode)
    return begin(width, height, colorMode)
end

return begin