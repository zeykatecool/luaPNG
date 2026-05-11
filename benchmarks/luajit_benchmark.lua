---@diagnostic disable: need-check-nil
-- luajit_benchmark.lua
local ffi = require("ffi")
local ffipng = require("lib.ffipng")

if not jit then
    print("This benchmark is designed for LuaJIT")
    os.exit(1)
end

local resolutions = {
    { 256,  256 },
    { 512,  512 },
    { 1024, 1024 },
    { 2048, 2048 },
    { 4096, 4096 },
    { 8192, 8192 }
}

local iterations = 5
local output_path = "output/luajit/"

local function generate_ffi_data(w, h)
    local size = w * h * 3
    local data = ffi.new("uint8_t[?]", size)
    for i = 0, size - 1 do
        data[i] = i % 256
    end
    return data
end

local csv = io.open(output_path .. "benchmark_luajit.csv", "w")
csv:write("Resolution,AverageTimeMS,MBPerSecond\n")

print("--- LuaJIT Benchmark (ffipng.lua) ---")
print(string.format("%-15s | %-12s | %-12s", "Resolution", "Avg Time", "Throughput"))
print(string.rep("-", 45))

for _, res in ipairs(resolutions) do
    local w, h = res[1], res[2]
    local name = w .. "x" .. h
    local raw_size_mb = (w * h * 3) / (1024 * 1024)

    local ffi_data = generate_ffi_data(w, h)
    local total_time = 0
    local last_data

    for _ = 1, iterations do
        local start = os.clock()
        local p = ffipng(w, h, "rgb", "luajit-ffi-bench")
        p:write(ffi_data)
        last_data = p:getData()
        total_time = total_time + (os.clock() - start)
    end

    local avg_time = (total_time / iterations) * 1000
    local tp = raw_size_mb / (total_time / iterations)

    print(string.format("%-15s | %10.2fms | %10.2f MB/s", name, avg_time, tp))
    csv:write(string.format("%s,%.2f,%.2f\n", name, avg_time, tp))

    local f = io.open(output_path .. "luajit_ffi_" .. name .. ".png", "wb")
    f:write(last_data)
    f:close()
end

csv:close()
print("\nLuaJIT benchmark complete.")
