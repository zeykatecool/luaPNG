local Image = require("luaPNG.init")

local png = Image.new(256, 256, "rgba")

png:addSignature("test signature") -- It should shown in the metadata of the image when opening it with a program that can read it.

for i = 1, 256 * 256 * 4 do
    png.Data[i] = math.random(0, 255)
end

png:save("randomRGBA_Signature.png")

print("Done in:", os.clock())
