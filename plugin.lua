local PLUGIN = "botster-workspaces"
local STATE_KEY = "workspace_state"
local ENTITY_FAMILY = "botster-workspaces.workspace"

local HUB_OWNED_FIELDS = {
  process_state = true,
  pty_state = true,
  terminal_scrollback = true,
  package_admission = true,
  spawn_target_record = true,
  session_manifest = true,
}

local function empty_schema()
  return {
    type = "object",
    properties = {},
    additionalProperties = false,
  }
end

local function default_state()
  return {
    next_workspace = 0,
    next_timestamp = 0,
    workspaces = {},
    default_session_templates = {},
  }
end

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

local function trim(value)
  if type(value) ~= "string" then
    return nil
  end
  return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function load_state()
  local capabilities = botster and botster.capabilities or {}
  local plugin_db = capabilities.plugin_db
  if not plugin_db or type(plugin_db.get) ~= "function" then
    return default_state()
  end

  local ok, result = pcall(plugin_db.get, { key = STATE_KEY })
  if not ok or not result or not result.record or type(result.record.payload) ~= "table" then
    return default_state()
  end

  local state = result.record.payload
  state.next_workspace = tonumber(state.next_workspace or 0) or 0
  state.next_timestamp = tonumber(state.next_timestamp or 0) or 0
  state.workspaces = state.workspaces or {}
  state.default_session_templates = state.default_session_templates or {}
  return state
end

local function persist_state(state)
  local capabilities = botster and botster.capabilities or {}
  local plugin_db = capabilities.plugin_db
  if not plugin_db or type(plugin_db.set) ~= "function" then
    return true
  end

  return pcall(plugin_db.set, {
    key = STATE_KEY,
    schema_version = 1,
    payload = state,
  })
end

local function persist_failed(error)
  return {
    ok = false,
    error = {
      code = "persist_failed",
      message = "failed to persist workspace state: " .. tostring(error),
    },
  }
end

local function save_or_error(state)
  local ok, result = persist_state(state)
  if not ok then
    return persist_failed(result)
  end
  return nil
end

local function error_result(code, message, fields)
  local result = {
    ok = false,
    error = {
      code = code,
      message = message,
    },
  }
  if fields then
    result.fields = fields
  end
  return result
end

local function validate_repo_ref(ref)
  if type(ref) ~= "table" then
    return false
  end
  if type(ref.relative_worktree_hint) == "string" and ref.relative_worktree_hint:match("^/") then
    return false
  end
  return trim(ref.id) ~= nil
    and trim(ref.display_name) ~= nil
    and trim(ref.repo_capability_ref) ~= nil
    and trim(ref.default_branch) ~= nil
    and trim(ref.relative_worktree_hint) ~= nil
end

local function validate_spawn_target_ref(ref)
  return type(ref) == "table"
    and trim(ref.target_id) ~= nil
    and trim(ref.label) ~= nil
    and trim(ref.kind) ~= nil
    and trim(ref.capability_ref) ~= nil
end

local function validate_session_refs(refs)
  if refs == nil then
    return true
  end
  if type(refs) ~= "table" then
    return false
  end
  for _, ref in ipairs(refs) do
    if type(ref) ~= "table"
      or trim(ref.session_uuid) == nil
      or trim(ref.role) == nil
      or trim(ref.status) == nil then
      return false
    end
  end
  return true
end

local function workspace_by_id(state, workspace_id)
  for _, workspace in ipairs(state.workspaces) do
    if workspace.id == workspace_id then
      return workspace
    end
  end
  return nil
end

local function active_name_taken(state, name, except_id)
  for _, workspace in ipairs(state.workspaces) do
    if workspace.status == "active"
      and workspace.name == name
      and workspace.id ~= except_id then
      return true
    end
  end
  return false
end

local function next_workspace_id(state, name)
  state.next_workspace = (tonumber(state.next_workspace or 0) or 0) + 1
  local slug = (name or "workspace"):lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
  if slug == "" then
    slug = "workspace"
  end
  return "ws_" .. slug .. "_" .. tostring(state.next_workspace)
end

local function next_timestamp(state)
  state.next_timestamp = (tonumber(state.next_timestamp or 0) or 0) + 1
  return string.format("plugin-clock-%06d", state.next_timestamp)
end

