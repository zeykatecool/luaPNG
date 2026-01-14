local Image = require("luaPNG.init")
local img = Image.new(800, 600, "rgba")


img:add(Geometry.Rectangle{
    x = 120, y = 140,
    w = 280, h = 280,
    color = {220, 60, 60, 180},
    mode = "fill"
})

img:add(Geometry.Triangle{
    x1 = 500, y1 = 80,
    x2 = 720, y2 = 220,
    x3 = 580, y3 = 480,
    color = {60, 140, 220, 255},
    mode = "fill"
})

img:add(Geometry.Triangle{
    x1 = 500, y1 = 80,
    x2 = 720, y2 = 220,
    x3 = 580, y3 = 480,
    color = {255, 220, 60, 255},
    mode = "stroke"
})

for i = 1, 6 do
    local alpha = math.floor(60 + i * 30)
    img:add(Geometry.Rectangle{
        x = 200 + i*40,
        y = 300 + i*20,
        w = 180,
        h = 140,
        color = {100, 200, 255, alpha},
        mode = "fill"
    })
end

local colors = {
    {255,0,0,255}, {0,255,0,220}, {0,180,255,200},
    {255,180,0,180}, {220,0,220,160}
}

for i = 1, 5 do
    local y = 100 + i * 80
    img:add(Geometry.Line{
        x1 = 50,  y1 = y,
        x2 = 750, y2 = y + 40,
        color = colors[i],
        thickness = 3 + i*2
    })
end


local accents = {
    {x=20,  y=20,  col={255,80,80,220}},
    {x=800-140, y=20, col={80,255,80,200}},
    {x=20,  y=600-140, col={80,80,255,180}},
    {x=800-140, y=600-140, col={255,220,100,160}}
}

img:save("../output/example_shapes.png")
print("Done in:", os.clock())