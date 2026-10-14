-- Uso: lua5.1 hash_check.lua ruta/Core.lua texto1 texto2 ...  → imprime MES.Hash de cada texto
local core = arg[1]
local MES = {}
_G.UnitName = function() return nil end
_G.CreateFont = function() end
local chunk = assert(loadfile(core))
chunk("MisionesES", MES)
for i = 2, #arg do print(MES.Hash(arg[i])) end
