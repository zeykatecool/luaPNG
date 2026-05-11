---@diagnostic disable: need-check-nil
-- pure_lua_benchmark.lua
local luapng = require("lib.png")

local resolutions = {
    { 256,  256 },
    { 512,  512 },
    { 1024, 1024 },
    { 2048, 2048 },
    { 4096, 4096 }
}

local iterations = 3
local output_path = "output/lua/"

local function generate_table_data(w, h)
    local data = {}
    for i = 1, w * h * 3 do
        data[i] = i % 256
    end
    return data
end

local csv = io.open(output_path .. "benchmark_pure_lua.csv", "w")
csv:write("Resolution,AverageTimeMS,MBPerSecond\n")

print("--- Pure Lua Benchmark (png.lua) ---")
print(string.format("%-15s | %-12s | %-12s", "Resolution", "Avg Time", "Throughput"))
print(string.rep("-", 45))

for _, res in ipairs(resolutions) do
    local w, h = res[1], res[2]
    local name = w .. "x" .. h
    local raw_size_mb = (w * h * 3) / (1024 * 1024)

    local table_data = generate_table_data(w, h)
    local total_time = 0
    local last_data

    for _ = 1, iterations do
        local start = os.clock()
        local p = luapng(w, h, "rgb", "pure-lua-bench")
        p:write(table_data)
        last_data = p:getData()
        total_time = total_time + (os.clock() - start)
    end

    local avg_time = (total_time / iterations) * 1000
    local tp = raw_size_mb / (total_time / iterations)

    print(string.format("%-15s | %10.2fms | %10.2f MB/s", name, avg_time, tp))
    csv:write(string.format("%s,%.2f,%.2f\n", name, avg_time, tp))

    local f = io.open(output_path .. "pure_lua_" .. name .. ".png", "wb")
    f:write(last_data)
    f:close()
end

csv:close()
print("\nPure Lua benchmark complete.")
