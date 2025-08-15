local ffiPng = require("lib.ffipng")

local width, height = 512, 512
local colorMode = "rgb"
local channels = 3

local function generateChecker(size)
    local pixels = {}
    for y = 0, height-1 do
        for x = 0, width-1 do
            local isWhite = ((x/size + y/size) % 2 == 0)
            for c = 1, channels do
                pixels[y*width*channels + x*channels + c] = isWhite and 255 or 0
            end
        end
    end
    return pixels
end

local pixels = generateChecker(32)
local png = ffiPng(width, height, colorMode)
png:write(pixels)
local f = io.open("../output/shape.png", "wb")
f:write(png:getData())
f:close()
print("Done in: ", os.clock())