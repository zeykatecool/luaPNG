--main.lua
local Image = {}
Image.__index = Image

---@diagnostic disable-next-line: undefined-global
Image.UsingJIT = jit and true or false

local PNGLib = Image.UsingJIT and require("luaPNG.ffipng") or require("luaPNG.png")

---@class Image
---@field Width number Width of the image.
---@field Height number Height of the image.
---@field ColorMode "rgb" | "rgba" Color mode of the image.
---@field write fun(self : Image,Pixels: number[]): boolean Writes pixels to the PNG file,expects an `Array`, returns `true` on success.
---@field save fun(self : Image, Path: string): boolean Saves the image to a file, returns `true` on success.
---@field Data number[] The image data,an `Array`.

---@param Width number Width of the image.
---@param Height number Height of the image.
---@param ColorMode "rgb" | "rgba" Color mode of the image.
---@return Image
function Image.new(Width, Height, ColorMode)
    local obj = setmetatable({}, Image)
    obj.Width = Width
    obj.Height = Height
    obj.ColorMode = ColorMode
    obj.Data = {}
    function obj:write(Pixels)
        self.Data = Pixels
        return true
    end

    function obj:save(Path)
        local PNG = PNGLib(self.Width, self.Height, self.ColorMode)
        PNG:write(self.Data)
        local File = io.open(Path, "wb") or error("Failed to open file while saving image.")
        File:write(PNG:getData())
        File:close()
        return true
    end

    return obj
end

return Image
