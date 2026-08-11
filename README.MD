# PNG Encoder and Raster Toolkit for Lua / LuaJIT
- High-performance PNG encoder written in pure Lua with optional LuaJIT FFI backend.
> LuaJIT is much faster and Lua is not recommended for production usage.
- Provides a lightweight raster pipeline (geometry, shapes).
- Supports RGB and RGBA color modes.
- Only requires `bit` library.
- This library does **not** perform any **compression**. Output files are uncompressed PNGs.

<p align="center">
  <img src="https://raw.githubusercontent.com/zeykatecool/luaPNG/refs/heads/main/benchmarks/benchmark_time.png" width="400">
  <img src="https://raw.githubusercontent.com/zeykatecool/luaPNG/refs/heads/main/benchmarks/benchmark_throughput.png" width="400">
</p>

# Usage
- Check `examples` folder for more examples.
> `luaPNG` selects the default runner based on `(require("luaPNG.init")).UsingJIT` variable.
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

# Benchmark
- You can run `benchmark/pure_lua_benchmark.lua` and `benchmark/ffipng_benchmark.lua` files to run the benchmark.
> It will give CSV file in `benchmark/output/*` folder.

## Known Issues
### png.lua
- `png.lua` slows down or crashes when encoding large RGBA images.

## License
- MIT License

