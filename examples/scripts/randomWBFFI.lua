local ffiPng = require("lib.ffipng")
local width, height = 512, 512
local colorMode = "rgb"
local channels = 3


local pixels = {}
for y = 0, height-1 do
    for x = 0, width-1 do
        local val = math.random(0,1) * 255
        for c = 1, channels do
            pixels[y*width*channels + x*channels + c] = val
        end
    end
end

local png = ffiPng(width, height, colorMode)
png:write(pixels)
local f = io.open("../output/randomWB.png", "wb")
f:write(png:getData())
f:close()
print("Done in: ", os.clock())