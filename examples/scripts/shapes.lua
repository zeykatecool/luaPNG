local Image = require("luaPNG.init")
local Geometry = require("luaPNG.geometry")

local img = Image.new(640, 480, "rgba")

-- Background fill
img:add(Geometry.Rectangle{
    x = 0, y = 0, width = 640, height = 480,
    color = {30, 32, 40, 255},
    mode = "fill"
})

-- Filled and stroked rectangles with transparency
img:add(Geometry.Rectangle{
    x = 60, y = 60, width = 200, height = 150,
    color = {220, 70, 70, 200},
    mode = "fill"
})

img:add(Geometry.Rectangle{
    x = 160, y = 120, width = 200, height = 150,
    color = {70, 160, 240, 180},
    mode = "fill"
})

-- Antialiased Triangle
img:add(Geometry.Triangle{
    x1 = 480, y1 = 60,
    x2 = 600, y2 = 260,
    x3 = 360, y3 = 260,
    color = {80, 220, 120, 220},
    mode = "fill"
})

img:add(Geometry.Triangle{
    x1 = 480, y1 = 60,
    x2 = 600, y2 = 260,
    x3 = 360, y3 = 260,
    color = {255, 255, 255, 255},
    mode = "stroke"
})

-- Antialiased Lines with thickness
for i = 1, 5 do
    img:add(Geometry.Line{
        x1 = 60, y1 = 340 + (i * 20),
        x2 = 580, y2 = 300 + (i * 30),
        thickness = i,
        color = {240, 180, 50, 255 - i * 30}
    })
end

img:save("output/shapes.png")
print("Saved shapes.png")
