-- Strict globals: the plugin's Lua uses no global that the sandbox lacks.
-- Run: botster-plugin-test --plugin . test/globals_spec.lua
--
-- Regression: an error path used the bare global `log` (the sandbox has
-- `botster.log`). No runtime spec reached that path, so every spec passed and
-- the call would fail in production. The check parses the plugin's Lua and
-- compares every global name with the sandbox's real global set.
local kit = require("botster.test")

kit.test("botster-workspaces uses no global name that the sandbox does not define", function(t)
  local p = t:load(".")
  local found = p:undefined_globals()
  local names = {}
  for _, use in ipairs(found) do
    names[#names + 1] = use.file .. ":" .. use.line .. " " .. use.name
  end
  t:eq(#found, 0, "undefined globals: " .. table.concat(names, ", "))
end)
