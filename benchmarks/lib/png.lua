--png.lua
local PNG = {}
PNG.__index = PNG

local bit = require("bit32")
local MAX_BLOCK = 65535

if unpack == nil then
    unpack = table.unpack
end


local b_and, b_xor, b_shr, b_shl, b_not, b_or = bit.band, bit.bxor, bit.rshift, bit.lshift, bit.bnot, bit.bor
local m_min, m_ceil = math.min, math.ceil
local s_char = string.char

local CRC_LOOKUP = {}
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

local BUF_SIZE = 32768

local function pack32(val, tbl, off)
    tbl[off] = b_and(b_shr(val, 24), 0xFF)
    tbl[off + 1] = b_and(b_shr(val, 16), 0xFF)
    tbl[off + 2] = b_and(b_shr(val, 8), 0xFF)
    tbl[off + 3] = b_and(val, 0xFF)
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
    for i = 1, 4 do chunk[j] = TEXT[i]; j = j + 1 end
    for i = 1, len do chunk[j] = data[i]; j = j + 1 end

    ctx.crc_val = 0
    ctx:crc32(chunk, 5, 4 + len)
    pack32(ctx.crc_val, chunk, j)
    j = j + 4

    ctx.crc_val = 0
    ctx:writeBytes(chunk, 1, j - 1)
end

---Writes bytes to the output buffer
---@param src table The data to write
---@param start number|nil The index of the first byte to write
---@param size number|nil The number of bytes to write
function PNG:writeBytes(src, start, size)
    start = start or 1
    size = size or #src

    local out = self.chunks
    local buf = self.w_buf
    local ptr = self.w_ptr

    local stop = start + size - 1
    local i = start

    while i <= stop do
        local space = BUF_SIZE - ptr
        local batch = m_min(space, stop - i + 1)

        for j = 0, batch - 1 do
            buf[ptr + j + 1] = src[i + j]
        end

        ptr = ptr + batch
        i = i + batch

        if ptr >= BUF_SIZE or i > stop then
            out[#out + 1] = s_char(unpack(buf, 1, ptr))
            ptr = 0
        end
    end

    self.w_ptr = ptr
end

---Updates the CRC
---@param src table The data to update the CRC with
---@param start number|nil The index of the first byte to update
---@param size number|nil The number of bytes to update
function PNG:crc32(src, start, size)
    local crc = b_not(self.crc_val)
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

    self.crc_val = b_not(crc)
end

---Updates the Adler32
---@param src table The data to update the Adler32 with
---@param start number|nil The index of the first byte to update
---@param size number|nil The number of bytes to update
function PNG:adler32(src, start, size)
    local s1 = b_and(self.adler_val, 0xFFFF)
    local s2 = b_shr(self.adler_val, 16)

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

    self.adler_val = b_or(b_shl(s2, 16), s1)
end

---Writes pixels to the PNG file
---@param pix table The pixels to write
function PNG:write(pix)
    local left = #pix
    local p_idx = 1
    local stride = self.stride
    local r_cnt = self.rem_sz
    local f_cnt = self.fill_sz
    local px = self.pos_x
    local py = self.pos_y
    local h = self.h

    local f_b = self.filter_b or { 0 }
    self.filter_b = f_b

    while left > 0 do
        if f_cnt == 0 then
            local sz = m_min(MAX_BLOCK, r_cnt)
            local last = (r_cnt <= MAX_BLOCK) and 1 or 0

            local head = self.head_b or {}
            head[1] = b_and(last, 0xFF)
            head[2] = b_and(sz, 0xFF)
            head[3] = b_and(b_shr(sz, 8), 0xFF)
            head[4] = b_and(b_xor(sz, 0xFF), 0xFF)
            head[5] = b_and(b_xor(b_shr(sz, 8), 0xFF), 0xFF)
            self.head_b = head

            self:writeBytes(head, 1, 5)
            self:crc32(head, 1, 5)
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
                    chunks[#chunks + 1] = s_char(unpack(self.w_buf, 1, self.w_ptr))
                end

                local footer = {
                    0, 0, 0, 0,
                    0, 0, 0, 0,
                    0x00, 0x00, 0x00, 0x00,
                    0x49, 0x45, 0x4E, 0x44,
                    0xAE, 0x42, 0x60, 0x82,
                }
                pack32(self.adler_val, footer, 1)
                self:crc32(footer, 1, 4)
                pack32(self.crc_val, footer, 5)
                self:writeBytes(footer)
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

local SIG = { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A }
local IHDR = { 0x49, 0x48, 0x44, 0x52 }
local IDAT = { 0x49, 0x44, 0x41, 0x54 }
local ZLIB = { 0x08, 0x1D }

local function create(w, h, mode, signature)
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

        w_buf = {},
        w_ptr = 0,
    }, PNG)

    for i = 1, BUF_SIZE do
        ctx.w_buf[i] = 0
    end

    ctx.rem_sz = ctx.stride * h
    local blocks = m_ceil(ctx.rem_sz / MAX_BLOCK)
    local idat_sz = blocks * 5 + 6 + ctx.rem_sz

    local head = {}
    local k = 1

    for i = 1, 8 do
        head[k] = SIG[i]
        k = k + 1
    end

    head[k] = 0x00; head[k + 1] = 0x00; head[k + 2] = 0x00; head[k + 3] = 0x0D
    k = k + 4

    for i = 1, 4 do
        head[k] = IHDR[i]
        k = k + 1
    end

    for i = 1, 8 do
        head[k] = 0
        k = k + 1
    end

    head[k] = 0x08; head[k + 1] = ctype; head[k + 2] = 0x00
    head[k + 3] = 0x00; head[k + 4] = 0x00
    k = k + 5

    for i = 1, 4 do
        head[k] = 0
        k = k + 1
    end

    for i = 1, 4 do
        head[k] = 0
        k = k + 1
    end

    for i = 1, 4 do
        head[k] = IDAT[i]
        k = k + 1
    end

    head[k] = ZLIB[1]
    head[k + 1] = ZLIB[2]

    pack32(w, head, 17)
    pack32(h, head, 21)
    pack32(idat_sz, head, 34)

    ctx:crc32(head, 13, 17)
    pack32(ctx.crc_val, head, 30)
    ctx:writeBytes(head, 1, 33)
    writeTextChunk(ctx, "signature", signature)
    ctx:writeBytes(head, 34, 10)
    ctx.crc_val = 0
    ctx:crc32(head, 38, 6)

    return ctx
end

function PNG:getData()
    return table.concat(self.chunks)
end

return create
