package = "luapng"
version = "1.0-1"
source = {
  url = "git+https://github.com/zeykatecool/luaPNG",
  md5 = ""
}
description = {
  summary = "Blazingly fast PNG encoder for LuaJIT (FFI) with fallback pure Lua version",
  detailed = [[
    Provides two modules:
    - ffipng.lua: Fast PNG encoder using LuaJIT FFI.
    - png.lua: Pure Lua PNG encoder (bit dependency only).
  ]],
  homepage = "https://github.com/zeykatecool/luaPNG",
  license = "MIT"
}
build = {
  type = "builtin",
  modules = {
    ffipng = "ffipng.lua",
    png = "png.lua",
  }
}
dependencies = {
  "lua >= 5.1",
  "bit32"
}

