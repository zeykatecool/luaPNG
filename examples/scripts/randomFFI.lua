local Image = require("luaPNG.main")

local png = Image.new(256, 256, "rgb")

for i = 1, 256 * 256 * 3 do
    png.Data[i] = math.random(0, 255)
end

png:save("../output/randomRGB.png")

print("Done in:", os.clock())
