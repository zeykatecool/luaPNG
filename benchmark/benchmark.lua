--- This file does not use init.lua of luaPNG.
--- It directly uses the FFI and LUA png libraries which are core files of luaPNG.
--- This file needs to be run with LuaJIT.
--- The results are logged to output/log/benchmark.log and output/log/benchmark.csv files.

math.randomseed(os.time())
local ffiPng = require("lib.ffipng")
local luaPng = require("lib.png")

local tests = {}
local sizes = {1000, 1500, 2000, 2500}
local modes = {"rgb", "rgba"}

for _, w in ipairs(sizes) do
    for _, h in ipairs(sizes) do
        for _, mode in ipairs(modes) do
            table.insert(tests, {width = w, height = h, colorMode = mode})
        end
    end
end


local logFile = io.open("output/log/benchmark_"..os.date("%Y%m%d")..".log", "a")
local csvFile = io.open("output/log/benchmark_"..os.date("%Y%m%d")..".csv", "w")
csvFile:write("Library,Width,Height,Mode,TotalPixels,MemMB,EncodeTimeSec,FileSizeBytes,FileSizeMB,WriteSpeedMBps,Status\n")

local function log(...)
    local msg = table.concat({...}, " ")
    print(msg)
    if logFile then logFile:write(msg.."\n") end
end

local function runBenchmark(library, libName)
    for idx, test in ipairs(tests) do
        local width, height, colorMode = test.width, test.height, test.colorMode
        local channels = (colorMode == "rgb") and 3 or 4
        local totalPixels = width * height * channels
        local memEstimateMB = totalPixels * 8 / (1024*1024)

        log(string.format("[%s] Test %d: %dx%d %s, total pixels %d, approx mem %.2f MB", libName, idx, width, height, colorMode, totalPixels, memEstimateMB))
        local pixels = {}
        for i = 1, totalPixels do pixels[i] = math.random(0,255) end

        local status, duration, dataSize
        local success, err = pcall(function()
            local startTime = os.clock()
            local png = library(width, height, colorMode)
            png:write(pixels)
            duration = os.clock() - startTime
            dataSize = #png:getData()

            if libName == "FFIPNG" then
                folder = "ffi"
            elseif libName == "LUA" then
                folder = "lua"
            end

            local filename = string.format("output/image/%s_image_%d.png", libName:lower(), idx)
            local f = io.open(filename, "wb")
            f:write(png:getData())
            f:close()
        end)

        local fileSizeMB = dataSize and (dataSize/(1024*1024)) or 0
        local speedMBps = duration and (fileSizeMB/duration) or 0
        local statusStr = success and "OK" or ("ERROR: "..err)

        log(string.format("[%s] EncodeTime: %.4f sec, FileSize: %d bytes (%.2f MB), WriteSpeed: %.2f MB/s, Status: %s", libName, duration or 0, dataSize or 0, fileSizeMB, speedMBps, statusStr))
        csvFile:write(string.format("%s,%d,%d,%s,%d,%.2f,%.4f,%d,%.2f,%.2f,%s\n",
            libName, width, height, colorMode, totalPixels, memEstimateMB, duration or 0, dataSize or 0, fileSizeMB, speedMBps, statusStr))
    end
end

log("Starting FFI PNG benchmark")
runBenchmark(ffiPng, "FFI")

log("Starting Pure Lua PNG benchmark")
runBenchmark(luaPng, "LUA")

log("Benchmark completed")
logFile:close()
csvFile:close()

print("Done in: ", os.clock())