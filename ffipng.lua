--ffipng.lua
local ffi = require("ffi")
local bit = require("bit")

local PNG = {}
PNG.__index = PNG


local b_and, b_xor, b_shr, b_shl, b_not, b_or = bit.band, bit.bxor, bit.rshift, bit.lshift, bit.bnot, bit.bor
local m_min, m_ceil = math.min, math.ceil
local f_cast = ffi.cast

local CRC_LOOKUP = ffi.new("uint32_t[256]")
for i = 0, 255 do
    local c = i
    for j = 0, 7 do
        if b_and(c, 1) == 1 then
            c = b_xor(b_shr(c, 1), 0xEDB88320)
        else
            c = b_shr(c, 1)
        end
    end
    CRC_LOOKUP[i] = c
end

local MAX_BLOCK = 65535
local IO_CHUNK = 32768

local function pack32(val, buf, off)
    buf[off] = b_and(b_shr(val, 24), 0xFF)
    buf[off + 1] = b_and(b_shr(val, 16), 0xFF)
    buf[off + 2] = b_and(b_shr(val, 8), 0xFF)
    buf[off + 3] = b_and(val, 0xFF)
end

local TEXT = { 0x74, 0x45, 0x58, 0x74 }

local function writeTextChunk(ctx, keyword, value)
    if value == nil then return end
    if type(value) ~= "string" then value = tostring(value) end
    if type(keyword) ~= "string" then keyword = tostring(keyword) end
    local data = {}
    local k = 1

    for i = 1, #keyword do
        data[k] = string.byte(keyword, i)
        k = k + 1
    end
    data[k] = 0x00
    k = k + 1
    for i = 1, #value do
        data[k] = string.byte(value, i)
        k = k + 1
    end

    local len = #data
    local chunk = {}
    local j = 1

    pack32(len, chunk, j); j = j + 4
    for i = 1, 4 do
        chunk[j] = TEXT[i]; j = j + 1
    end
    for i = 1, len do
        chunk[j] = data[i]; j = j + 1
    end

    ctx:initCrc()
    ctx:crc32(chunk, 5, 4 + len)
    pack32(ctx.crc_val, chunk, j)
    j = j + 4

    ctx:writeBytes(chunk, 1, j - 1)
end


