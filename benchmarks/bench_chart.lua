package.path = package.path .. ";./?.lua;./?/init.lua"
local Chart = require("luachart.init")
local ffi = require("ffi")
local Image = require("luaPNG")
local PNGLib = Image.UsingJIT and require("luaPNG.ffipng") or require("luaPNG.png")

print("================================================================================")
print("luaPNG BENCHMARK")
print("Using " .. jit.version)
print("================================================================================")

local function get_hires_timer()
    if ffi.os == "Windows" then
        ffi.cdef[[
            typedef long long LARGE_INTEGER;
            int QueryPerformanceCounter(LARGE_INTEGER*);
            int QueryPerformanceFrequency(LARGE_INTEGER*);
        ]]
        local freq = ffi.new("LARGE_INTEGER[1]")
        local counter = ffi.new("LARGE_INTEGER[1]")
        ffi.C.QueryPerformanceFrequency(freq)
        local f = tonumber(freq[0])
        return function()
            ffi.C.QueryPerformanceCounter(counter)
            return tonumber(counter[0]) / f
        end
    end
    return os.clock
end

local now = get_hires_timer()

local resolutions = {
    { w = 256, h = 256, iters = 40 },
    { w = 512, h = 512, iters = 40 },
    { w = 1024, h = 1024, iters = 25 },
    { w = 2048, h = 2048, iters = 15 },
}

local res_labels = {}

local norm_ram_ms = {}
local norm_enc_ms = {}
local norm_wr_ms = {}
local norm_save_ms = {}

local pct_ram = {}
local pct_enc = {}
local pct_io = {}

local io_lua_mbps = {}
local io_win32_mbps = {}
local io_mmap_mbps = {}

local std_res_labels = {"512x512", "1024x1024"}
local lat_min = {}
local lat_med = {}
local lat_avg = {}
local lat_max = {}

