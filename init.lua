local Image = {}
local ImageMethods = {}
Geometry = require("luaPNG.geometry")
ImageMethods.__index = ImageMethods

Image.UsingJIT = jit and true or false

local PNGLib = Image.UsingJIT and require("luaPNG.ffipng") or require("luaPNG.png")

local function drawLine(img, x0, y0, x1, y1, r, g, b, a)
    local dx = math.abs(x1 - x0)
    local dy = math.abs(y1 - y0)
    local sx = (x0 < x1) and 1 or -1
    local sy = (y0 < y1) and 1 or -1
    local err = dx - dy

    while true do
        img:setPixel(x0, y0, r, g, b, a)
        if x0 == x1 and y0 == y1 then break end
        local e2 = err * 2
        if e2 > -dy then
            err = err - dy; x0 = x0 + sx
        end
        if e2 < dx then
            err = err + dx; y0 = y0 + sy
        end
    end
end

local function edge(ax, ay, bx, by, cx, cy)
    return (cx - ax) * (by - ay) - (cy - ay) * (bx - ax)
end

local function rasterRectangle(img, g)
    local x0 = g.x
    local y0 = g.y
    local x1 = x0 + g.w - 1
    local y1 = y0 + g.h - 1

    local c = g.color
    local r, g_, b, a = c[1], c[2], c[3], c[4]

    if g.mode == "fill" then
        for y = y0, y1 do
            for x = x0, x1 do
                img:setPixel(x, y, r, g_, b, a)
            end
        end
    else
        for x = x0, x1 do
            img:setPixel(x, y0, r, g_, b, a)
            img:setPixel(x, y1, r, g_, b, a)
        end
        for y = y0, y1 do
            img:setPixel(x0, y, r, g_, b, a)
            img:setPixel(x1, y, r, g_, b, a)
        end
    end
end

local function fpart(x) return x - math.floor(x) end
local function rfpart(x) return 1 - fpart(x) end

local function drawLineAA(img, x0, y0, x1, y1, r, g, b, a)
    local steep = math.abs(y1 - y0) > math.abs(x1 - x0)
    if steep then
        x0, y0 = y0, x0; x1, y1 = y1, x1
    end
    if x0 > x1 then
        x0, x1 = x1, x0; y0, y1 = y1, y0
    end

    local dx = x1 - x0
    local dy = y1 - y0
    local gradient = (dx == 0) and 1 or dy / dx

    local xend = math.floor(x0 + 0.5)
    local yend = y0 + gradient * (xend - x0)
    local xpxl1 = xend
    local ypxl1 = math.floor(yend)

    local function plot(x, y, c)
        if steep then
            img:setPixel(y, x, r, g, b, (a or 255) * c)
        else
            img:setPixel(x, y, r, g, b, (a or 255) * c)
        end
    end

    plot(xpxl1, ypxl1, rfpart(yend))
    plot(xpxl1, ypxl1 + 1, fpart(yend))
    local intery = yend + gradient

    for x = xpxl1 + 1, x1 - 1 do
        plot(x, math.floor(intery), rfpart(intery))
        plot(x, math.floor(intery) + 1, fpart(intery))
        intery = intery + gradient
    end

    xend = math.floor(x1 + 0.5)
    yend = y1 + gradient * (xend - x1)
    plot(xend, math.floor(yend), rfpart(yend))
    plot(xend, math.floor(yend) + 1, fpart(yend))
end


local function edgeSignedDistance(ax, ay, bx, by, px, py)
    local ex = bx - ax
    local ey = by - ay
    local len = math.sqrt(ex * ex + ey * ey)
    if len == 0 then
        return 1e9
    end
    local cross = (px - ax) * ey - (py - ay) * ex
    return cross / len
end

local function blendPixel(img, x, y, r, g, b, coverage)
    if coverage <= 0 then return end
    if coverage >= 0.999 then
        img:setPixel(x, y, r, g, b, 255)
        return
    end

    local channels = (img.ColorMode == "rgba") and 4 or 3
    local i = (y * img.Width + x) * channels
    local d = img.Data

    local dr = (d[i + 1] or 0)
    local dg = (d[i + 2] or 0)
    local db = (d[i + 3] or 0)

    local inv = 1 - coverage
    d[i + 1] = math.floor(dr * inv + r * coverage + 0.5)
    d[i + 2] = math.floor(dg * inv + g * coverage + 0.5)
    d[i + 3] = math.floor(db * inv + b * coverage + 0.5)

    if channels == 4 then
        d[i + 4] = d[i + 4] or 255
    end
