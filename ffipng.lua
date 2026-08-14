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
local IO_CHUNK = 16 * 1024 * 1024 -- 16MB buyuk tampon

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
    local cap = self.w_cap

    if type(src) == "table" then
        local stop = start + size - 1
        local i = start

        while i <= stop do
            local space = cap - ptr
            local step = m_min(space, stop - i + 1)

            for j = 0, step - 1 do
                buf[ptr + j] = src[i + j]
            end

            ptr = ptr + step
            i = i + step

            if ptr >= cap then
                out[#out + 1] = ffi.string(buf, ptr)
                ptr = 0
            end
        end
    else
        local srcp = f_cast("uint8_t*", src) + start
        local i = 0

        while i < size do
            local space = cap - ptr
            local step = m_min(space, size - i)

            ffi.copy(buf + ptr, srcp + i, step)

            ptr = ptr + step
            i = i + step

            if ptr >= cap then
                out[#out + 1] = ffi.string(buf, ptr)
                ptr = 0
            end
        end
    end

    self.w_ptr = ptr
end


function PNG:initCrc()
    self.crc_val = 0
end

---Updates the CRC
---@param src userdata|table The data to update the CRC with
---@param start number|nil The index of the first byte to update
---@param size number|nil The number of bytes to update
function PNG:crc32(src, start, size)
    local crc = b_not(self.crc_val)

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
    local p = f_cast("const uint8_t*", src) + start
    local stop = size
    local i = 0

    while i <= stop - 16 do
        crc = b_xor(b_shr(crc, 8), CRC_LOOKUP[b_and(b_xor(crc, p[i]), 0xFF)])
        crc = b_xor(b_shr(crc, 8), CRC_LOOKUP[b_and(b_xor(crc, p[i + 1]), 0xFF)])
        crc = b_xor(b_shr(crc, 8), CRC_LOOKUP[b_and(b_xor(crc, p[i + 2]), 0xFF)])
        crc = b_xor(b_shr(crc, 8), CRC_LOOKUP[b_and(b_xor(crc, p[i + 3]), 0xFF)])
        crc = b_xor(b_shr(crc, 8), CRC_LOOKUP[b_and(b_xor(crc, p[i + 4]), 0xFF)])
        crc = b_xor(b_shr(crc, 8), CRC_LOOKUP[b_and(b_xor(crc, p[i + 5]), 0xFF)])
        crc = b_xor(b_shr(crc, 8), CRC_LOOKUP[b_and(b_xor(crc, p[i + 6]), 0xFF)])
        crc = b_xor(b_shr(crc, 8), CRC_LOOKUP[b_and(b_xor(crc, p[i + 7]), 0xFF)])
        crc = b_xor(b_shr(crc, 8), CRC_LOOKUP[b_and(b_xor(crc, p[i + 8]), 0xFF)])
        crc = b_xor(b_shr(crc, 8), CRC_LOOKUP[b_and(b_xor(crc, p[i + 9]), 0xFF)])
        crc = b_xor(b_shr(crc, 8), CRC_LOOKUP[b_and(b_xor(crc, p[i + 10]), 0xFF)])
        crc = b_xor(b_shr(crc, 8), CRC_LOOKUP[b_and(b_xor(crc, p[i + 11]), 0xFF)])
        crc = b_xor(b_shr(crc, 8), CRC_LOOKUP[b_and(b_xor(crc, p[i + 12]), 0xFF)])
        crc = b_xor(b_shr(crc, 8), CRC_LOOKUP[b_and(b_xor(crc, p[i + 13]), 0xFF)])
        crc = b_xor(b_shr(crc, 8), CRC_LOOKUP[b_and(b_xor(crc, p[i + 14]), 0xFF)])
        crc = b_xor(b_shr(crc, 8), CRC_LOOKUP[b_and(b_xor(crc, p[i + 15]), 0xFF)])
        i = i + 16
    end

    while i < stop do
        crc = b_xor(
            b_shr(crc, 8),
            CRC_LOOKUP[b_and(b_xor(crc, p[i]), 0xFF)]
        )
        i = i + 1
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
                s2 = s2 + s1 * 8 + (src[i] * 8 + src[i + 1] * 7 + src[i + 2] * 6 + src[i + 3] * 5 +
                    src[i + 4] * 4 + src[i + 5] * 3 + src[i + 6] * 2 + src[i + 7])
                s1 = s1 + (src[i] + src[i + 1] + src[i + 2] + src[i + 3] +
                    src[i + 4] + src[i + 5] + src[i + 6] + src[i + 7])
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
    local ptr = f_cast("const uint8_t*", src) + start
    local left = size
    local p = 0

    while left > 0 do
        local batch = m_min(5552, left)
        local stop = p + batch
        local i = p

        while i <= stop - 8 do
            s2 = s2 + s1 * 8 +
                (ptr[i] * 8 + ptr[i + 1] * 7 + ptr[i + 2] * 6 + ptr[i + 3] * 5 +
                ptr[i + 4] * 4 + ptr[i + 5] * 3 + ptr[i + 6] * 2 + ptr[i + 7])

            s1 = s1 + (
                ptr[i] + ptr[i + 1] + ptr[i + 2] + ptr[i + 3] +
                ptr[i + 4] + ptr[i + 5] + ptr[i + 6] + ptr[i + 7]
            )

            i = i + 8
        end

        while i < stop do
            s1 = s1 + ptr[i]
            s2 = s2 + s1
            i = i + 1
        end

        s1 = s1 % 65521
        s2 = s2 % 65521

        p = stop
        left = left - batch
    end
end

    self.adler_val = b_or(b_shl(s2, 16), s1)
end

---Writes pixels to the PNG file
---@param pix table|userdata The pixels to write
function PNG:write(pix, size)
    local is_table = type(pix) == "table"
    local left = size or (is_table and #pix or ffi.sizeof(pix))

    local p_idx = 1
    local stride = self.stride
    local r_cnt = self.rem_sz
    local f_cnt = self.fill_sz
    local px = self.pos_x
    local py = self.pos_y
    local h = self.h

    local f_b = self.filter_b or ffi.new("uint8_t[1]")
    local h_b = self.head_b or ffi.new("uint8_t[5]")
    self.filter_b = f_b
    self.head_b = h_b

    local out = self.chunks
    local buf = self.w_buf
    local ptr = self.w_ptr
    local cap = self.w_cap

    local src
    if not is_table then
        src = f_cast("const uint8_t*", pix)
    end

    while left > 0 and not self.finished do
        if f_cnt == 0 then
            local sz = m_min(MAX_BLOCK, r_cnt)
            local last = (r_cnt <= MAX_BLOCK) and 1 or 0
            local nlen = b_xor(sz, 0xFFFF)

            h_b[0] = last
            h_b[1] = b_and(sz, 0xFF)
            h_b[2] = b_shr(sz, 8)
            h_b[3] = b_and(nlen, 0xFF)
            h_b[4] = b_shr(nlen, 8)

            self.w_ptr = ptr
            self:writeBytes(h_b, 0, 5)
            self:crc32(h_b, 0, 5)
            ptr = self.w_ptr
        end

        if px == 0 then
            f_b[0] = 0

            self.w_ptr = ptr
            self:writeBytes(f_b, 0, 1)
            self:crc32(f_b, 0, 1)
            self:adler32(f_b, 0, 1)
            ptr = self.w_ptr

            px = 1
            r_cnt = r_cnt - 1
            f_cnt = f_cnt + 1
        else
            local n = m_min(
                MAX_BLOCK - f_cnt,
                stride - px,
                left
            )

            local consumed = 0

            while consumed < n do
                local remaining = n - consumed
                local space = cap - ptr
                local step = m_min(space, remaining)

                if is_table then
                    self.w_ptr = ptr
                    self:writeBytes(pix, p_idx + consumed, step)
                    self:crc32(pix, p_idx + consumed, step)
                    self:adler32(pix, p_idx + consumed, step)
                    ptr = self.w_ptr
                else
                    local srcp = src + (p_idx - 1) + consumed

                    ffi.copy(buf + ptr, srcp, step)

                    local crc = b_not(self.crc_val)
                    local i = 0

                    while i <= step - 16 do
                        crc = b_xor(b_shr(crc, 8), CRC_LOOKUP[b_and(b_xor(crc, srcp[i]), 0xFF)])
                        crc = b_xor(b_shr(crc, 8), CRC_LOOKUP[b_and(b_xor(crc, srcp[i + 1]), 0xFF)])
                        crc = b_xor(b_shr(crc, 8), CRC_LOOKUP[b_and(b_xor(crc, srcp[i + 2]), 0xFF)])
                        crc = b_xor(b_shr(crc, 8), CRC_LOOKUP[b_and(b_xor(crc, srcp[i + 3]), 0xFF)])
                        crc = b_xor(b_shr(crc, 8), CRC_LOOKUP[b_and(b_xor(crc, srcp[i + 4]), 0xFF)])
                        crc = b_xor(b_shr(crc, 8), CRC_LOOKUP[b_and(b_xor(crc, srcp[i + 5]), 0xFF)])
                        crc = b_xor(b_shr(crc, 8), CRC_LOOKUP[b_and(b_xor(crc, srcp[i + 6]), 0xFF)])
                        crc = b_xor(b_shr(crc, 8), CRC_LOOKUP[b_and(b_xor(crc, srcp[i + 7]), 0xFF)])
                        crc = b_xor(b_shr(crc, 8), CRC_LOOKUP[b_and(b_xor(crc, srcp[i + 8]), 0xFF)])
                        crc = b_xor(b_shr(crc, 8), CRC_LOOKUP[b_and(b_xor(crc, srcp[i + 9]), 0xFF)])
                        crc = b_xor(b_shr(crc, 8), CRC_LOOKUP[b_and(b_xor(crc, srcp[i + 10]), 0xFF)])
                        crc = b_xor(b_shr(crc, 8), CRC_LOOKUP[b_and(b_xor(crc, srcp[i + 11]), 0xFF)])
                        crc = b_xor(b_shr(crc, 8), CRC_LOOKUP[b_and(b_xor(crc, srcp[i + 12]), 0xFF)])
                        crc = b_xor(b_shr(crc, 8), CRC_LOOKUP[b_and(b_xor(crc, srcp[i + 13]), 0xFF)])
                        crc = b_xor(b_shr(crc, 8), CRC_LOOKUP[b_and(b_xor(crc, srcp[i + 14]), 0xFF)])
                        crc = b_xor(b_shr(crc, 8), CRC_LOOKUP[b_and(b_xor(crc, srcp[i + 15]), 0xFF)])
                        i = i + 16
                    end

                    while i < step do
                        crc = b_xor(
                            b_shr(crc, 8),
                            CRC_LOOKUP[b_and(b_xor(crc, srcp[i]), 0xFF)]
                        )
                        i = i + 1
                    end

                    self.crc_val = b_not(crc)

                    local s1 = b_and(self.adler_val, 0xFFFF)
                    local s2 = b_shr(self.adler_val, 16)

                    local ai = 0

                    while ai <= step - 8 do
                        local a0 = srcp[ai]
                        local a1 = srcp[ai + 1]
                        local a2 = srcp[ai + 2]
                        local a3 = srcp[ai + 3]
                        local a4 = srcp[ai + 4]
                        local a5 = srcp[ai + 5]
                        local a6 = srcp[ai + 6]
                        local a7 = srcp[ai + 7]

                        s2 = s2 + s1 * 8 +
                            a0 * 8 + a1 * 7 + a2 * 6 + a3 * 5 +
                            a4 * 4 + a5 * 3 + a6 * 2 + a7

                        s1 = s1 + a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7
                        ai = ai + 8
                    end

                    while ai < step do
                        s1 = s1 + srcp[ai]
                        s2 = s2 + s1
                        ai = ai + 1
                    end

                    self.adler_val = b_or(
                        b_shl(s2 % 65521, 16),
                        s1 % 65521
                    )

                    ptr = ptr + step
                end

                consumed = consumed + step

                if ptr >= cap then
                    out[#out + 1] = ffi.string(buf, ptr)
                    ptr = 0
                end
            end

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
                local footer = self.foot_b or ffi.new("uint8_t[20]")

                pack32(self.adler_val, footer, 0)

                self:crc32(footer, 0, 4)
                pack32(self:finalizeCrc(), footer, 4)

                footer[8] = 0
                footer[9] = 0
                footer[10] = 0
                footer[11] = 0

                footer[12] = 0x49
                footer[13] = 0x45
                footer[14] = 0x4E
                footer[15] = 0x44

                footer[16] = 0xAE
                footer[17] = 0x42
                footer[18] = 0x60
                footer[19] = 0x82

                self.w_ptr = ptr
                self:writeBytes(footer, 0, 8)
                self:writeBytes(footer, 8, 12)
                ptr = self.w_ptr

                if ptr > 0 then
                    out[#out + 1] = ffi.string(buf, ptr)
                    ptr = 0
                end

                self.foot_b = footer
                self.finished = true
                break
            end
        end
    end

    self.w_ptr = ptr
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

    local rem_sz = (w * bpp + 1) * h
    local blocks = m_ceil(rem_sz / MAX_BLOCK)
    local idat_sz = blocks * 5 + 6 + rem_sz
    local total_png_est = idat_sz + 1024
    local cap = m_min(IO_CHUNK, total_png_est)

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

        w_buf = ffi.new("uint8_t[?]", cap),
        w_ptr = 0,
        w_cap = cap,
    }, PNG)

    ctx.rem_sz = rem_sz

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

local is_windows = (ffi.os == "Windows")

if is_windows then
    ffi.cdef[[
        void* CreateFileA(const char* lpFileName, uint32_t dwDesiredAccess, uint32_t dwShareMode, void* lpSecurityAttributes, uint32_t dwCreationDisposition, uint32_t dwFlagsAndAttributes, void* hTemplateFile);
        int WriteFile(void* hFile, const void* lpBuffer, uint32_t nNumberOfBytesToWrite, uint32_t* lpNumberOfBytesWritten, void* lpOverlapped);
        int CloseHandle(void* hObject);
        uint32_t SetFilePointer(void* hFile, long lDistanceToMove, long* lpDistanceToMoveHigh, uint32_t dwMoveMethod);
        int SetEndOfFile(void* hFile);
        void* CreateFileMappingA(void* hFile, void* lpFileMappingAttributes, uint32_t flProtect, uint32_t dwMaximumSizeHigh, uint32_t dwMaximumSizeLow, const char* lpName);
        void* MapViewOfFile(void* hFileMappingObject, uint32_t dwDesiredAccess, uint32_t dwFileOffsetHigh, uint32_t dwFileOffsetLow, size_t dwNumberOfBytesToMap);
        int UnmapViewOfFile(const void* lpBaseAddress);
    ]]
else
    ffi.cdef[[
        int open(const char *pathname, int flags, int mode);
        long write(int fd, const void *buf, size_t count);
        int close(int fd);
    ]]
end

local bytes_written_buf = ffi.new("uint32_t[1]")

---Writes PNG data directly to a file using fastest native OS I/O
---@param filepath string
---@return boolean
function PNG:writeToFile(filepath)
    if is_windows then
        -- 0x40000000 = GENERIC_WRITE, 3 = FILE_SHARE_READ|FILE_SHARE_WRITE
        -- 4 = OPEN_ALWAYS (reuses existing file allocation without NTFS deletion overhead)
        -- 0x08000080 = FILE_FLAG_SEQUENTIAL_SCAN | FILE_ATTRIBUTE_NORMAL
        local h = ffi.C.CreateFileA(filepath, 0x40000000, 3, nil, 4, 0x08000080, nil)
        if h == ffi.cast("void*", -1) or h == nil then
            return false
        end

        ffi.C.SetFilePointer(h, 0, nil, 0)

        local chunks = self.chunks
        for i = 1, #chunks do
            local str = chunks[i]
            if ffi.C.WriteFile(h, str, #str, bytes_written_buf, nil) == 0 then
                ffi.C.CloseHandle(h)
                return false
            end
        end

        if self.w_ptr > 0 then
            if ffi.C.WriteFile(h, self.w_buf, self.w_ptr, bytes_written_buf, nil) == 0 then
                ffi.C.CloseHandle(h)
                return false
            end
        end

        ffi.C.SetEndOfFile(h)
        ffi.C.CloseHandle(h)
        return true
    end

    -- POSIX direct syscall: O_WRONLY(1) | O_CREAT(64) | O_TRUNC(512) = 577
    local fd = ffi.C.open(filepath, 577, 438) -- 0666 octal = 438 dec
    if fd < 0 then
        return false
    end

    local chunks = self.chunks
    for i = 1, #chunks do
        local str = chunks[i]
        ffi.C.write(fd, str, #str)
    end

    if self.w_ptr > 0 then
        ffi.C.write(fd, self.w_buf, self.w_ptr)
    end

    ffi.C.close(fd)
    return true
end

---Writes PNG data to a file using memory-mapped I/O (Windows only, falls back to writeToFile on POSIX)
---@param filepath string
---@return boolean
function PNG:writeToFileMapped(filepath)
    if not is_windows then
        return self:writeToFile(filepath)
    end

    local total = 0
    local chunks = self.chunks
    for i = 1, #chunks do
        total = total + #chunks[i]
    end
    if self.w_ptr > 0 then
        total = total + self.w_ptr
    end

    if total == 0 then return false end

    -- 0xC0000000 = GENERIC_READ | GENERIC_WRITE
    -- 4 = OPEN_ALWAYS
    -- 0x00000080 = FILE_ATTRIBUTE_NORMAL
    local h = ffi.C.CreateFileA(filepath, 0xC0000000, 0, nil, 4, 0x00000080, nil)
    if h == ffi.cast("void*", -1) or h == nil then
        return false
    end

    -- Truncate to exact size
    ffi.C.SetFilePointer(h, total, nil, 0)
    ffi.C.SetEndOfFile(h)
    ffi.C.SetFilePointer(h, 0, nil, 0)

    -- 0x04 = PAGE_READWRITE
    local mapping = ffi.C.CreateFileMappingA(h, nil, 0x04, 0, total, nil)
    if mapping == nil then
        ffi.C.CloseHandle(h)
        return false
    end

    -- 0x00000002 = FILE_MAP_WRITE
    local view = ffi.C.MapViewOfFile(mapping, 0x00000002, 0, 0, total)
    if view == nil then
        ffi.C.CloseHandle(mapping)
        ffi.C.CloseHandle(h)
        return false
    end


    local dst = ffi.cast("uint8_t*", view)
    local off = 0
    for i = 1, #chunks do
        local str = chunks[i]
        local len = #str
        ffi.copy(dst + off, str, len)
        off = off + len
    end
    if self.w_ptr > 0 then
        ffi.copy(dst + off, self.w_buf, self.w_ptr)
    end

    ffi.C.UnmapViewOfFile(view)
    ffi.C.CloseHandle(mapping)
    ffi.C.CloseHandle(h)
    return true
end

---Returns the PNG data to be written to a file
function PNG:getData()
    if #self.chunks == 1 then
        return self.chunks[1]
    end
    if self.w_ptr > 0 and #self.chunks == 0 then
        return ffi.string(self.w_buf, self.w_ptr)
    end
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