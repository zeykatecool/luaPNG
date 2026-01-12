--png.lua
local Png = {}
Png.__index = Png
local bit = require("bit32")
local DEFLATE_MAX_BLOCK_SIZE = 65535

if unpack == nil then
    unpack = table.unpack
end


local crc_table = {}
for i = 0, 255 do
    local c = i
    for j = 0, 7 do
        if bit.band(c, 1) == 1 then
            c = bit.bxor(bit.rshift(c, 1), 0xEDB88320)
        else
            c = bit.rshift(c, 1)
        end
    end
    crc_table[i] = c
end

local band, bxor, rshift, lshift, bnot = bit.band, bit.bxor, bit.rshift, bit.lshift, bit.bnot
local min, ceil = math.min, math.ceil
local string_char = string.char

local function putBigUint32(val, tbl, index)
    tbl[index] = band(rshift(val, 24), 0xFF)
    tbl[index + 1] = band(rshift(val, 16), 0xFF)
    tbl[index + 2] = band(rshift(val, 8), 0xFF)
    tbl[index + 3] = band(val, 0xFF)
end

local WRITE_BUFFER_SIZE = 32768 
function Png:writeBytes(data, index, len)
    index = index or 1
    len = len or #data

    local output = self.output
    local buffer = self.write_buffer
    local buffer_pos = self.buffer_pos

    local end_idx = index + len - 1
    local i = index

    while i <= end_idx do
        local available_buffer = WRITE_BUFFER_SIZE - buffer_pos
        local chunk_size = min(available_buffer, end_idx - i + 1)

        for j = 0, chunk_size - 1 do
            buffer[buffer_pos + j + 1] = data[i + j]
        end

        buffer_pos = buffer_pos + chunk_size
        i = i + chunk_size

        if buffer_pos >= WRITE_BUFFER_SIZE or i > end_idx then

            output[#output + 1] = string_char(unpack(buffer, 1, buffer_pos))
            buffer_pos = 0
        end
    end

    self.buffer_pos = buffer_pos
end

function Png:crc32(data, index, len)
    local crc = bnot(self.crc)
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

    self.crc = bnot(crc)
end

function Png:adler32(data, index, len)
    local s1 = band(self.adler, 0xFFFF)
    local s2 = rshift(self.adler, 16)

    local pos = index
    local remaining = len

    while remaining > 0 do
        local current_chunk = min(5552, remaining)
        local end_pos = pos + current_chunk - 1

        local i = pos
        while i <= end_pos - 7 do
            local sum = data[i] + data[i+1] + data[i+2] + data[i+3] + 
                       data[i+4] + data[i+5] + data[i+6] + data[i+7]
            s1 = s1 + sum
            s2 = s2 + s1 * 8 - (data[i] * 7 + data[i+1] * 6 + data[i+2] * 5 + 
                                data[i+3] * 4 + data[i+4] * 3 + data[i+5] * 2 + data[i+6])
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

    self.adler = bit.bor(lshift(s2, 16), s1)
end

function Png:write(pixels)
    local count = #pixels
    local pixelPointer = 1
    local lineSize = self.lineSize
    local uncompRemain = self.uncompRemain
    local deflateFilled = self.deflateFilled
    local positionX = self.positionX
    local positionY = self.positionY
    local height = self.height

    local filterByte = self.filterByte or {0}
    self.filterByte = filterByte

    while count > 0 do
        if deflateFilled == 0 then
            local size = min(DEFLATE_MAX_BLOCK_SIZE, uncompRemain)
            local isLast = (uncompRemain <= DEFLATE_MAX_BLOCK_SIZE) and 1 or 0

            local header = self.header_buffer or {}
            header[1] = band(isLast, 0xFF)
            header[2] = band(size, 0xFF)
            header[3] = band(rshift(size, 8), 0xFF)
            header[4] = band(bxor(size, 0xFF), 0xFF)
            header[5] = band(bxor(rshift(size, 8), 0xFF), 0xFF)
            self.header_buffer = header

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
                    output[#output + 1] = string_char(unpack(self.write_buffer, 1, self.buffer_pos))
                end

                local footer = {
                    0, 0, 0, 0,  
                    0, 0, 0, 0,  
                    0x00, 0x00, 0x00, 0x00,  
                    0x49, 0x45, 0x4E, 0x44,  
                    0xAE, 0x42, 0x60, 0x82,  
                }
                putBigUint32(self.adler, footer, 1)
                self:crc32(footer, 1, 4)
                putBigUint32(self.crc, footer, 5)
                self:writeBytes(footer)
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

local PNG_SIGNATURE = {0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A}
local IHDR_TYPE = {0x49, 0x48, 0x44, 0x52}
local IDAT_TYPE = {0x49, 0x44, 0x41, 0x54}
local DEFLATE_HEADER = {0x08, 0x1D}

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

        write_buffer = {},
        buffer_pos = 0,
    }, Png)

    for i = 1, WRITE_BUFFER_SIZE do
        state.write_buffer[i] = 0
    end

    state.uncompRemain = state.lineSize * height
    local numBlocks = ceil(state.uncompRemain / DEFLATE_MAX_BLOCK_SIZE)
    local idatSize = numBlocks * 5 + 6 + state.uncompRemain

    local header = {}
    local idx = 1

    for i = 1, 8 do
        header[idx] = PNG_SIGNATURE[i]
        idx = idx + 1
    end

    header[idx] = 0x00; header[idx+1] = 0x00; header[idx+2] = 0x00; header[idx+3] = 0x0D
    idx = idx + 4

    for i = 1, 4 do
        header[idx] = IHDR_TYPE[i]
        idx = idx + 1
    end

    for i = 1, 8 do
        header[idx] = 0
        idx = idx + 1
    end

    header[idx] = 0x08; header[idx+1] = colorType; header[idx+2] = 0x00
    header[idx+3] = 0x00; header[idx+4] = 0x00
    idx = idx + 5

    for i = 1, 4 do
        header[idx] = 0
        idx = idx + 1
    end

    for i = 1, 4 do
        header[idx] = 0
        idx = idx + 1
    end

    for i = 1, 4 do
        header[idx] = IDAT_TYPE[i]
        idx = idx + 1
    end

    header[idx] = DEFLATE_HEADER[1]
    header[idx+1] = DEFLATE_HEADER[2]

    putBigUint32(width, header, 17)
    putBigUint32(height, header, 21)
    putBigUint32(idatSize, header, 34)

    state:crc32(header, 13, 17)
    putBigUint32(state.crc, header, 30)
    state:writeBytes(header)

    state.crc = 0
    state:crc32(header, 38, 6)

    return state
end

function Png:getData()
    return table.concat(self.output)
end

return begin