end

local function rasterTriangleAA(img, t)
    local x1, y1 = t.x1, t.y1
    local x2, y2 = t.x2, t.y2
    local x3, y3 = t.x3, t.y3

    local c = t.color
    local r, g, b, a = c[1], c[2], c[3], c[4] or 255

    local minX = math.max(0, math.floor(math.min(x1, x2, x3)))
    local maxX = math.min(img.Width - 1, math.ceil(math.max(x1, x2, x3)))
    local minY = math.max(0, math.floor(math.min(y1, y2, y3)))
    local maxY = math.min(img.Height - 1, math.ceil(math.max(y1, y2, y3)))

    local triArea = edge(x1, y1, x2, y2, x3, y3)
    local insidePositive = triArea > 0

    local ex1, ey1 = x2 - x1, y2 - y1
    local ex2, ey2 = x3 - x2, y3 - y2
    local ex3, ey3 = x1 - x3, y1 - y3
    local len1 = math.sqrt(ex1 * ex1 + ey1 * ey1)
    local len2 = math.sqrt(ex2 * ex2 + ey2 * ey2)
    local len3 = math.sqrt(ex3 * ex3 + ey3 * ey3)

    for y = minY, maxY do
        for x = minX, maxX do
            local px, py = x + 0.5, y + 0.5

            local d1 = edgeSignedDistance(x1, y1, x2, y2, px, py) / (len1 ~= 0 and 1 or 1)
            local d2 = edgeSignedDistance(x2, y2, x3, y3, px, py) / (len2 ~= 0 and 1 or 1)
            local d3 = edgeSignedDistance(x3, y3, x1, y1, px, py) / (len3 ~= 0 and 1 or 1)

            if not insidePositive then
                d1, d2, d3 = -d1, -d2, -d3
            end

            if d1 >= 0 and d2 >= 0 and d3 >= 0 then
                img:setPixel(x, y, r, g, b, 255)
            else
                local minD = math.min(d1, d2, d3)
                if minD > -1.0 then
                    local coverage = math.max(0, math.min(1, 1 + minD))
                    if coverage > 0.001 then
                        if img.ColorMode == "rgba" and a and a < 255 then
                            local alphaCoverage = (a / 255) * coverage
                            local blendedA = math.floor((img.Data[(y * img.Width + x) * ((img.ColorMode == "rgba") and 4 or 3) + 4] or 255) * (1 - alphaCoverage) + 255 * alphaCoverage + 0.5) -- calis amk
                            blendPixel(img, x, y, r, g, b, alphaCoverage)
                            local channels = (img.ColorMode == "rgba") and 4 or 3
                            if channels == 4 then
                                local idx = (y * img.Width + x) * channels
                                img.Data[idx + 4] = blendedA
                            end
                        else
                            blendPixel(img, x, y, r, g, b, coverage)
                        end
                    end
                end
            end
        end
    end
end




local function rasterTriangle(img, t)
    local x1, y1 = t.x1, t.y1
    local x2, y2 = t.x2, t.y2
    local x3, y3 = t.x3, t.y3

    local c = t.color
    local r, g, b, a = c[1], c[2], c[3], c[4]

    if t.mode == "fill" then
        rasterTriangleAA(img, t)
    else
        drawLineAA(img, x1, y1, x2, y2, r, g, b, a)
        drawLineAA(img, x2, y2, x3, y3, r, g, b, a)
        drawLineAA(img, x3, y3, x1, y1, r, g, b, a)
    end
end

function Image.new(Width, Height, ColorMode)
    local obj = setmetatable({}, ImageMethods)
    obj.Width = Width
    obj.Height = Height
    obj.ColorMode = ColorMode

    local channels = (ColorMode == "rgba") and 4 or 3
    obj.Data = {}

    local r, g, b, a = 0, 0, 0, 255

    for i = 1, Width * Height do
        local base       = (i - 1) * channels + 1

        obj.Data[base]   = r
        obj.Data[base + 1] = g
        obj.Data[base + 2] = b

        if channels == 4 then
            obj.Data[base + 3] = a
        end
    end

    return obj
