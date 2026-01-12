local Image = require("luaPNG.main")

local width, height = 512, 512
local png = Image.new(width, height, "rgb")

for y = 0, height - 1 do
    for x = 0, width - 1 do
        local val = math.random(0, 1) * 255
        local base = y * width * 3 + x * 3
        png.Data[base + 1] = val
        png.Data[base + 2] = val
        png.Data[base + 3] = val
    end
end

png:save("../output/randomWB.png")

print("Done in:", os.clock())