---Writes bytes to the output buffer
---@param src userdata|table The data to write
---@param start number|nil The index of the first byte to write
---@param size number|nil The number of bytes to write
function PNG:writeBytes(src, start, size)
    start = start or 1
    if not size then
        if type(src) == "table" then
            size = #src
        else
            size = ffi.sizeof(src)
        end
    end

    local out = self.chunks
    local buf = self.w_buf
    local ptr = self.w_ptr

    if type(src) == "table" then
        local stop = start + size - 1
        local i = start

        while i <= stop do
            local space = IO_CHUNK - ptr
            local step = m_min(space, stop - i + 1)

            for j = 0, step - 1 do
                buf[ptr + j] = src[i + j]
            end

            ptr = ptr + step
            i = i + step

            if ptr >= IO_CHUNK or i > stop then
                out[#out + 1] = ffi.string(buf, ptr)
                ptr = 0
            end
        end
    else
        out[#out + 1] = ffi.string(f_cast("uint8_t*", src) + start - 1, size)
    end

    self.w_ptr = ptr
end

---Initializes the CRC
function PNG:initCrc()
    self.crc_val = 0xFFFFFFFF
end

---Updates the CRC
---@param src userdata|table The data to update the CRC with
---@param start number|nil The index of the first byte to update
---@param size number|nil The number of bytes to update
function PNG:crc32(src, start, size)
    local crc = self.crc_val

    if type(src) == "table" then
        local stop = start + size - 1
        local i = start

        while i <= stop - 15 do
            for j = 0, 15 do
                crc = b_xor(b_shr(crc, 8), CRC_LOOKUP[b_and(b_xor(crc, src[i + j]), 0xFF)])
            end
            i = i + 16
        end

        while i <= stop do
            crc = b_xor(b_shr(crc, 8), CRC_LOOKUP[b_and(b_xor(crc, src[i]), 0xFF)])
            i = i + 1
        end
    else
        local p = f_cast("uint8_t*", src) + start - 1
        for i = 0, size - 1 do
            crc = b_xor(b_shr(crc, 8), CRC_LOOKUP[b_and(b_xor(crc, p[i]), 0xFF)])
        end
    end

    self.crc_val = b_not(crc)
end

---Finalizes the CRC, returning the result
function PNG:finalizeCrc()
    return self.crc_val
end

---Updates the Adler32
---@param src userdata|table The data to update the Adler32 with
---@param start number|nil The index of the first byte to update
---@param size number|nil The number of bytes to update
function PNG:adler32(src, start, size)
    local s1 = b_and(self.adler_val, 0xFFFF)
    local s2 = b_shr(self.adler_val, 16)

    if type(src) == "table" then
        local p = start
        local left = size

        while left > 0 do
            local batch = m_min(5552, left)
            local stop = p + batch - 1

            local i = p
            while i <= stop - 7 do
                local s = src[i] + src[i + 1] + src[i + 2] + src[i + 3] +
                    src[i + 4] + src[i + 5] + src[i + 6] + src[i + 7]
                s1 = s1 + s
                s2 = s2 + s1 * 8 - (src[i] * 7 + src[i + 1] * 6 + src[i + 2] * 5 +
                    src[i + 3] * 4 + src[i + 4] * 3 + src[i + 5] * 2 + src[i + 6])
                i = i + 8
            end

            while i <= stop do
                s1 = s1 + src[i]
                s2 = s2 + s1
                i = i + 1
            end

            s1 = s1 % 65521
            s2 = s2 % 65521

            p = stop + 1
            left = left - batch
        end
    else
        local ptr = f_cast("uint8_t*", src) + start - 1
        for i = 0, size - 1 do
            s1 = (s1 + ptr[i]) % 65521
            s2 = (s2 + s1) % 65521
        end
    end

    self.adler_val = b_or(b_shl(s2, 16), s1)
end

---Writes pixels to the PNG file
---@param pix table The pixels to write
function PNG:write(pix, size)
    local left = size
    if not left then
        if type(pix) == "table" then
            left = #pix
        else
            left = ffi.sizeof(pix)
        end
    end
    local p_idx = 1
    local stride = self.stride
    local r_cnt = self.rem_sz
    local f_cnt = self.fill_sz
    local px = self.pos_x
    local py = self.pos_y
    local h = self.h

    local f_b = self.filter_b or { 0 }
    local h_b = self.head_b or {}
    self.filter_b = f_b
    self.head_b = h_b

    while left > 0 and not self.finished do
        if f_cnt == 0 then
            local sz = m_min(MAX_BLOCK, r_cnt)
            local last = (r_cnt <= MAX_BLOCK) and 1 or 0

            h_b[1] = b_and(last, 0xFF)
            h_b[2] = b_and(sz, 0xFF)
            h_b[3] = b_and(b_shr(sz, 8), 0xFF)
            h_b[4] = b_and(b_xor(sz, 0xFFFF), 0xFF)
            h_b[5] = b_and(b_shr(b_xor(sz, 0xFFFF), 8), 0xFF)

            self:writeBytes(h_b, 1, 5)
            self:crc32(h_b, 1, 5)
        end

        if px == 0 then
            self:writeBytes(f_b)
            self:crc32(f_b, 1, 1)
            self:adler32(f_b, 1, 1)
            px = 1
            r_cnt = r_cnt - 1
            f_cnt = f_cnt + 1
        else
            local n = m_min(
                MAX_BLOCK - f_cnt,
                stride - px,
                left
            )

            self:writeBytes(pix, p_idx, n)
            self:crc32(pix, p_idx, n)
            self:adler32(pix, p_idx, n)

            left = left - n
            p_idx = p_idx + n
            px = px + n
            r_cnt = r_cnt - n
            f_cnt = f_cnt + n
        end

        if f_cnt >= MAX_BLOCK then
            f_cnt = 0
        end

        if px == stride then
            px = 0
            py = py + 1

            if py == h then
                if self.w_ptr > 0 then
                    local chunks = self.chunks
                    chunks[#chunks + 1] = ffi.string(self.w_buf, self.w_ptr)
                end

                local footer = self.foot_b or {}
                pack32(self.adler_val, footer, 1)
                self:crc32(footer, 1, 4)
                local final = self:finalizeCrc()
                pack32(final, footer, 5)

                footer[9] = 0x00; footer[10] = 0x00; footer[11] = 0x00; footer[12] = 0x00
                footer[13] = 0x49; footer[14] = 0x45; footer[15] = 0x4E; footer[16] = 0x44
                footer[17] = 0xAE; footer[18] = 0x42; footer[19] = 0x60; footer[20] = 0x82

                self:writeBytes(footer, 1, 8)
                self:writeBytes(footer, 9, 12)

                self.foot_b = footer
                self.finished = true
                break
            end
        end
    end

    self.rem_sz = r_cnt
    self.fill_sz = f_cnt
    self.pos_x = px
    self.pos_y = py
end

local SIG = ffi.new("uint8_t[8]", { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A })
local IHDR = ffi.new("uint8_t[4]", { 0x49, 0x48, 0x44, 0x52 })
local IDAT = ffi.new("uint8_t[4]", { 0x49, 0x44, 0x41, 0x54 })
local ZLIB = ffi.new("uint8_t[2]", { 0x08, 0x1D })

local function create(w, h, mode, metadata)
    mode = mode or "rgb"

    local bpp, ctype
    if mode == "rgb" then
        bpp, ctype = 3, 2
    elseif mode == "rgba" then
        bpp, ctype = 4, 6
    else
        error("Invalid mode: " .. tostring(mode))
    end

    local ctx = setmetatable({
        w = w,
        h = h,
        finished = false,
        chunks = {},
        stride = w * bpp + 1,
        pos_x = 0,
        pos_y = 0,
        fill_sz = 0,
        crc_val = 0,
        adler_val = 1,

        w_buf = ffi.new("uint8_t[?]", IO_CHUNK),
        w_ptr = 0,
    }, PNG)

    ctx.rem_sz = ctx.stride * h
    local blocks = m_ceil(ctx.rem_sz / MAX_BLOCK)
    local idat_sz = blocks * 5 + 6 + ctx.rem_sz

    local head = {}
    local k = 1

    for i = 0, 7 do
        head[k] = SIG[i]
        k = k + 1
    end

    pack32(13, head, k)
    k = k + 4

    for i = 0, 3 do
        head[k] = IHDR[i]
        k = k + 1
    end

    pack32(w, head, k)
    k = k + 4
    pack32(h, head, k)
    k = k + 4

    head[k] = 8
    head[k + 1] = ctype
    head[k + 2] = 0
    head[k + 3] = 0
    head[k + 4] = 0
    k = k + 5

    ctx:initCrc()
    ctx:crc32(head, 13, 17)
    local ihdr_crc = ctx:finalizeCrc()

    pack32(ihdr_crc, head, k)
    k = k + 4

    ctx:writeBytes(head, 1, k - 1)
    if metadata then
        for u, v in pairs(metadata) do
            writeTextChunk(ctx, u, v)
        end
    end

    local idat_start = {}
    k = 1
    pack32(idat_sz, idat_start, k)
    k = k + 4

    for i = 0, 3 do
        idat_start[k] = IDAT[i]
        k = k + 1
    end

    idat_start[k] = ZLIB[0]
    idat_start[k + 1] = ZLIB[1]
    k = k + 2

    ctx:writeBytes(idat_start, 1, k - 1)

    ctx:initCrc()
    ctx:crc32(idat_start, 5, 6)

    return ctx
end

---Returns the PNG data to be written to a file
function PNG:getData()
    return table.concat(self.chunks)
end

---Creates a new PNG object
---@param w number
---@param h number
---@param mode string One of "rgb" or "rgba"
function PNG.new(w, h, mode, metadata)
    return create(w, h, mode, metadata)
end

return create
