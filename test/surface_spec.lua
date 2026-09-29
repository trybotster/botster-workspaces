-- The workspaces app surface and its ui_actions, through the Hub's production
-- surface requests (plugin_surface_render, plugin_surface_action).
-- Run: botster-plugin-test --plugin . test/surface_spec.lua
local kit = require("botster.test")
local ws = require("support")

local function render(t)
  local response = t:request({
    type = "plugin_surface_render",
    package_name = "botster-workspaces",
    surface_id = "workspaces",
    payload = {},
  })
  t:eq(response.ok, true)
  return response.response.plugin_surface.ui_tree_snapshot.body
end

local function act(t, action_id, fields)
  local request = { request_id = "spec", surface_id = "workspaces", action_id = action_id, kind = "submit" }
  for key, value in pairs(fields or {}) do
    request[key] = value
  end
  local response = t:request({
    type = "plugin_surface_action",
    package_name = "botster-workspaces",
    request = request,
  })
  t:eq(response.ok, true)
  return response.response.plugin_action_result
end

-- Depth-first search over children, slots, and $kind wrappers.
local function find(node, predicate)
  if type(node) ~= "table" then
    return nil
  end
  if predicate(node) then
    return node
  end
  for _, child in pairs(node) do
    local found = find(child, predicate)
    if found then
      return found
    end
  end
  return nil
end

local function by_id(tree, id)
  return find(tree, function(node)
    return node.id == id
  end)
end

-- U1, U2
kit.test("the empty surface is one stack with an empty state and a New workspace action", function(t)
  t:load(".")
  local tree = render(t)
  t:eq(tree.id, "botster-workspaces-app")
  t:eq(tree.type, "stack")
  t:ok(by_id(tree, "botster-workspaces-empty") ~= nil, "empty state present")
  t:match(by_id(tree, "botster-workspaces-empty-create"), {
    type = "button",
    props = { label = "New workspace", action = { id = "botster_workspaces.open", payload = { dialog = "create" } } },
  })
end)

-- U3
kit.test("the New workspace action opens the create dialog", function(t)
  t:load(".")
  local result = act(t, "botster_workspaces.open", { payload = { dialog = "create" } })
  t:eq(result.state, "accepted")
  t:eq(result.presentation, { { kind = "set", key = "workspace-dialog", value = "create" } })
end)

-- U4, U26
kit.test("create rejects an empty name on its field and accepts a valid one", function(t)
  local p = t:load(".")
  local rejected = act(t, "botster_workspaces.create", { values = { ["botster-workspaces-create-name"] = "" } })
  t:eq(rejected.state, "rejected")
  t:ok(rejected.field_errors["botster-workspaces-create-name"] ~= nil, "field error on the name input")
  local accepted = act(t, "botster_workspaces.create", { values = { ["botster-workspaces-create-name"] = "Alpha" } })
  t:eq(accepted.state, "accepted")
  t:eq(accepted.presentation, { { kind = "clear", key = "workspace-dialog" } })
  t:ok(accepted.replacement ~= nil, "the surface is replaced")
  t:eq(#ws.call(t, p, "botster_workspaces.list", {}).workspaces, 1)
end)

-- U12: grouped sessions bind to this hub's /session family by session id.
kit.test("a grouped session binds its rows to /session by session id", function(t)
  local p = t:load(".")
  local a = ws.create(t, p, "Alpha")
  ws.call(t, p, "botster_workspaces.add_session", { workspace_id = a, session_id = "session-a" })
  local tree = render(t)
  local binding = find(tree, function(node)
    return node["$kind"] == "bind_list" and type(node.where) == "table" and node.where.session_uuid == "session-a"
  end)
  t:ok(binding ~= nil, "a bind_list filters /session by the grouped session id")
  t:eq(binding.source, "/session")
end)

-- U11: the Available sessions picker excludes grouped sessions by the membership row's session_id.
kit.test("the add picker excludes memberships by session_id", function(t)
  local p = t:load(".")
  ws.create(t, p, "Alpha")
  local source = find(render(t), function(node)
    return node["$kind"] == "entity_options"
  end)
  t:ok(source ~= nil, "entity_options source present")
  t:eq(source.source, "/session")
  t:eq(source.value_field, "session_uuid")
  t:eq(source.exclude, { source = "/botster-workspaces.membership", value_field = "session_id" })
end)

-- U16, and the spawn-target regression through the UI.
kit.test("the spawn dialog offers admitted spawn targets", function(t)
  local p = t:load(".")
  ws.admit_target(t, "plain", "Plain", "directory")
  ws.create(t, p, "Alpha")
  local option = find(render(t), function(node)
    return node.value == "plain"
  end)
  t:ok(option ~= nil, "the admitted target is an option")
end)

-- U27
kit.test("the remove action removes the session from the workspace", function(t)
  local p = t:load(".")
  local a = ws.create(t, p, "Alpha")
  ws.call(t, p, "botster_workspaces.add_session", { workspace_id = a, session_id = "session-a" })
  local result = act(t, "botster_workspaces.remove_session", { payload = { workspace_id = a, session_id = "session-a" } })
  t:eq(result.state, "accepted")
  t:eq(#ws.workspace(t, p, a).session_refs, 0)
end)

-- U28-U31: the advanced historical id wins over the picker; both empty is rejected on the picker.
kit.test("add session precedence: advanced id over picker; neither is rejected", function(t)
  local p = t:load(".")
  local hub_id = ws.hub_id(t, p)
  local a = ws.create(t, p, "Alpha")
  local picker = "botster-workspaces-add-session-id"
  local advanced = "botster-workspaces-add-session-id-advanced"
  local workspace_field = "botster-workspaces-add-workspace-id"
  t:eq(act(t, "botster_workspaces.add_session",
    { values = { [workspace_field] = a, [picker] = "session-picked" } }).state, "accepted")
  t:eq(act(t, "botster_workspaces.add_session",
    { values = { [workspace_field] = a, [picker] = "session-other", [advanced] = "session-historical" } }).state,
    "accepted")
  t:eq(ws.workspace(t, p, a).session_refs,
    { ws.ref(hub_id, "session-picked"), ws.ref(hub_id, "session-historical") })
  local rejected = act(t, "botster_workspaces.add_session", { values = { [workspace_field] = a } })
  t:eq(rejected.state, "rejected")
  t:ok(rejected.field_errors[picker] ~= nil, "field error on the picker")
end)

-- U32
kit.test("adding a session owned by another workspace reports the conflict", function(t)
  local p = t:load(".")
  local a = ws.create(t, p, "Alpha")
  local b = ws.create(t, p, "Beta")
  ws.call(t, p, "botster_workspaces.add_session", { workspace_id = a, session_id = "session-a" })
  local result = act(t, "botster_workspaces.add_session", { values = {
    ["botster-workspaces-add-workspace-id"] = b,
    ["botster-workspaces-add-session-id"] = "session-a",
  } })
  t:eq(result.state, "error")
  t:ok(#result.form_errors > 0, "a form error explains the conflict")
end)
