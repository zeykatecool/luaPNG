-- geometry.lua
local Geometry = {}

--- @param GeometryRectangle_Args {
---     x?: number,
---     y?: number,
---     width?: number,
---     height?: number,
---     color?: number[],
---     mode?: "fill" | "stroke"}
function Geometry.Rectangle(GeometryRectangle_Args)
    return {
        __type = "rectangle",
        x = GeometryRectangle_Args.x or 0,
        y = GeometryRectangle_Args.y or 0,
        w = GeometryRectangle_Args.width or 0,
        h = GeometryRectangle_Args.height or 0,
        color = GeometryRectangle_Args.color or { 0, 0, 0, 255 },
        mode = GeometryRectangle_Args.mode or "fill"
    }
end

--- @param GeometryTriangle_Args {
---     x1?: number,
---     y1?: number,
---     x2?: number,
---     y2?: number,
---     x3?: number,
---     y3?: number,
---     color?: number[],
---     mode?: "fill" | "stroke"}
function Geometry.Triangle(GeometryTriangle_Args)
    return {
        __type = "triangle",
        x1 = GeometryTriangle_Args.x1 or 0,
        y1 = GeometryTriangle_Args.y1 or 0,
        x2 = GeometryTriangle_Args.x2 or 0,
        y2 = GeometryTriangle_Args.y2 or 0,
        x3 = GeometryTriangle_Args.x3 or 0,
        y3 = GeometryTriangle_Args.y3 or 0,
        color = GeometryTriangle_Args.color or { 0, 0, 0, 255 },
        mode = GeometryTriangle_Args.mode or "fill"
    }
end

--- @param GeometryLine_Args {
---     x1?: number,
---     y1?: number,
---     x2?: number,
---     y2?: number,
---     thickness?: number,
---     color?: number[]}
function Geometry.Line(GeometryLine_Args)
    return {
        __type = "line",
        x1 = GeometryLine_Args.x1 or 0,
        y1 = GeometryLine_Args.y1 or 0,
        x2 = GeometryLine_Args.x2 or 0,
        y2 = GeometryLine_Args.y2 or 0,
        thickness = GeometryLine_Args.thickness or 1,
        color = GeometryLine_Args.color or { 0, 0, 0, 255 },
    }
end


return Geometry