for idx, r in ipairs(resolutions) do
    local w, h, iters = r.w, r.h, r.iters
    local pixels = w * h
    local megapixels = pixels / 1000000
    local raw_mb = (pixels * 3) / (1024 * 1024)

    table.insert(res_labels, string.format("%dx%d", w, h))
    print(string.format("Testing %dx%d (%d runs)...", w, h, iters))

    local img = Image.new(w, h, "rgb")
    img:save("temp_bench.png")

    local t0 = now()
    for _ = 1, iters do
        local test_img = Image.new(w, h, "rgb")
        for y = 0, h - 1 do
            for x = 0, w - 1 do
                test_img:setPixel(x, y, (x * 255) / w, (y * 255) / h, 128)
            end
        end
    end
    local t_ram = (now() - t0) / iters

    local sample_img = Image.new(w, h, "rgb")
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            sample_img:setPixel(x, y, (x * 255) / w, (y * 255) / h, 128)
        end
    end

    local encoded_data
    local png_ctx
    t0 = now()
    for _ = 1, iters do
        local png = PNGLib(sample_img.Width, sample_img.Height, sample_img.ColorMode, sample_img.Metadata)
        png:write(sample_img.Data)
        encoded_data = png:getData()
        png_ctx = png
    end
    local t_enc = (now() - t0) / iters

    t0 = now()
    for _ = 1, iters do
        local f = io.open("temp_bench.png", "wb") or error("Failed to open temp_bench.png for writing")
        f:write(encoded_data)
        f:close()
    end
    local t_lua_io = (now() - t0) / iters

    t0 = now()
    for _ = 1, iters do
        png_ctx:writeToFile("temp_bench.png")
    end
    local t_win32_io = (now() - t0) / iters

    local t_mmap_io = 0
    if png_ctx.writeToFileMapped then
        t0 = now()
        for _ = 1, iters do
            png_ctx:writeToFileMapped("temp_bench.png")
        end
        t_mmap_io = (now() - t0) / iters
    end

    local save_samples = {}
    for i = 1, iters do
        local s_t0 = now()
        sample_img:save("temp_bench.png")
        save_samples[i] = now() - s_t0
    end
    table.sort(save_samples)

    local total_s = 0
    for i = 1, iters do total_s = total_s + save_samples[i] end
    local t_save = total_s / iters
    local t_save_med = save_samples[math.ceil(iters / 2)]
    local t_save_min = save_samples[1]
    local t_save_max = save_samples[iters]

    if w == 512 or w == 1024 then
        table.insert(lat_min, math.floor(t_save_min * 1000 * 100 + 0.5) / 100)
        table.insert(lat_med, math.floor(t_save_med * 1000 * 100 + 0.5) / 100)
        table.insert(lat_avg, math.floor(t_save * 1000 * 100 + 0.5) / 100)
        table.insert(lat_max, math.floor(t_save_max * 1000 * 100 + 0.5) / 100)
    end

    local per_mp_ram  = (t_ram * 1000) / megapixels
    local per_mp_enc  = (t_enc * 1000) / megapixels
    local per_mp_wr   = (t_win32_io * 1000) / megapixels
    local per_mp_save = (t_save * 1000) / megapixels

    table.insert(norm_ram_ms, math.floor(per_mp_ram * 10 + 0.5) / 10)
    table.insert(norm_enc_ms, math.floor(per_mp_enc * 10 + 0.5) / 10)
    table.insert(norm_wr_ms,  math.floor(per_mp_wr * 10 + 0.5) / 10)
    table.insert(norm_save_ms, math.floor(per_mp_save * 10 + 0.5) / 10)

    local sum_time = t_ram + t_enc + t_win32_io
    local p_ram = math.floor((t_ram / sum_time) * 1000 + 0.5) / 10
    local p_enc = math.floor((t_enc / sum_time) * 1000 + 0.5) / 10
    local p_io  = math.floor((t_win32_io / sum_time) * 1000 + 0.5) / 10

    table.insert(pct_ram, p_ram)
    table.insert(pct_enc, p_enc)
    table.insert(pct_io,  p_io)

    local out_mb = (#encoded_data) / (1024 * 1024)
    table.insert(io_lua_mbps,   math.floor((out_mb / t_lua_io) * 10 + 0.5) / 10)
    table.insert(io_win32_mbps, math.floor((out_mb / t_win32_io) * 10 + 0.5) / 10)
    table.insert(io_mmap_mbps,  math.floor((out_mb / t_mmap_io) * 10 + 0.5) / 10)
end

os.remove("temp_bench.png")

print("\nRendering charts...")

print("- chart_normalized_efficiency.png")
local chart1 = Chart.new({
    width   = 960,
    height  = 540,
    type    = "bar",
    theme   = "dark",
    title   = "luaPNG: Normalized Efficiency (ms / Megapixel)",
    xlabel  = "Resolution",
    ylabel  = "Time (ms / MP)",
    footer  = "Lower is better. Shows linear efficiency across resolutions.",
    xLabels = res_labels,
})

chart1:addSeries({
    label = "RAM Init (ms/MP)",
    data  = norm_ram_ms,
})

chart1:addSeries({
    label = "Encode (ms/MP)",
    data  = norm_enc_ms,
})

chart1:addSeries({
    label = "Disk Write (ms/MP)",
    data  = norm_wr_ms,
})

chart1:addSeries({
    label = "image:save() (ms/MP)",
    data  = norm_save_ms,
})

chart1:render("chart_normalized_efficiency.png")

print("- chart_percentage_breakdown.png")
local chart2 = Chart.new({
    width   = 960,
    height  = 540,
    type    = "bar",
    theme   = "dark",
    title   = "luaPNG: Time Breakdown (%)",
    xlabel  = "Resolution",
    ylabel  = "Share (%)",
    footer  = "Small sizes are I/O bound; large sizes are CPU encode bound.",
    xLabels = res_labels,
})

chart2:addSeries({
    label = "RAM Pixel Gen (%)",
    data  = pct_ram,
})

chart2:addSeries({
    label = "PNG Encode CPU (%)",
    data  = pct_enc,
})

chart2:addSeries({
    label = "Disk Write (%)",
    data  = pct_io,
})

chart2:render("chart_percentage_breakdown.png")

print("- chart_io_throughput.png")
local chart3 = Chart.new({
    width   = 960,
    height  = 540,
    type    = "bar",
    theme   = "dark",
    title   = "luaPNG: Disk Write Speed (MB/s)",
    xlabel  = "Resolution",
    ylabel  = "Speed (MB/s)",
    footer  = "io.open (Lua) vs Win32 FFI vs Memory-Mapped",
    xLabels = res_labels,
})

chart3:addSeries({
    label = "io.open (Lua)",
    data  = io_lua_mbps,
})

chart3:addSeries({
    label = "Win32 WriteFile (FFI)",
    data  = io_win32_mbps,
})

chart3:addSeries({
    label = "Memory-Mapped (mmap)",
    data  = io_mmap_mbps,
})

chart3:render("chart_io_throughput.png")

print("- chart_latency_stability.png")
local chart4 = Chart.new({
    width   = 960,
    height  = 540,
    type    = "bar",
    theme   = "dark",
    title   = "luaPNG: image:save() Latency Consistency",
    xlabel  = "Resolution",
    ylabel  = "Time (ms)",
    footer  = "Min, Median, Average and Max save latency",
    xLabels = std_res_labels,
})

chart4:addSeries({
    label = "Fastest (Min ms)",
    data  = lat_min,
})

chart4:addSeries({
    label = "Median (ms)",
    data  = lat_med,
})

chart4:addSeries({
    label = "Average (ms)",
    data  = lat_avg,
})

chart4:addSeries({
    label = "Slowest (Max ms)",
    data  = lat_max,
})

chart4:render("chart_latency_stability.png")

print("Done.")
