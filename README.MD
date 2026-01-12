# PNG Encoder For Lua and LuaJIT
- Blazingly fast PNG encoder written in Lua.
- Supports RGB and RGBA color modes.
- Only requires `bit` library.
- This library does **not** perform any **compression**. Output files are uncompressed PNGs.

> There is a `png.lua` for independent usage,without FFI.

# Usage
- Check `examples` folder for more examples.
```lua
local Image = require("luaPNG.init")

local png = Image.new(256, 256, "rgb")

for i = 1, 256*256*3 do
    png.Data[i] = math.random(0,255)
end

print(Image.UsingJIT)

png:save("Example256x256.png")
print("Done in: ", os.clock())
```


# Benchmark
- Check `benchmark\output\log` folder for benchmark results.
- LuaJIT is the default runner for benchmark but you can also use Lua which is very slow and not recommended.

**Runned benchmark with:** `ffipng.lua` using **LuaJIT 2.1.1753364724**

| LIB | W    | H    | MODE | ENCODE SEC | WRITE MB/s | STATUS |
| --- | ---- | ---- | ---- | ---------- | ---------- | ------ |
| FFI | 1000 | 1000 | RGB  | 0.030      | 95.41      | OK     |
| FFI | 1000 | 1000 | RGBA | 0.037      | 103.14     | OK     |
| FFI | 1500 | 1500 | RGB  | 0.067      | 96.11      | OK     |
| FFI | 1500 | 1500 | RGBA | 0.101      | 85.00      | OK     |
| FFI | 2000 | 2000 | RGB  | 0.183      | 62.55      | OK     |
| FFI | 2000 | 2000 | RGBA | 0.181      | 84.32      | OK     |
| FFI | 2500 | 2500 | RGB  | 0.244      | 73.30      | OK     |
| FFI | 2500 | 2500 | RGBA | 0.286      | 83.38      | OK     |

**Runned benchmark with:** `png.lua` using **LuaJIT 2.1.1753364724**

| LIB | W    | H    | MODE | ENCODE SEC | WRITE MB/s | STATUS |
| --- | ---- | ---- | ---- | ---------- | ---------- | ------ |
| LUA | 1000 | 1000 | RGB  | 0.059      | 48.51      | OK     |
| LUA | 1000 | 1000 | RGBA | 0.088      | 43.36      | OK     |
| LUA | 1500 | 1500 | RGB  | 0.121      | 53.22      | OK     |
| LUA | 1500 | 1500 | RGBA | 0.183      | 46.91      | OK     |
| LUA | 2000 | 2000 | RGB  | 0.225      | 50.88      | OK     |
| LUA | 2500 | 2500 | RGB  | 0.370      | 48.34      | OK     |

**Runned benchmark with:** `png.lua` using **Lua 5.4.6**

| LIB | W    | H    | MODE | ENCODE SEC | WRITE MB/s | STATUS |
| --- | ---- | ---- | ---- | ---------- | ---------- | ------ |
| LUA | 1000 | 1000 | rgb  | 1.165      | 2.46       | OK     |
| LUA | 1000 | 1000 | rgba | 2.063      | 1.85       | OK     |
| LUA | 1000 | 1500 | rgb  | 1.688      | 2.54       | OK     |
| LUA | 1000 | 1500 | rgba | 2.875      | 1.99       | OK     |
| LUA | 1000 | 2000 | rgb  | 2.503      | 2.29       | OK     |
| LUA | 1000 | 2000 | rgba | 4.533      | 1.68       | OK     |
| LUA | 1000 | 2500 | rgb  | 2.950      | 2.43       | OK     |
| LUA | 1000 | 2500 | rgba | 4.223      | 2.26       | OK     |
| LUA | 1500 | 1500 | rgb  | 3.126      | 2.06       | OK     |
| LUA | 1500 | 1500 | rgba | 4.278      | 2.01       | OK     |
| LUA | 2000 | 2000 | rgb  | 4.821      | 2.37       | OK     |
| LUA | 2000 | 2000 | rgba | 7.222      | 2.11       | OK     |
| LUA | 2500 | 2500 | rgb  | 7.492      | 2.39       | OK     |
| LUA | 2500 | 2500 | rgba | 10.933     | 2.18       | OK     |


## Known Issues
### png.lua
- `png.lua` slows down or crashes when encoding large RGBA images.
> LUA,2000,1000,rgba,8000000,61.04,0.0000,0,0.00,0.00,ERROR: .\lib\png.lua:56: too many results to unpack

## Graphs
- Check `benchmark\output\resultMatPlotLib.png` file for graph.

## License
- MIT License



