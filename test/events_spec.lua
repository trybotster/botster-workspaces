-- Event input: the Hub session family.
-- Run: botster-plugin-test --plugin . test/events_spec.lua
local kit = require("botster.test")
local ws = require("support")

-- F1-F6: the session family prunes ended sessions and keeps the rest.
local function grouped(t, p, ids)
  local a = ws.create(t, p, "Alpha")
  for _, id in ipairs(ids) do
    ws.call(t, p, "botster_workspaces.add_session", { workspace_id = a, session_id = id })
  end
  return a
end

kit.test("a current session keeps its membership; an ended one is pruned", function(t)
  local p = t:load(".")
  local hub_id = ws.hub_id(t, p)
  local a = grouped(t, p, { "session-a", "session-b" })
  t:sessions_baseline({
    kit.session({ id = "session-a", state = "running" }),
    kit.session({ id = "session-b", state = "exited", code = 0 }),
  })
  t:eq(ws.workspace(t, p, a).session_refs, { ws.ref(hub_id, "session-a") })
  t:eq(p:db_get(ws.key(hub_id, "session-b")), nil)
  t:session_upsert(kit.session({ id = "session-a", state = "exited", code = 0 }))
  t:eq(#ws.workspace(t, p, a).session_refs, 0)
end)

kit.test("a session missing from the baseline, or removed, keeps its membership", function(t)
  local p = t:load(".")
  local hub_id = ws.hub_id(t, p)
  local a = grouped(t, p, { "session-a", "session-gone" })
  t:sessions_baseline({ kit.session({ id = "session-a", state = "running" }) })
  t:session_remove("session-a")
  t:eq(ws.workspace(t, p, a).session_refs, { ws.ref(hub_id, "session-a"), ws.ref(hub_id, "session-gone") })
end)
