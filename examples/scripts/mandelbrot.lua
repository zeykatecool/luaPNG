local Image = require("luaPNG.init")

local width, height = 800, 600
local img = Image.new(width, height, "rgb")

local max_iter = 64

for py = 0, height - 1 do
    local y0 = (py / height) * 2.4 - 1.2
    for px = 0, width - 1 do
        local x0 = (px / width) * 3.2 - 2.2
        local x, y = 0, 0
        local iter = 0

        while (x * x + y * y <= 4) and (iter < max_iter) do
            local xtemp = x * x - y * y + x0
            y = 2 * x * y + y0
            x = xtemp
            iter = iter + 1
        end

        if iter == max_iter then
            img:setPixel(px, py, 0, 0, 0)
        else
            local t = iter / max_iter
            local r = math.floor(9 * (1 - t) * t * t * t * 255)
            local g = math.floor(15 * (1 - t) * (1 - t) * t * t * 255)
            local b = math.floor(8.5 * (1 - t) * (1 - t) * (1 - t) * t * 255)
            img:setPixel(px, py, r, g, b)
        end
    end
end

img:save("output/mandelbrot.png")
print("Saved mandelbrot.png")
