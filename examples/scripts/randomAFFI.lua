local ffiPng = require("lib.ffipng")
local width, height = 256, 256
local colorMode = "rgba"
local channels = 4
local totalPixels = width * height * channels

local pixels = {}
for i = 1, totalPixels do
    pixels[i] = math.random(0,255)
end

local png = ffiPng(width, height, colorMode)
png:write(pixels)
local f = io.open("../output/randomRGBA.png", "wb")
f:write(png:getData())
f:close()
print("Done in: ", os.clock())