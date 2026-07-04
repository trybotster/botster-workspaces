local database = {}
local registrations = {}

local function copy(value)
  if type(value) ~= "table" then
    return value
  end
  local out = {}
  for key, child in pairs(value) do
    out[key] = copy(child)
  end
  return out
end

botster = {
  capabilities = {
    plugin_db = {
      get = function(request)
        local record = database[request.key]
        if not record then
          error("record not found")
        end
        return { record = { payload = copy(record.payload) } }
      end,
      set = function(request)
        database[request.key] = {
          schema_version = request.schema_version,
          payload = copy(request.payload),
        }
        return { ok = true }
      end,
    },
    session_templates = {
      resolve = function(request)
        if request.template_id == "template_missing" then
          return {
            ok = false,
            error = {
              code = "template_not_found",
              message = "template not found",
            },
          }
        end
        return {
          ok = true,
          template_id = request.template_id,
          label = "Hub " .. request.template_id,
        }
      end,
    },
    config = {
      get = function()
        return {
          values = {
            archive_policy = { type = "select", value = "mark_deleted" },
          },
          missing_required = {},
          diagnostics = {},
        }
      end,
    },
  },
  register = function(spec)
    registrations[#registrations + 1] = spec
    return spec
  end,
}

local function assert_eq(actual, expected, message)
  if actual ~= expected then
    error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
  end
end

local function assert_true(value, message)
  if not value then
    error(message or "assertion failed")
  end
end

local function tool(spec, name)
  for _, candidate in ipairs(spec.tools or {}) do
    if candidate.name == name then
      return candidate.call
    end
  end
  error("missing tool " .. name)
end

local function handler(spec, id)
  for _, candidate in ipairs(spec.handlers or {}) do
    if candidate.id == id then
      return candidate.call
    end
  end
  error("missing handler " .. id)
end

local function repo_ref(id, label)
  return {
    id = id,
    display_name = label,
    repo_capability_ref = "repo_capability_" .. id,
    default_branch = "main",
    relative_worktree_hint = "worktrees/" .. id,
  }
end

local function spawn_target_ref(id, label)
  return {
    target_id = id,
    label = label,
    kind = "agent",
    capability_ref = "spawn_target_" .. id,
  }
end

local invalid_surface_types = {
  bind_list = true,
  row = true,
  section = true,
  binding = true,
}

local function assert_valid_surface_node(node)
  assert_true(type(node.type) == "string", "surface node has type")
  assert_true(not invalid_surface_types[node.type], "surface node type is supported: " .. tostring(node.type))
  if node.type == "list_item" then
    assert_true(node.slots and node.slots.title, "list_item has required title slot")
  end
  for _, child in ipairs(node.children or {}) do
    assert_valid_surface_node(child)
  end
  for _, slot_children in pairs(node.slots or {}) do
    for _, child in ipairs(slot_children or {}) do
      assert_valid_surface_node(child)
    end
  end
end

local function collect_text(node, out)
  if node.type == "text" and node.props and node.props.text then
    out[#out + 1] = node.props.text
  end
  if node.type == "empty_state" and node.props and node.props.title then
    out[#out + 1] = node.props.title
  end
  for _, child in ipairs(node.children or {}) do
    collect_text(child, out)
  end
  for _, slot_children in pairs(node.slots or {}) do
    for _, child in ipairs(slot_children or {}) do
      collect_text(child, out)
    end
  end
end

local function json_escape(value)
  local escaped = value:gsub("\\", "\\\\")
  escaped = escaped:gsub('"', '\\"')
  escaped = escaped:gsub("\n", "\\n")
  escaped = escaped:gsub("\r", "\\r")
  escaped = escaped:gsub("\t", "\\t")
  return '"' .. escaped .. '"'
end

local function is_array(value)
  local count = 0
  for key in pairs(value) do
    if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
      return false
    end
    if key > count then
      count = key
    end
  end
  for index = 1, count do
    if value[index] == nil then
      return false
    end
  end
  return true
end

local function json_encode(value)
  local value_type = type(value)
  if value_type == "nil" then
    return "null"
  end
  if value_type == "boolean" then
    return value and "true" or "false"
  end
  if value_type == "number" then
    return tostring(value)
  end
  if value_type == "string" then
    return json_escape(value)
  end
  if value_type ~= "table" then
    error("cannot encode JSON value of type " .. value_type)
  end

  local parts = {}
  if is_array(value) then
    for index, child in ipairs(value) do
      parts[index] = json_encode(child)
    end
    return "[" .. table.concat(parts, ",") .. "]"
  end

  for key, child in pairs(value) do
    parts[#parts + 1] = json_escape(tostring(key)) .. ":" .. json_encode(child)
  end
  table.sort(parts)
  return "{" .. table.concat(parts, ",") .. "}"
end

local function dump_surfaces(path, surfaces)
  if not path or path == "" then
    return
  end
  local file = assert(io.open(path, "w"))
  file:write(json_encode(surfaces))
  file:write("\n")
  file:close()
end

local spec = dofile("plugin.lua")

assert_eq(#registrations, 1, "plugin registers once")
assert_true(tool(spec, "botster_workspaces.create"), "create tool is registered")
assert_true(tool(spec, "botster_workspaces.list"), "list tool is registered")
assert_true(tool(spec, "botster_workspaces.show"), "show tool is registered")
assert_true(tool(spec, "botster_workspaces.update"), "update tool is registered")
assert_true(tool(spec, "botster_workspaces.delete"), "delete tool is registered")
assert_true(tool(spec, "botster_workspaces.refresh_template_diagnostics"), "template diagnostics tool is registered")
assert_true(tool(spec, "botster_workspaces.spawn_default_session"), "template spawn tool is registered")
assert_true(tool(spec, "botster_workspaces.entity_snapshot"), "entity snapshot tool is registered")

local create = tool(spec, "botster_workspaces.create")
local list = tool(spec, "botster_workspaces.list")
local show = tool(spec, "botster_workspaces.show")
local update = tool(spec, "botster_workspaces.update")
local delete = tool(spec, "botster_workspaces.delete")
local refresh_templates = tool(spec, "botster_workspaces.refresh_template_diagnostics")
local spawn_default_session = tool(spec, "botster_workspaces.spawn_default_session")
local snapshot = tool(spec, "botster_workspaces.entity_snapshot")

local missing = create({})
assert_eq(missing.ok, false, "create rejects missing required fields")
assert_eq(missing.error.code, "validation_failed", "missing fields returns validation_failed")

local created = create({
  name = "Product refactor",
  purpose = "Coordinate product refactor agents",
  local_repo_ref = repo_ref("repo_main", "Main application repo"),
  spawn_target_ref = spawn_target_ref("target_codex_local", "Codex local"),
  default_session_template_refs = {
    {
      template_id = "template_codex_implement",
      label = "Codex implementer",
      role = "implement",
      group = "primary",
      selected = true,
    },
    {
      template_id = "template_missing",
      label = "Missing review template",
      role = "review",
      group = "accessory",
      accessory = true,
    },
  },
})
assert_eq(created.ok, true, "create succeeds")
assert_eq(created.workspace.status, "active", "create marks active")
assert_eq(created.workspace.session_group.workspace_id, created.workspace.id, "session group is workspace scoped")
assert_eq(#created.workspace.session_group.session_refs, 0, "create starts with no session refs")
assert_eq(created.workspace.settings.archive_policy, "mark_deleted", "package config seeds workspace archive policy")
assert_eq(created.entity.entity_family, "botster-workspaces.workspace", "entity family is correct")
assert_eq(created.entity.repo_label, "Main application repo", "entity exposes repo label")
assert_eq(created.entity.spawn_target_label, "Codex local", "entity exposes spawn target label")
assert_eq(created.entity.session_count, 0, "entity counts sessions")
assert_eq(created.entity.default_session_template_count, 2, "entity counts default templates")
assert_eq(created.workspace.default_session_template_id, "template_codex_implement", "create preserves primary template compatibility field")
assert_eq(#created.workspace.default_session_template_refs, 2, "create stores multiple template refs")
assert_eq(created.workspace.created_at, "plugin-clock-000001", "create assigns plugin-owned timestamp")

local refreshed = refresh_templates({ id = created.workspace.id })
assert_eq(refreshed.ok, true, "template diagnostics refresh succeeds")
assert_eq(refreshed.workspace.default_session_template_refs[1].validation_status, "valid", "valid template is marked")
assert_eq(refreshed.workspace.default_session_template_refs[1].label, "Hub template_codex_implement", "hub label is cached")
assert_eq(refreshed.workspace.default_session_template_refs[2].validation_status, "invalid", "invalid template is marked")
assert_eq(refreshed.workspace.default_session_template_refs[2].template_id, "template_missing", "invalid template reference is retained")

local spawn_request = spawn_default_session({
  id = created.workspace.id,
  session_id = "session-workspace-template-1",
  prompt = "Implement from workspace context",
  ticket_id = "ticket-123",
  branch_name = "main",
})
assert_eq(spawn_request.ok, true, "spawn default session request succeeds")
assert_eq(spawn_request.hub_api, "spawn_session_template", "spawn uses hub template API name")
assert_eq(spawn_request.daemon_request.type, "spawn_session_template", "spawn request is daemon template spawn")
assert_eq(spawn_request.daemon_request.template_id, "template_codex_implement", "spawn uses selected template")
assert_eq(spawn_request.daemon_request.request.context.workspace_id, created.workspace.id, "spawn passes workspace context")
assert_eq(spawn_request.daemon_request.target_id, nil, "spawn request does not echo hub-owned target id")
assert_eq(spawn_request.daemon_request.request.cwd, nil, "spawn request does not inject unproven cwd override")
assert_eq(spawn_request.daemon_request.request.env, nil, "spawn request does not inject unproven env override")
assert_eq(spawn_request.daemon_request.request.context.metadata, nil, "spawn request does not inject unproven metadata context")

local duplicate = create({
  name = "Product refactor",
  purpose = "Duplicate active name",
  local_repo_ref = repo_ref("repo_duplicate", "Duplicate repo"),
  spawn_target_ref = spawn_target_ref("target_codex_local", "Codex local"),
})
assert_eq(duplicate.ok, false, "duplicate active name rejects")
assert_eq(duplicate.error.code, "duplicate_active_name", "duplicate error code")

local second = create({
  name = "Alpha support",
  purpose = "Support agents",
  local_repo_ref = repo_ref("repo_support", "Support repo"),
  spawn_target_ref = spawn_target_ref("target_claude_local", "Claude local"),
})
assert_eq(second.ok, true, "second workspace creates")

local listed = list({})
assert_eq(listed.ok, true, "list succeeds")
assert_eq(#listed.workspaces, 2, "list returns active rows")
assert_eq(listed.workspaces[1].name, "Alpha support", "list sorts by name")
assert_eq(listed.workspaces[2].name, "Product refactor", "list sorts by name second")

local full = show({ id = created.workspace.id })
assert_eq(full.ok, true, "show succeeds")
assert_eq(full.workspace.local_repo_ref.relative_worktree_hint, "worktrees/repo_main", "show returns repo metadata")

local not_found = show({ id = "missing_workspace" })
assert_eq(not_found.ok, false, "show rejects unknown id")
assert_eq(not_found.error.code, "workspace_not_found", "show not-found code")

local rejected = update({
  id = created.workspace.id,
  patch = {
    process_state = "running",
  },
})
assert_eq(rejected.ok, false, "update rejects hub-owned fields")
assert_eq(rejected.error.code, "hub_owned_field_rejected", "hub-owned error code")

local raw_spawn_rejected = update({
  id = created.workspace.id,
  patch = {
    raw_spawn_request = {
      command = "codex",
    },
  },
})
assert_eq(raw_spawn_rejected.ok, false, "update rejects raw spawn request fields")
assert_eq(raw_spawn_rejected.error.code, "hub_owned_field_rejected", "raw spawn error code")

local updated = update({
  id = created.workspace.id,
  patch = {
    purpose = "Coordinate implementation agents",
    session_group = {
      session_refs = {
        {
          session_uuid = "example-session-101",
          role = "implement",
          spawned_from_template_id = "template_codex_implement",
          status = "running",
        },
        {
          session_uuid = "example-session-102",
          role = "review",
          spawned_from_template_id = "template_codex_review",
          status = "queued",
        },
      },
    },
  },
})
assert_eq(updated.ok, true, "update succeeds")
assert_eq(updated.entity.session_count, 2, "update refreshes session count")
assert_eq(#updated.workspace.session_group.session_refs, 2, "update stores session refs")
assert_eq(updated.workspace.updated_at, "plugin-clock-000005", "update assigns plugin-owned timestamp")

local selected_by_update = update({
  id = created.workspace.id,
  patch = {
    default_session_template_refs = {
      {
        template_id = "template_codex_implement",
        label = "Codex implementer",
        role = "implement",
        group = "primary",
        selected = false,
      },
      {
        template_id = "template_codex_review",
        label = "Codex reviewer",
        role = "review",
        group = "accessory",
        accessory = true,
        selected = true,
      },
    },
  },
})
assert_eq(selected_by_update.ok, true, "update selects default template")
assert_eq(selected_by_update.workspace.default_session_template_refs[2].selected, true, "second template is selected")

local selected_spawn_request = spawn_default_session({
  id = created.workspace.id,
  session_id = "session-workspace-template-selected",
})
assert_eq(selected_spawn_request.ok, true, "spawn after selection succeeds")
assert_eq(selected_spawn_request.daemon_request.template_id, "template_codex_review", "spawn uses tool-selected template")

local singular = create({
  name = "Legacy singular",
  purpose = "Load old singular template records",
  local_repo_ref = repo_ref("repo_legacy", "Legacy repo"),
  spawn_target_ref = spawn_target_ref("target_codex_local", "Codex local"),
  default_session_template_id = "template_legacy",
})
assert_eq(singular.ok, true, "singular template create succeeds")
assert_eq(#singular.workspace.default_session_template_refs, 1, "singular template normalizes to one ref")
assert_eq(singular.workspace.default_session_template_refs[1].template_id, "template_legacy", "singular template id preserved")

local entity_rows = snapshot({})
assert_eq(entity_rows.ok, true, "entity snapshot succeeds")
assert_eq(entity_rows.entity_family, "botster-workspaces.workspace", "snapshot family")
assert_eq(#entity_rows.rows, 3, "snapshot includes active rows")

local deleted = delete({ id = created.workspace.id })
assert_eq(deleted.ok, true, "delete succeeds")
assert_eq(deleted.workspace.status, "deleted", "delete marks deleted")
assert_eq(#deleted.workspace.session_group.session_refs, 2, "delete preserves session references")

local active_after_delete = list({})
assert_eq(#active_after_delete.workspaces, 2, "deleted rows are excluded from default list")

local recreated = create({
  name = "Product refactor",
  purpose = "Reuse name after deletion",
  local_repo_ref = repo_ref("repo_recreated", "Recreated repo"),
  spawn_target_ref = spawn_target_ref("target_codex_local", "Codex local"),
})
assert_eq(recreated.ok, true, "deleted names do not block new active workspace")

botster.capabilities.config.get = function()
  return {
    values = {
      archive_policy = { type = "select", value = "archive" },
    },
    missing_required = {},
    diagnostics = {},
  }
end
local archived_default = create({
  name = "Archive default",
  purpose = "Configured package default",
  local_repo_ref = repo_ref("repo_archive_default", "Archive default repo"),
  spawn_target_ref = spawn_target_ref("target_codex_local", "Codex local"),
})
assert_eq(archived_default.workspace.settings.archive_policy, "archive", "configured archive policy seeds new workspaces")
botster.capabilities.config.get = function()
  return {
    values = {
      archive_policy = { type = "select", value = "mark_deleted" },
    },
    missing_required = {},
    diagnostics = {},
  }
end

local restart_spec = dofile("plugin.lua")
local restart_list = tool(restart_spec, "botster_workspaces.list")({})
assert_eq(#restart_list.workspaces, 4, "state persists through plugin reload")

local app_surface = handler(spec, "workspaces_surface")({})
assert_eq(app_surface.id, "botster-workspaces-app", "app surface renders")
assert_valid_surface_node(app_surface)
assert_eq(app_surface.children[2].type, "list", "app surface uses valid list node")
local app_text = {}
collect_text(app_surface, app_text)
assert_true(table.concat(app_text, "\n"):find("Product refactor", 1, true), "app surface renders workspace state")
assert_true(table.concat(app_text, "\n"):find("botster%-workspaces%.workspace") ~= nil, "app surface names read-model family")

local settings_surface = handler(spec, "workspaces_settings_surface")({})
assert_eq(settings_surface.id, "botster-workspaces-settings", "settings surface renders")
assert_valid_surface_node(settings_surface)
assert_eq(settings_surface.children[2].type, "list", "settings surface uses valid list node")
local settings_text = {}
collect_text(settings_surface, settings_text)
assert_true(table.concat(settings_text, "\n"):find("Product refactor", 1, true), "settings surface renders workspace state")

dump_surfaces(os.getenv("BOTSTER_WORKSPACES_SURFACE_JSON"), {
  app_surface,
  settings_surface,
})

local invalid_repo = create({
  name = "Unsafe repo",
  purpose = "Reject host path",
  local_repo_ref = {
    id = "repo_unsafe",
    display_name = "Unsafe",
    repo_capability_ref = "repo_capability_unsafe",
    default_branch = "main",
    relative_worktree_hint = "/tmp/unsafe",
  },
  spawn_target_ref = spawn_target_ref("target_codex_local", "Codex local"),
})
assert_eq(invalid_repo.ok, false, "raw absolute repo paths are rejected")

print("test/plugin_runtime_test.lua: ok")
