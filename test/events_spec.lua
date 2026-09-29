-- Event input: botster-orchestrator.session_spawned and the Hub session family.
-- Run: botster-plugin-test --plugin . test/events_spec.lua
local kit = require("botster.test")
local ws = require("support")

-- The producer is the REAL botster-orchestrator manifest at the commit pinned
-- in test/orchestrator.pin (script/test checks it out and passes its path in
-- BOTSTER_ORCHESTRATOR_PACKAGE). Only the plugin code is a stand-in, because
-- the in-process kit cannot spawn a session: the stand-in emits the event that
-- the orchestrator emits after a spawn. The event name, audience, and payload
-- schema come from the orchestrator's own manifest, so a contract change there
-- breaks these specs instead of drifting unseen.
local ORCHESTRATOR = os.getenv("BOTSTER_ORCHESTRATOR_PACKAGE")
assert(ORCHESTRATOR and ORCHESTRATOR ~= "", "set BOTSTER_ORCHESTRATOR_PACKAGE (script/test does)")

local function real_producer_package()
  local directory = io.popen("mktemp -d"):read("*l")
  assert(os.execute(string.format(
    "cp '%s/botster-package.json' '%s/' && cp 'test/fixtures/orchestrator-producer/plugin.lua' '%s/'",
    ORCHESTRATOR, directory, directory)))
  return directory
end

local PRODUCER = real_producer_package()

local function spawned(t, producer, payload)
  local emitted = producer:call_tool("producer.emit", payload)
  t:eq(emitted.ok, true)
  t:eq(emitted.result.ok, true)
end

-- W1 subscription: the claim completes inside the producer's step.
kit.test("session_spawned claims membership across packages in one step", function(t)
  local producer = t:load(PRODUCER)
  local p = t:load(".")
  local a = ws.create(t, p, "Alpha")
  local hub_id = ws.hub_id(t, p)
  spawned(t, producer, { hub_id = hub_id, session_id = "session-a", workspace_id = a })
  t:eq(ws.workspace(t, p, a).session_refs, { ws.ref(hub_id, "session-a") })
  t:eq(p:db_get(ws.key(hub_id, "session-a")).workspace_id, a)
end)

-- P10: the subscription is admitted before its producer loads and binds when
-- botster-orchestrator loads, whatever the load order.
kit.test("session_spawned claims membership when botster-workspaces loads before botster-orchestrator", function(t)
  local p = t:load(".")
  local producer = t:load(PRODUCER)
  local a = ws.create(t, p, "Alpha")
  local hub_id = ws.hub_id(t, p)
  spawned(t, producer, { hub_id = hub_id, session_id = "session-a", workspace_id = a })
  t:eq(ws.workspace(t, p, a).session_refs, { ws.ref(hub_id, "session-a") })
end)

kit.test("session_spawned for an unknown workspace leaves the session ungrouped and logs", function(t)
  local producer = t:load(PRODUCER)
  local p = t:load(".")
  local hub_id = ws.hub_id(t, p)
  spawned(t, producer, { hub_id = hub_id, session_id = "session-a", workspace_id = "ws_missing_9" })
  t:eq(p:db_get(ws.key(hub_id, "session-a")), nil)
  t:match(p:logs(), { { level = "warn", message = "spawned session was not added to its workspace" } })
end)

kit.test("session_spawned from another hub is not claimed", function(t)
  local producer = t:load(PRODUCER)
  local p = t:load(".")
  local a = ws.create(t, p, "Alpha")
  spawned(t, producer, { hub_id = "hub-elsewhere", session_id = "session-a", workspace_id = a })
  t:eq(#ws.workspace(t, p, a).session_refs, 0)
  t:match(p:logs(), { { level = "warn", message = "spawned session was not added to its workspace" } })
end)

kit.test("botster-workspaces loads without botster-orchestrator", function(t)
  local p = t:load(".")
  t:eq(ws.call(t, p, "botster_workspaces.list", {}).ok, true)
end)

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
