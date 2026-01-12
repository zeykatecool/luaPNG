local Image = require("luaPNG.main")

local png = Image.new(256, 256, "rgba")

for i = 1, 256 * 256 * 4 do
    png.Data[i] = math.random(0, 255)
end

png:save("../output/randomRGBA.png")

print("Done in:", os.clock())
