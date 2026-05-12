local Image = require("luaPNG.init")

local png = Image.new(256, 256, "rgba")

png:addMetadata("test","signature")

for i = 1, 256 * 256 * 4 do
    png.Data[i] = math.random(0, 255)
end

png:save("randomRGBA_Metadata.png")

print("Done in:", os.clock())
