# PNG Encoder and Raster Toolkit for LuaJIT / Lua
- High-performance PNG encoder for LuaJIT and Lua.
- LuaJIT is much faster and ~~Lua is not recommended for production usage~~ **Lua (png.lua) is deprecated**.
- Provides a lightweight raster pipeline (geometry, shapes).
- Supports RGB and RGBA color modes.
- This library does **not** perform any **compression**. Output files are uncompressed PNGs.

# Performance
- Check `benchmarks` for graphics (requires [luachart](https://github.com/zeykatecool/luachart) to generate charts).
<p align="center">
  <img src="https://raw.githubusercontent.com/zeykatecool/luaPNG/main/benchmarks/chart_io_throughput.png" width="45%">
  <img src="https://raw.githubusercontent.com/zeykatecool/luaPNG/main/benchmarks/chart_latency_stability.png" width="45%">
  <br>
  <img src="https://raw.githubusercontent.com/zeykatecool/luaPNG/main/benchmarks/chart_normalized_efficiency.png" width="45%">
  <img src="https://raw.githubusercontent.com/zeykatecool/luaPNG/main/benchmarks/chart_percentage_breakdown.png" width="45%">
</p>

# Usage
- Check `examples` folder for more examples.

```lua
--- Encoding standart PNG.
local Image = require("luaPNG.init")

local png = Image.new(256, 256, "rgb")

for i = 1, 256*256*3 do
    png.Data[i] = math.random(0,255)
end

print(Image.UsingJIT)

png:save("Example256x256.png")
print("Done in: ", os.clock())

```

```lua
--- Encoding standart PNG and drawing rectangle.
local Image = require("luaPNG.init")
local img = Image.new(800, 600, "rgba")

img:add(Geometry.Rectangle{
    x = 0, y = 0,
    w = 300, h = 300,
    color = {220, 60, 60, 180}, -- RGBA
    mode = "fill"
})

img:save("Example800x600.png")
print("Done in:", os.clock())
```

## License
- MIT License

