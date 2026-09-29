-- Membership: add, move, remove, the durable index, and membership entities.
-- Run: botster-plugin-test --plugin . test/membership_spec.lua
local kit = require("botster.test")
local ws = require("support")

local function add(t, p, workspace_id, session_id, extra)
  local args = { workspace_id = workspace_id, session_id = session_id }
  for key, value in pairs(extra or {}) do
    args[key] = value
  end
  return ws.call(t, p, "botster_workspaces.add_session", args)
end

-- M1, M2
kit.test("add records { hub_id, session_id } in the workspace and the index", function(t)
  local p = t:load(".")
  local a = ws.create(t, p, "Alpha")
  local hub_id = ws.hub_id(t, p)
  t:eq(add(t, p, a, "session-a").ok, true)
  t:eq(ws.workspace(t, p, a).session_refs, { ws.ref(hub_id, "session-a") })
  t:eq(p:db_get(ws.key(hub_id, "session-a")), { hub_id = hub_id, session_id = "session-a", workspace_id = a })
end)

-- M3, M13
kit.test("re-adding to the same workspace is an idempotent no-op", function(t)
  local p = t:load(".")
  local a = ws.create(t, p, "Alpha")
  add(t, p, a, "session-a")
  local frames = #p:entities(ws.MEMBERSHIP)
  local again = add(t, p, a, "session-a")
  t:eq(again.ok, true)
  t:eq(again.idempotent, true)
  t:eq(again.membership_delivery, "none")
  t:eq(#again.workspace.session_refs, 1)
  t:eq(#p:entities(ws.MEMBERSHIP), frames)
end)

-- M4, M5, M6
kit.test("a session belongs to one workspace; ids are validated", function(t)
  local p = t:load(".")
  local a = ws.create(t, p, "Alpha")
  local b = ws.create(t, p, "Beta")
  add(t, p, a, "session-a")
  local conflict = add(t, p, b, "session-a")
  t:eq(conflict.error.code, "session_already_owned")
  t:eq(conflict.owner_workspace_id, a)
  t:eq(add(t, p, a, "   ").error.code, "validation_failed")
  t:eq(add(t, p, a, "session-b").ok, true)
  t:eq(#ws.workspace(t, p, a).session_refs, 2)
end)

kit.test("add refuses a remote hub and accepts the local hub id", function(t)
  local p = t:load(".")
  local a = ws.create(t, p, "Alpha")
  local hub_id = ws.hub_id(t, p)
  t:eq(add(t, p, a, "session-a", { hub_id = "hub-elsewhere" }).error.code, "remote_hub_unsupported")
  t:eq(add(t, p, a, "session-a", { hub_id = hub_id }).ok, true)
end)

-- M7, M8, M9
kit.test("move changes the owner atomically; remove clears the index; re-add works", function(t)
  local p = t:load(".")
  local a = ws.create(t, p, "Alpha")
  local b = ws.create(t, p, "Beta")
  local hub_id = ws.hub_id(t, p)
  add(t, p, a, "session-a")
  local moved = ws.call(t, p, "botster_workspaces.move_session", { destination_workspace_id = b, session_id = "session-a" })
  t:eq(moved.ok, true)
  t:eq(#ws.workspace(t, p, a).session_refs, 0)
  t:eq(ws.workspace(t, p, b).session_refs, { ws.ref(hub_id, "session-a") })
  t:eq(p:db_get(ws.key(hub_id, "session-a")).workspace_id, b)
  local removed = ws.call(t, p, "botster_workspaces.remove_session", { workspace_id = b, session_id = "session-a" })
  t:eq(removed.ok, true)
  t:eq(#ws.workspace(t, p, b).session_refs, 0)
  t:eq(p:db_get(ws.key(hub_id, "session-a")), nil)
  t:eq(add(t, p, a, "session-a").ok, true)
end)

-- E1-E4: membership entities carry { hub_id, session_id } and use one id form.
kit.test("membership mutations publish upsert and remove frames keyed by hub and session", function(t)
  local p = t:load(".")
  p:entities(ws.MEMBERSHIP)
  local a = ws.create(t, p, "Alpha")
  local b = ws.create(t, p, "Beta")
  local hub_id = ws.hub_id(t, p)
  local id = hub_id .. "/session-a"
  add(t, p, a, "session-a")
  ws.call(t, p, "botster_workspaces.move_session", { destination_workspace_id = b, session_id = "session-a" })
  ws.call(t, p, "botster_workspaces.remove_session", { workspace_id = b, session_id = "session-a" })
  -- The kit subscribes as a client: a snapshot frame first, then live deltas.
  -- p:entities returns each frame itself: { type, id, entity, ... }.
  t:match(p:entities(ws.MEMBERSHIP), {
    { type = "entity_snapshot", entity_type = ws.MEMBERSHIP },
    { type = "entity_upsert", id = id,
      entity = { id = id, hub_id = hub_id, session_id = "session-a", workspace_id = a } },
    { type = "entity_upsert", id = id, entity = { workspace_id = b } },
    { type = "entity_remove", id = id },
  })
end)

-- Agent tool: move_agent_workspace adds an ungrouped session and moves a grouped one.
kit.test("move_agent_workspace adds, then moves", function(t)
  local p = t:load(".")
  local a = ws.create(t, p, "Alpha")
  local b = ws.create(t, p, "Beta")
  local hub_id = ws.hub_id(t, p)
  t:eq(ws.call(t, p, "move_agent_workspace", { session_id = "session-a", workspace_id = a }).ok, true)
  local moved = ws.call(t, p, "move_agent_workspace", { session_id = "session-a", workspace_id = b, hub_id = hub_id })
  t:eq(moved.ok, true)
  t:eq(moved.destination.id, b)
  t:eq(ws.workspace(t, p, b).session_refs, { ws.ref(hub_id, "session-a") })
  t:eq(ws.call(t, p, "move_agent_workspace", { session_id = "session-a", workspace_id = a, hub_id = "hub-elsewhere" })
    .error.code, "remote_hub_unsupported")
  t:eq(ws.call(t, p, "move_agent_workspace", { session_id = "session-a" }).error.code, "validation_failed")
end)

-- Review of d6ee4c9: a malformed hub_id is refused and never means the local hub.
kit.test("a malformed hub_id is refused by every tool and changes nothing", function(t)
  local p = t:load(".")
  local hub_id = ws.hub_id(t, p)
  local a = ws.create(t, p, "Alpha")
  local b = ws.create(t, p, "Beta")
  add(t, p, a, "session-a")
  local before_a = ws.workspace(t, p, a)
  local before_b = ws.workspace(t, p, b)
  for _, bad in ipairs({ false, 42, { hub = "x" }, "   " }) do
    local calls = {
      { "botster_workspaces.add_session", { workspace_id = b, session_id = "session-b", hub_id = bad } },
      { "botster_workspaces.move_session", { destination_workspace_id = b, session_id = "session-a", hub_id = bad } },
      { "botster_workspaces.remove_session", { workspace_id = a, session_id = "session-a", hub_id = bad } },
      { "move_agent_workspace", { session_id = "session-a", workspace_id = b, hub_id = bad } },
      { "rename_workspace", { workspace_id = a, new_name = "Gamma", hub_id = bad } },
      { "list_workspaces", { hub_id = bad } },
    }
    for _, call in ipairs(calls) do
      local r = ws.call(t, p, call[1], call[2])
      t:eq(r.ok, false)
      t:eq(r.error.code, "validation_failed")
      t:eq(r.fields, { "hub_id" })
    end
  end
  t:eq(ws.workspace(t, p, a), before_a)
  t:eq(ws.workspace(t, p, b), before_b)
  t:eq(p:db_get(ws.key(hub_id, "session-a")).workspace_id, a)
  t:eq(p:db_get(ws.key(hub_id, "session-b")), nil)
end)
