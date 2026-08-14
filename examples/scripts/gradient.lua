local Image = require("luaPNG.init")

local width, height = 512, 512
local img = Image.new(width, height, "rgb")

for y = 0, height - 1 do
    for x = 0, width - 1 do
        local r = math.floor((x / width) * 255)
        local g = math.floor((y / height) * 255)
        local b = math.floor(((x + y) / (width + height)) * 255)
        img:setPixel(x, y, r, g, b)
    end
end

img:save("output/gradient.png")
print("Saved gradient.png")
