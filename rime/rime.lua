-- rime.lua
-- Entry point for Rime Lua extensions
-- Exposes smart_undo processor to hindi_ai schema

-- Ensure Lua module search path includes both root and lua/ subfolder
local rime_user_dir = (rime_api and rime_api.get_user_data_dir and rime_api.get_user_data_dir()) or ""
if rime_user_dir ~= "" then
    package.path = package.path .. ";" .. rime_user_dir .. "/lua/?.lua;" .. rime_user_dir .. "/?.lua"
end
package.path = package.path .. ";./lua/?.lua;./?.lua"

local ok, mod = pcall(require, "smart_undo")
if ok then
    smart_undo = mod
else
    local ok2, mod2 = pcall(require, "lua.smart_undo")
    if ok2 then
        smart_undo = mod2
    end
end
