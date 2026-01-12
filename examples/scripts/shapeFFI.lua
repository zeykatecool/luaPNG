local Image = require("luaPNG.main")

local width, height = 512, 512
local png = Image.new(width, height, "rgb")

local function generateChecker(size)
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            local isWhite = ((math.floor(x / size) + math.floor(y / size)) % 2 == 0)
            local val = isWhite and 255 or 0
            local base = y * width * 3 + x * 3
            png.Data[base + 1] = val
            png.Data[base + 2] = val
            png.Data[base + 3] = val
        end
    end
end

generateChecker(32)
png:save("../output/shape.png")

print("Done in:", os.clock())
