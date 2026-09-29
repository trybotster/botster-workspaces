-- botster_workspaces.spawn up to the Hub spawn helper. The in-process kit
-- starts no session worker, so a completed spawn is proven end to end.
-- Run: botster-plugin-test --plugin . test/spawn_spec.lua
local kit = require("botster.test")
local ws = require("support")

local function spawn(t, p, args)
  return ws.call(t, p, "botster_workspaces.spawn", args)
end

-- Regression for 742891f: spawn_targets.list returns { ok, value = rows } and
-- the plugin iterated the wrapper, so no admitted target was ever found.
kit.test("spawn finds an admitted spawn target", function(t)
  local p = t:load(".")
  ws.admit_target(t, "plain", "Plain", "directory")
  local a = ws.create(t, p, "Alpha")
  local r = spawn(t, p, { workspace_id = a, target_id = "plain", session_type_id = "none" })
  t:ok(r.error.code ~= "spawn_target_not_found", "the admitted target was found: " .. tostring(r.error.code))
end)

kit.test("spawn refuses an unknown target and records nothing", function(t)
  local p = t:load(".")
  local a = ws.create(t, p, "Alpha")
  t:eq(spawn(t, p, { workspace_id = a, target_id = "missing", session_type_id = "x" }).error.code,
    "spawn_target_not_found")
  t:eq(#ws.workspace(t, p, a).session_refs, 0)
end)

-- S4
kit.test("a git target needs a branch", function(t)
  local p = t:load(".")
  ws.admit_target(t, "repo", "Repo", "git")
  local a = ws.create(t, p, "Alpha")
  local r = spawn(t, p, { workspace_id = a, target_id = "repo", session_type_id = "x" })
  t:eq(r.error.code, "validation_failed")
  t:eq(r.fields, { "branch" })
end)

-- S5, S6, S7, L1
kit.test("spawn refuses caller-chosen ids, obsolete fields, and a missing session type", function(t)
  local p = t:load(".")
  local a = ws.create(t, p, "Alpha")
  t:eq(spawn(t, p, { workspace_id = a, target_id = "t", session_type_id = "x", session_id = "s" }).error.code,
    "unknown_field")
  local r = spawn(t, p, { workspace_id = a, target_id = "t", session_type_id = "x", template_id = "old" }) -- cold-cut negative control
  t:eq(r.error.code, "unknown_field")
  t:eq(r.fields, { "template_id" }) -- cold-cut negative control
  r = spawn(t, p, { workspace_id = a, target_id = "t" })
  t:eq(r.error.code, "validation_failed")
  t:eq(r.fields, { "session_type_id" })
  t:eq(#ws.workspace(t, p, a).session_refs, 0)
end)

-- S3 up to the Hub: a directory target reaches session_types.spawn, whose
-- refusal (an unknown session type) is reported and records nothing.
kit.test("a Hub spawn refusal is reported and records nothing", function(t)
  local p = t:load(".")
  ws.admit_target(t, "plain", "Plain", "directory")
  local a = ws.create(t, p, "Alpha")
  local r = spawn(t, p, { workspace_id = a, target_id = "plain", session_type_id = "none" })
  t:eq(r.ok, false)
  t:eq(r.error.code, "hub_spawn_failed")
  t:eq(#ws.workspace(t, p, a).session_refs, 0)
end)