end

function ImageMethods:setPixel(x, y, r, g, b, a)
    if x < 0 or y < 0 or x >= self.Width or y >= self.Height then
        return
    end

    local channels = (self.ColorMode == "rgba") and 4 or 3
    local i = (y * self.Width + x) * channels
    local d = self.Data

    if channels == 4 and a and a < 255 then
        local srcAlpha = a / 255
        local dstAlpha = (d[i + 4] or 0) / 255

        if dstAlpha > 0.001 then
            local outAlpha = srcAlpha + dstAlpha * (1 - srcAlpha)
            d[i + 1] = (r * srcAlpha + d[i + 1] * dstAlpha * (1 - srcAlpha)) / outAlpha
            d[i + 2] = (g * srcAlpha + d[i + 2] * dstAlpha * (1 - srcAlpha)) / outAlpha
            d[i + 3] = (b * srcAlpha + d[i + 3] * dstAlpha * (1 - srcAlpha)) / outAlpha
            d[i + 4] = outAlpha * 255
        else
            d[i + 1] = r
            d[i + 2] = g
            d[i + 3] = b
            d[i + 4] = a
        end
    else
        d[i + 1] = r
        d[i + 2] = g
        d[i + 3] = b
        if channels == 4 then
            d[i + 4] = a or 255
        end
    end
end


local function distPointToSegment(x1, y1, x2, y2, px, py)
    local vx = x2 - x1
    local vy = y2 - y1
    local wx = px - x1
    local wy = py - y1

    local c1 = wx * vx + wy * vy
    if c1 <= 0 then
        return math.sqrt(wx*wx + wy*wy)
    end

    local c2 = vx*vx + vy*vy
    if c2 <= c1 then
        local dx = px - x2
        local dy = py - y2
        return math.sqrt(dx*dx + dy*dy)
    end

    local b = c1 / c2
    local bx = x1 + b * vx
    local by = y1 + b * vy
    local dx = px - bx
    local dy = py - by
    return math.sqrt(dx*dx + dy*dy)
end


local function rasterLineAA(img, x1, y1, x2, y2, thickness, r, g, b, a)
    local half = thickness * 0.5

    local minX = math.floor(math.min(x1, x2) - half - 1)
    local maxX = math.ceil (math.max(x1, x2) + half + 1)
    local minY = math.floor(math.min(y1, y2) - half - 1)
    local maxY = math.ceil (math.max(y1, y2) + half + 1)

    minX = math.max(0, minX)
    minY = math.max(0, minY)
    maxX = math.min(img.Width - 1, maxX)
    maxY = math.min(img.Height - 1, maxY)

    for y = minY, maxY do
        for x = minX, maxX do
            local px = x + 0.5
            local py = y + 0.5

            local d = distPointToSegment(x1, y1, x2, y2, px, py)

            if d < half + 1.0 then
                local coverage
                if d <= half then
                    coverage = 1.0
                else
                    coverage = 1.0 - (d - half)
                end

                if coverage > 0 then
                    blendPixel(img, x, y, r, g, b, coverage)
                end
            end
        end
    end
end


function ImageMethods:drawLine(x0, y0, x1, y1, r, g, b, a)
    drawLine(self, x0, y0, x1, y1, r, g, b, a)
end

function ImageMethods:add(geometry)
    if geometry.__type == "rectangle" then
        rasterRectangle(self, geometry)
    elseif geometry.__type == "triangle" then
        rasterTriangle(self, geometry)
    elseif geometry.__type == "line" then
        rasterLineAA(self, geometry.x1, geometry.y1, geometry.x2, geometry.y2, geometry.thickness, geometry.color[1], geometry.color[2], geometry.color[3], geometry.color[4])
    else
        error("Unsupported geometry type: " .. tostring(geometry.__type))
    end
end

function ImageMethods:write(Pixels)
    self.Data = Pixels
    return true
end

function ImageMethods:save(Path)
    local PNG = PNGLib(self.Width, self.Height, self.ColorMode)
    PNG:write(self.Data)
    local File = io.open(Path, "wb") or error("Failed to open file while saving image.")
    File:write(PNG:getData())
    File:close()
    return true
end

return Image
