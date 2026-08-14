local Image = require("luaPNG.init")

local img = Image.new(256, 256, "rgb")

-- Add standard PNG text metadata
img:addMetadata({
    Title = "luaPNG Sample",
    Author = "luaPNG Developer",
    Description = "Encoded using luaPNG",
    Software = "luaPNG"
})

-- Generate simple pattern
for y = 0, 255 do
    for x = 0, 255 do
        local val = (x ~ y)
        img:setPixel(x, y, val, val, val)
    end
end

img:save("output/metadata_sample.png")
print("Saved metadata_sample.png")
