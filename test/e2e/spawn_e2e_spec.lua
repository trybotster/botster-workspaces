-- botster-workspaces against a REAL daemon process with a session worker.
-- Run with the candidate Hub binaries from the Hub's own gate:
--   BOTSTER_HUB_BIN=... BOTSTER_SESSION_WORKER_BIN=... BOTSTER_CANDIDATE_MANIFEST=... \
--     script/test-e2e
-- The in-process kit has no session worker, so a completed spawn is proven here.
local kit = require("botster.test")
local ws = require("test.support")

local SESSION_TYPE = "botster-workspaces-acceptance-session-type/workspace-acceptance"

kit.test("spawn starts a real session and records it in the workspace", function(t)
  local p = t:load(".")
  t:load("test/fixtures/session-type-package") -- a runnable session type for the target below
  ws.admit_target(t, "workspaces-acceptance", "Workspaces acceptance", "git")
  local id = ws.create(t, p, "Alpha")

  local spawned = ws.call(t, p, "botster_workspaces.spawn", {
    workspace_id = id,
    target_id = "workspaces-acceptance",
    branch = "e2e-spawn",
    session_type_id = SESSION_TYPE,
  })
  t:eq(spawned.ok, true, "the Hub started the session: " .. tostring(spawned.error and spawned.error.message))

  local refs = ws.workspace(t, p, id).session_refs
  t:eq(#refs, 1, "the workspace records the new session")
  t:eq(refs[1].hub_id, ws.hub_id(t, p))
  t:eq(type(refs[1].session_id), "string")
end)

kit.test("spawn into a missing workspace records nothing and starts no session", function(t)
  local p = t:load(".")
  t:load("test/fixtures/session-type-package")
  ws.admit_target(t, "workspaces-acceptance", "Workspaces acceptance", "git")
  local refused = ws.call(t, p, "botster_workspaces.spawn", {
    workspace_id = "ws_missing_1",
    target_id = "workspaces-acceptance",
    branch = "e2e-missing",
    session_type_id = SESSION_TYPE,
  })
  t:eq(refused.ok, false)
  local listed = t:request({ type = "list_sessions" })
  t:eq(listed.ok, true)
  t:eq(#listed.response.sessions, 0, "no session was started")
end)

-- The superseded manifest key contributes no effective session type. The
-- contrast is the first spec: the current key spawns a real session.
kit.test("a package with the superseded session_templates key offers no spawnable session type", function(t)
  local p = t:load(".")
  t:load("test/fixtures/legacy-session-template-manifest") -- cold-cut negative control
  ws.admit_target(t, "workspaces-acceptance", "Workspaces acceptance", "git")
  local id = ws.create(t, p, "Alpha")
  local refused = ws.call(t, p, "botster_workspaces.spawn", {
    workspace_id = id,
    target_id = "workspaces-acceptance",
    branch = "e2e-legacy",
    session_type_id = "botster-workspaces-legacy-manifest-negative/legacy-acceptance",
  })
  t:eq(refused.ok, false)
  t:eq(#ws.workspace(t, p, id).session_refs, 0)
  t:eq(#t:request({ type = "list_sessions" }).response.sessions, 0, "no session was started")
end)
