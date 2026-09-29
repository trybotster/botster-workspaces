-- Workspace records: registration, create, list, show, rename, delete.
-- Run: botster-plugin-test --plugin . test/workspace_spec.lua
local kit = require("botster.test")
local ws = require("support")

local TOOLS = {
  "botster_workspaces.add_session",
  "botster_workspaces.create",
  "botster_workspaces.delete",
  "botster_workspaces.entity_snapshot",
  "botster_workspaces.list",
  "botster_workspaces.move_session",
  "botster_workspaces.remove_session",
  "botster_workspaces.rename",
  "botster_workspaces.show",
  "botster_workspaces.spawn",
  "list_workspaces",
  "move_agent_workspace",
  "rename_workspace",
}

local function descriptors(p)
  local by_name = {}
  for _, tool in ipairs(p:tools()) do
    by_name[tool.name] = tool
  end
  return by_name
end

local function property_names(tool)
  local schema = tool.input_schema or tool.inputSchema
  if schema == nil then
    local keys = {}
    for key in pairs(tool) do
      keys[#keys + 1] = key
    end
    error("tool descriptor has no input schema; keys: " .. table.concat(keys, ", "))
  end
  local names = {}
  for name in pairs(schema.properties) do
    names[#names + 1] = name
  end
  table.sort(names)
  return names
end

-- R2, R3-R6
kit.test("the package registers its tools with exact argument schemas", function(t)
  local p = t:load(".")
  local tools = descriptors(p)
  for _, name in ipairs(TOOLS) do
    t:ok(tools[name] ~= nil, "registered: " .. name)
  end
  t:eq(property_names(tools["botster_workspaces.show"]), { "id" })
  t:eq(property_names(tools["botster_workspaces.add_session"]), { "hub_id", "session_id", "workspace_id" })
  t:eq(property_names(tools["botster_workspaces.move_session"]),
    { "destination_workspace_id", "hub_id", "session_id" })
  t:eq(property_names(tools["botster_workspaces.spawn"]),
    { "branch", "prompt", "session_type_id", "target_id", "ticket_id", "workspace_id" })
  local spawn_tool = tools["botster_workspaces.spawn"]
  t:eq((spawn_tool.input_schema or spawn_tool.inputSchema).additionalProperties, false)
  t:eq(property_names(tools["move_agent_workspace"]), { "hub_id", "session_id", "workspace_id" })
  t:eq(property_names(tools["rename_workspace"]), { "hub_id", "new_name", "workspace_id" })
end)

-- W1, and the empty-list class: an empty list crosses as a JSON array.
kit.test("a fresh hub lists no workspaces as an empty array", function(t)
  local p = t:load(".")
  local listed = ws.call(t, p, "botster_workspaces.list", {})
  t:eq(listed.ok, true)
  t:eq(#listed.workspaces, 0)
  ws.json_array(t, listed.workspaces, "workspaces")
end)

-- W2
kit.test("create trims the name and returns the five-field record", function(t)
  local p = t:load(".")
  local created = ws.call(t, p, "botster_workspaces.create", { name = "  Release train  " })
  t:eq(created.ok, true)
  local keys = {}
  for key in pairs(created.workspace) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  t:eq(keys, { "created_at", "id", "name", "session_refs", "updated_at" })
  t:eq(created.workspace.name, "Release train")
  t:eq(#created.workspace.session_refs, 0)
  ws.json_array(t, created.workspace.session_refs, "session_refs")
end)

-- W3, W4, L2
kit.test("create refuses unknown, obsolete, and duplicate input", function(t)
  local p = t:load(".")
  t:eq(ws.call(t, p, "botster_workspaces.create", { name = "a", color = "red" }).error.code, "unknown_field")
  for _, field in ipairs({ "purpose", "local_repo_ref", "spawn_target_ref", "default_session_template",
    "default_session_template_id", "default_session_template_refs", "archive_policy", "settings", "status" }) do
    t:eq(ws.call(t, p, "botster_workspaces.create", { name = "a", [field] = "x" }).error.code, "obsolete_field")
  end
  ws.create(t, p, "Alpha")
  t:eq(ws.call(t, p, "botster_workspaces.create", { name = "Alpha" }).error.code, "duplicate_name")
  t:eq(ws.call(t, p, "botster_workspaces.create", { name = "Beta" }).ok, true)
end)

-- W5, W6, W7
kit.test("rename trims, keeps identity, and refuses duplicates and extra fields", function(t)
  local p = t:load(".")
  local a = ws.create(t, p, "Alpha")
  ws.create(t, p, "Beta")
  local before = ws.workspace(t, p, a)
  local renamed = ws.call(t, p, "botster_workspaces.rename", { id = a, name = "  Gamma " })
  t:eq(renamed.ok, true)
  t:eq(renamed.workspace.name, "Gamma")
  t:eq(renamed.workspace.id, a)
  t:eq(renamed.workspace.created_at, before.created_at)
  t:eq(ws.call(t, p, "botster_workspaces.rename", { id = a, name = "Beta" }).error.code, "duplicate_name")
  t:eq(ws.call(t, p, "botster_workspaces.rename", { id = a, name = "x", purpose = "y" }).error.code, "unknown_field")
end)

-- W11, W10 (scale kept small: the behaviour does not depend on the count)
kit.test("delete removes only the grouping and frees the name", function(t)
  local p = t:load(".")
  local a = ws.create(t, p, "Alpha")
  local hub_id = ws.hub_id(t, p)
  for index = 1, 3 do
    t:eq(ws.call(t, p, "botster_workspaces.add_session", { workspace_id = a, session_id = "session-" .. index }).ok, true)
  end
  local deleted = ws.call(t, p, "botster_workspaces.delete", { id = a })
  t:eq(deleted.ok, true)
  t:eq(#deleted.workspace.session_refs, 3)
  for index = 1, 3 do
    t:eq(p:db_get(ws.key(hub_id, "session-" .. index)), nil)
  end
  t:eq(ws.call(t, p, "botster_workspaces.show", { id = a }).error.code, "workspace_not_found")
  t:eq(ws.call(t, p, "botster_workspaces.create", { name = "Alpha" }).ok, true)
end)

-- W12
kit.test("entity_snapshot returns read-model rows", function(t)
  local p = t:load(".")
  ws.create(t, p, "Alpha")
  ws.create(t, p, "Beta")
  local snapshot = ws.call(t, p, "botster_workspaces.entity_snapshot", {})
  t:eq(snapshot.entity_family, "botster-workspaces.workspace")
  t:eq(#snapshot.rows, 2)
  t:match(snapshot.rows, {
    { name = "Alpha", session_count = 0, entity_family = "botster-workspaces.workspace" },
    { name = "Beta", session_count = 0, entity_family = "botster-workspaces.workspace" },
  })
end)

-- W9: Hub session ids are opaque strings.
kit.test("an opaque non-UUID session id is kept", function(t)
  local p = t:load(".")
  local a = ws.create(t, p, "Alpha")
  local hub_id = ws.hub_id(t, p)
  t:eq(ws.call(t, p, "botster_workspaces.add_session", { workspace_id = a, session_id = "session-type-shell" }).ok, true)
  t:eq(ws.workspace(t, p, a).session_refs, { ws.ref(hub_id, "session-type-shell") })
end)

-- Agent tools: list_workspaces and rename_workspace.
kit.test("the agent tools list and rename with agent argument names", function(t)
  local p = t:load(".")
  local a = ws.create(t, p, "Alpha")
  local hub_id = ws.hub_id(t, p)
  local listed = ws.call(t, p, "list_workspaces", { hub_id = hub_id })
  t:eq(listed.ok, true)
  t:eq(listed.hub_id, hub_id)
  t:eq(#listed.workspaces, 1)
  t:eq(ws.call(t, p, "rename_workspace", { workspace_id = a, new_name = "Gamma" }).workspace.name, "Gamma")
  t:eq(ws.call(t, p, "rename_workspace", { workspace_id = a, new_name = "x", id = a }).error.code, "unknown_field")
  t:eq(ws.call(t, p, "list_workspaces", { hub_id = "hub-elsewhere" }).error.code, "remote_hub_unsupported")
  t:eq(ws.call(t, p, "rename_workspace", { workspace_id = a, new_name = "y", hub_id = "hub-elsewhere" }).error.code,
    "remote_hub_unsupported")
end)