local function default_settings(workspace_id, repo_ref, spawn_target_ref, template_id)
  return {
    workspace_id = workspace_id,
    default_repo_ref_id = repo_ref.id,
    default_spawn_target_id = spawn_target_ref.target_id,
    default_session_template_id = template_id,
    archive_policy = "mark_deleted",
  }
end

local function read_model(workspace)
  local session_refs = {}
  if workspace.session_group and type(workspace.session_group.session_refs) == "table" then
    session_refs = workspace.session_group.session_refs
  end

  return {
    id = workspace.id,
    name = workspace.name,
    purpose = workspace.purpose,
    status = workspace.status,
    repo_label = workspace.local_repo_ref and workspace.local_repo_ref.display_name or nil,
    spawn_target_label = workspace.spawn_target_ref and workspace.spawn_target_ref.label or nil,
    session_count = #session_refs,
    entity_family = ENTITY_FAMILY,
  }
end

local function active_read_models(state)
  local rows = {}
  for _, workspace in ipairs(state.workspaces) do
    if workspace.status == "active" then
      rows[#rows + 1] = read_model(workspace)
    end
  end
  table.sort(rows, function(left, right)
    return tostring(left.name or "") < tostring(right.name or "")
  end)
  return rows
end

local function create_workspace(arguments)
  local name = trim(arguments.name)
  local purpose = trim(arguments.purpose)
  local repo_ref = copy(arguments.local_repo_ref)
  local spawn_target_ref = copy(arguments.spawn_target_ref)
  local missing = {}

  if not name then
    missing[#missing + 1] = "name"
  end
  if not purpose then
    missing[#missing + 1] = "purpose"
  end
  if not validate_repo_ref(repo_ref) then
    missing[#missing + 1] = "local_repo_ref"
  end
  if not validate_spawn_target_ref(spawn_target_ref) then
    missing[#missing + 1] = "spawn_target_ref"
  end
  if #missing > 0 then
    return error_result("validation_failed", "workspace create is missing required fields", missing)
  end

  local state = load_state()
  if active_name_taken(state, name, nil) then
    return error_result("duplicate_active_name", "an active workspace already uses that name")
  end

  local workspace_id = next_workspace_id(state, name)
  local timestamp = next_timestamp(state)
  local template_id = arguments.default_session_template_id
  local workspace = {
    id = workspace_id,
    name = name,
    purpose = purpose,
    status = "active",
    local_repo_ref = repo_ref,
    spawn_target_ref = spawn_target_ref,
    session_group = {
      workspace_id = workspace_id,
      session_refs = {},
    },
    default_session_template_id = template_id,
    settings = default_settings(workspace_id, repo_ref, spawn_target_ref, template_id),
    created_at = timestamp,
    updated_at = timestamp,
  }

  state.workspaces[#state.workspaces + 1] = workspace
  local error = save_or_error(state)
  if error then
    return error
  end
  return { ok = true, workspace = copy(workspace), entity = read_model(workspace) }
end

local function list_workspaces(arguments)
  local include_archived = arguments and arguments.include_archived == true
  local include_deleted = arguments and arguments.include_deleted == true
  local state = load_state()
  local rows = {}
  for _, workspace in ipairs(state.workspaces) do
    if workspace.status == "active"
      or (include_archived and workspace.status == "archived")
      or (include_deleted and workspace.status == "deleted") then
      rows[#rows + 1] = read_model(workspace)
    end
  end
  table.sort(rows, function(left, right)
    return tostring(left.name or "") < tostring(right.name or "")
  end)
  return { ok = true, workspaces = rows, entity_family = ENTITY_FAMILY }
end

local function show_workspace(arguments)
  local workspace_id = trim(arguments.id or arguments.workspace_id)
  if not workspace_id then
    return error_result("missing_argument", "missing required argument: id")
  end
  local state = load_state()
  local workspace = workspace_by_id(state, workspace_id)
  if not workspace then
    return error_result("workspace_not_found", "workspace not found: " .. workspace_id)
  end
  return { ok = true, workspace = copy(workspace), entity = read_model(workspace) }
end

local function reject_hub_fields(patch)
  for key in pairs(patch or {}) do
    if HUB_OWNED_FIELDS[key] then
      return key
    end
  end
  return nil
end

local function update_workspace(arguments)
  local workspace_id = trim(arguments.id or arguments.workspace_id)
  if not workspace_id then
    return error_result("missing_argument", "missing required argument: id")
  end

  local patch = arguments.patch or arguments
  local rejected = reject_hub_fields(patch)
  if rejected then
    return error_result("hub_owned_field_rejected", "workspace updates cannot modify hub-owned field: " .. rejected, { rejected })
  end

  local state = load_state()
  local workspace = workspace_by_id(state, workspace_id)
  if not workspace then
    return error_result("workspace_not_found", "workspace not found: " .. workspace_id)
  end

  local next_name = patch.name ~= nil and trim(patch.name) or workspace.name
  if not next_name then
    return error_result("validation_failed", "workspace name cannot be blank", { "name" })
  end
  if active_name_taken(state, next_name, workspace.id) then
    return error_result("duplicate_active_name", "an active workspace already uses that name")
  end

  if patch.local_repo_ref ~= nil and not validate_repo_ref(patch.local_repo_ref) then
    return error_result("validation_failed", "local_repo_ref is invalid", { "local_repo_ref" })
  end
  if patch.spawn_target_ref ~= nil and not validate_spawn_target_ref(patch.spawn_target_ref) then
    return error_result("validation_failed", "spawn_target_ref is invalid", { "spawn_target_ref" })
  end
  if patch.session_group ~= nil and not validate_session_refs(patch.session_group.session_refs) then
    return error_result("validation_failed", "session_group.session_refs is invalid", { "session_group.session_refs" })
  end

  workspace.name = next_name
  workspace.purpose = patch.purpose ~= nil and trim(patch.purpose) or workspace.purpose
  workspace.local_repo_ref = patch.local_repo_ref ~= nil and copy(patch.local_repo_ref) or workspace.local_repo_ref
  workspace.spawn_target_ref = patch.spawn_target_ref ~= nil and copy(patch.spawn_target_ref) or workspace.spawn_target_ref
  workspace.default_session_template_id = patch.default_session_template_id ~= nil and patch.default_session_template_id or workspace.default_session_template_id
  if patch.settings ~= nil then
    workspace.settings = copy(patch.settings)
    workspace.settings.workspace_id = workspace.id
  end
  if patch.session_group ~= nil and patch.session_group.session_refs ~= nil then
    workspace.session_group = workspace.session_group or { workspace_id = workspace.id, session_refs = {} }
    workspace.session_group.workspace_id = workspace.id
    workspace.session_group.session_refs = copy(patch.session_group.session_refs)
  end
  workspace.updated_at = next_timestamp(state)

  local error = save_or_error(state)
  if error then
    return error
  end
  return { ok = true, workspace = copy(workspace), entity = read_model(workspace) }
end

local function delete_workspace(arguments)
  local workspace_id = trim(arguments.id or arguments.workspace_id)
  if not workspace_id then
    return error_result("missing_argument", "missing required argument: id")
  end
  local state = load_state()
  local workspace = workspace_by_id(state, workspace_id)
  if not workspace then
    return error_result("workspace_not_found", "workspace not found: " .. workspace_id)
  end
  workspace.status = "deleted"
  workspace.updated_at = next_timestamp(state)
  local error = save_or_error(state)
  if error then
    return error
  end
  return {
    ok = true,
    workspace = copy(workspace),
    deleted = true,
    does_not_delete = {
      "hub_sessions",
      "package_records",
      "spawn_targets",
      "repository_content",
      "host_filesystem_content",
    },
  }
end

local function entity_snapshot()
  local state = load_state()
  local rows = active_read_models(state)
  return { ok = true, entity_family = ENTITY_FAMILY, rows = rows }
end

local function text_node(id, text, tone)
  local props = { text = text }
  if tone then
    props.tone = tone
  end
  return {
    type = "text",
    id = id,
    props = props,
  }
end

local function empty_state(id, title, description)
  return {
    type = "empty_state",
    id = id,
    props = {
      title = title,
      description = description,
    },
  }
end

local function list_item(row)
  return {
    type = "list_item",
    id = "workspace-row-" .. tostring(row.id),
    props = {
      value = row.id,
    },
    slots = {
      title = {
        text_node("workspace-row-" .. tostring(row.id) .. "-title", row.name),
      },
      subtitle = {
        text_node("workspace-row-" .. tostring(row.id) .. "-purpose", row.purpose),
        text_node("workspace-row-" .. tostring(row.id) .. "-repo", row.repo_label .. " / " .. row.spawn_target_label, "muted"),
      },
      meta = {
        text_node("workspace-row-" .. tostring(row.id) .. "-status", row.status),
        text_node("workspace-row-" .. tostring(row.id) .. "-sessions", tostring(row.session_count) .. " sessions"),
      },
    },
  }
end

local function workspace_list_children(rows)
  local children = {}
  if #rows == 0 then
    children[#children + 1] = empty_state(
      "botster-workspaces-empty",
      "No active workspaces",
      "Create a workspace to group repo, spawn target, and session references."
    )
    return children
  end

  for _, row in ipairs(rows) do
    children[#children + 1] = list_item(row)
  end
  return children
end

local function workspaces_surface()
  local rows = active_read_models(load_state())
  return {
    type = "panel",
    id = "botster-workspaces-app",
    props = {
      title = "Workspaces",
    },
    children = {
      text_node("botster-workspaces-read-model", "Read model: " .. ENTITY_FAMILY, "muted"),
      {
        type = "list",
        id = "botster-workspaces-list",
        props = {
          aria_label = "Workspaces",
        },
        children = workspace_list_children(rows),
      },
    },
  }
end

local function settings_surface()
  local rows = active_read_models(load_state())
  return {
    type = "panel",
    id = "botster-workspaces-settings",
    props = {
      title = "Workspaces Settings",
    },
    children = {
      {
        type = "text",
        id = "botster-workspaces-settings-summary",
        props = {
          text = "No required configuration fields",
        },
      },
      {
        type = "list",
        id = "botster-workspaces-settings-list",
        props = {
          aria_label = "Workspace settings",
        },
        children = workspace_list_children(rows),
      },
    },
  }
end

return botster.register({
  handlers = {
    {
      id = "workspaces_surface",
      kind = "surface_route",
      descriptor_id = "workspaces",
      descriptor = {
        title = "Workspaces",
        surface_id = "workspaces",
      },
      call = workspaces_surface,
    },
    {
      id = "workspaces_settings_surface",
      kind = "surface_route",
      descriptor_id = "workspaces-settings",
      descriptor = {
        title = "Workspaces Settings",
        surface_id = "workspaces-settings",
      },
      call = settings_surface,
    },
  },
  tools = {
    {
      name = "botster_workspaces.create",
      description = "Create a plugin-owned workspace record.",
      input_schema = {
        type = "object",
        properties = {
          name = { type = "string" },
          purpose = { type = "string" },
          local_repo_ref = { type = "object" },
          spawn_target_ref = { type = "object" },
          default_session_template_id = { type = "string" },
        },
        required = { "name", "purpose", "local_repo_ref", "spawn_target_ref" },
        additionalProperties = false,
      },
      handler = "create_workspace",
      call = create_workspace,
    },
    {
      name = "botster_workspaces.list",
      description = "List workspace read models.",
      input_schema = {
        type = "object",
        properties = {
          include_archived = { type = "boolean" },
          include_deleted = { type = "boolean" },
        },
        additionalProperties = false,
      },
      handler = "list_workspaces",
      call = list_workspaces,
    },
    {
      name = "botster_workspaces.show",
      description = "Show a full plugin-owned workspace record.",
      input_schema = {
        type = "object",
        properties = {
          id = { type = "string" },
          workspace_id = { type = "string" },
        },
        additionalProperties = false,
      },
      handler = "show_workspace",
      call = show_workspace,
    },
    {
      name = "botster_workspaces.update",
      description = "Update plugin-owned workspace fields.",
      input_schema = {
        type = "object",
        properties = {
          id = { type = "string" },
          workspace_id = { type = "string" },
          patch = { type = "object" },
        },
        additionalProperties = true,
      },
      handler = "update_workspace",
      call = update_workspace,
    },
    {
      name = "botster_workspaces.delete",
      description = "Mark a workspace deleted without deleting hub-owned resources.",
      input_schema = {
        type = "object",
        properties = {
          id = { type = "string" },
          workspace_id = { type = "string" },
        },
        additionalProperties = false,
      },
      handler = "delete_workspace",
      call = delete_workspace,
    },
    {
      name = "botster_workspaces.entity_snapshot",
      description = "Return the workspace entity read-model snapshot.",
      input_schema = empty_schema(),
      handler = "entity_snapshot",
      call = entity_snapshot,
    },
  },
})
