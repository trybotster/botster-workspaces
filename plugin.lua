local PLUGIN = "botster-workspaces"
local STATE_KEY = "workspace_state"
local ENTITY_FAMILY = "botster-workspaces.workspace"
local SURFACE_ID = "workspaces"

local WORKSPACE_KEYS = {
  id = true,
  name = true,
  session_refs = true,
  created_at = true,
  updated_at = true,
}

local STATE_KEYS = {
  next_workspace = true,
  next_timestamp = true,
  workspaces = true,
}

local OBSOLETE_FIELDS = {
  purpose = true,
  repository = true,
  repository_id = true,
  local_repo_ref = true,
  spawn_target_ref = true,
  default_session_template = true,
  default_session_template_id = true,
  default_session_template_refs = true,
  branch = true,
  worktree = true,
  settings = true,
  status = true,
  archive_policy = true,
  session_group = true,
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
  }
end

local function copy(value)
  if type(value) ~= "table" then
    return value
  end
  local result = {}
  for key, child in pairs(value) do
    result[key] = copy(child)
  end
  return result
end

local function trim(value)
  if type(value) ~= "string" then
    return nil
  end
  local trimmed = value:gsub("^%s+", ""):gsub("%s+$", "")
  if trimmed == "" then
    return nil
  end
  return trimmed
end

local function error_result(code, message, fields, extra)
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
  for key, value in pairs(extra or {}) do
    result[key] = value
  end
  return result
end

local function unknown_field(arguments, allowed)
  for key in pairs(arguments or {}) do
    if not allowed[key] then
      return key
    end
  end
  return nil
end

local function exact_keys(value, allowed)
  if type(value) ~= "table" then
    return false
  end
  for key in pairs(value) do
    if not allowed[key] then
      return false
    end
  end
  for key in pairs(allowed) do
    if value[key] == nil then
      return false
    end
  end
  return true
end

local function valid_session_id(value)
  local id = trim(value)
  return id ~= nil
    and id:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
end

local function validate_state(state)
  if not exact_keys(state, STATE_KEYS)
    or type(state.next_workspace) ~= "number"
    or type(state.next_timestamp) ~= "number"
    or type(state.workspaces) ~= "table" then
    return error_result(
      "legacy_workspace_schema",
      "workspace data uses an unsupported pre-release schema; start with a fresh Hub data directory"
    )
  end

  local names = {}
  local memberships = {}
  for _, workspace in ipairs(state.workspaces) do
    if not exact_keys(workspace, WORKSPACE_KEYS)
      or trim(workspace.id) ~= workspace.id
      or trim(workspace.name) ~= workspace.name
      or type(workspace.session_refs) ~= "table"
      or trim(workspace.created_at) ~= workspace.created_at
      or trim(workspace.updated_at) ~= workspace.updated_at then
      return error_result(
        "legacy_workspace_schema",
        "workspace data uses an unsupported pre-release schema; start with a fresh Hub data directory"
      )
    end
    if names[workspace.name] then
      return error_result("legacy_workspace_schema", "workspace data contains duplicate names")
    end
    names[workspace.name] = true
    for _, session_id in ipairs(workspace.session_refs) do
      if not valid_session_id(session_id) or memberships[session_id] then
        return error_result("legacy_workspace_schema", "workspace data contains invalid or duplicate session references")
      end
      memberships[session_id] = workspace.id
    end
  end
  return nil
end

local function load_state()
  local plugin_db = botster and botster.capabilities
    and botster.capabilities.plugin_db
  if not plugin_db or type(plugin_db.get) ~= "function" then
    return default_state(), nil
  end

  local ok, result = pcall(plugin_db.get, { key = STATE_KEY })
  if not ok then
    return nil, error_result("workspace_state_read_failed", "failed to read workspace state")
  end
  if not result or not result.record then
    return default_state(), nil
  end
  local state = result.record.payload
  local invalid = validate_state(state)
  if invalid then
    return nil, invalid
  end
  return copy(state), nil
end

local function persist_state(state)
  local plugin_db = botster and botster.capabilities
    and botster.capabilities.plugin_db
  if not plugin_db or type(plugin_db.set) ~= "function" then
    return nil
  end

  local ok, result = pcall(plugin_db.set, {
    key = STATE_KEY,
    schema_version = 1,
    payload = state,
  })
  if not ok or (type(result) == "table" and result.ok == false) then
    return error_result("persist_failed", "failed to persist workspace state")
  end
  return nil
end

local function workspace_by_id(state, workspace_id)
  for index, workspace in ipairs(state.workspaces) do
    if workspace.id == workspace_id then
      return workspace, index
    end
  end
  return nil, nil
end

local function workspace_by_session(state, session_id)
  for _, workspace in ipairs(state.workspaces) do
    for _, candidate in ipairs(workspace.session_refs) do
      if candidate == session_id then
        return workspace
      end
    end
  end
  return nil
end

local function name_taken(state, name, except_id)
  for _, workspace in ipairs(state.workspaces) do
    if workspace.name == name and workspace.id ~= except_id then
      return true
    end
  end
  return false
end

local function next_workspace_id(state, name)
  state.next_workspace = state.next_workspace + 1
  local slug = name:lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
  if slug == "" then
    slug = "workspace"
  end
  return "ws_" .. slug .. "_" .. tostring(state.next_workspace)
end

local function next_timestamp(state)
  state.next_timestamp = state.next_timestamp + 1
  return string.format("plugin-clock-%06d", state.next_timestamp)
end

local function read_model(workspace)
  return {
    id = workspace.id,
    name = workspace.name,
    session_refs = copy(workspace.session_refs),
    session_count = #workspace.session_refs,
    created_at = workspace.created_at,
    updated_at = workspace.updated_at,
    entity_family = ENTITY_FAMILY,
  }
end

local function sorted_rows(state)
  local rows = {}
  for _, workspace in ipairs(state.workspaces) do
    rows[#rows + 1] = read_model(workspace)
  end
  table.sort(rows, function(left, right)
    return left.name < right.name
  end)
  return rows
end

local function create_workspace(arguments)
  local rejected = unknown_field(arguments, { name = true })
  if rejected then
    local code = OBSOLETE_FIELDS[rejected] and "obsolete_field" or "unknown_field"
    return error_result(code, "workspace create does not accept field: " .. rejected, { rejected })
  end
  local name = trim(arguments.name)
  if not name then
    return error_result("validation_failed", "workspace name is required", { "name" })
  end

  local state, load_error = load_state()
  if load_error then
    return load_error
  end
  if name_taken(state, name) then
    return error_result("duplicate_name", "a workspace already uses that name", { "name" })
  end

  local timestamp = next_timestamp(state)
  local workspace = {
    id = next_workspace_id(state, name),
    name = name,
    session_refs = {},
    created_at = timestamp,
    updated_at = timestamp,
  }
  state.workspaces[#state.workspaces + 1] = workspace
  local persist_error = persist_state(state)
  if persist_error then
    return persist_error
  end
  return { ok = true, workspace = copy(workspace), entity = read_model(workspace) }
end

local function list_workspaces(arguments)
  local rejected = unknown_field(arguments or {}, {})
  if rejected then
    return error_result("unknown_field", "workspace list does not accept field: " .. rejected, { rejected })
  end
  local state, load_error = load_state()
  if load_error then
    return load_error
  end
  return { ok = true, workspaces = sorted_rows(state), entity_family = ENTITY_FAMILY }
end

local function show_workspace(arguments)
  local rejected = unknown_field(arguments, { id = true })
  if rejected then
    return error_result("unknown_field", "workspace show does not accept field: " .. rejected, { rejected })
  end
  local workspace_id = trim(arguments.id)
  if not workspace_id then
    return error_result("validation_failed", "workspace id is required", { "id" })
  end
  local state, load_error = load_state()
  if load_error then
    return load_error
  end
  local workspace = workspace_by_id(state, workspace_id)
  if not workspace then
    return error_result("workspace_not_found", "workspace not found: " .. workspace_id)
  end
  return { ok = true, workspace = copy(workspace), entity = read_model(workspace) }
end

local function rename_workspace(arguments)
  local rejected = unknown_field(arguments, { id = true, name = true })
  if rejected then
    return error_result("unknown_field", "workspace rename does not accept field: " .. rejected, { rejected })
  end
  local workspace_id = trim(arguments.id)
  local name = trim(arguments.name)
  local missing = {}
  if not workspace_id then
    missing[#missing + 1] = "id"
  end
  if not name then
    missing[#missing + 1] = "name"
  end
  if #missing > 0 then
    return error_result("validation_failed", "workspace rename requires id and name", missing)
  end

  local state, load_error = load_state()
  if load_error then
    return load_error
  end
  local workspace = workspace_by_id(state, workspace_id)
  if not workspace then
    return error_result("workspace_not_found", "workspace not found: " .. workspace_id)
  end
  if name_taken(state, name, workspace.id) then
    return error_result("duplicate_name", "a workspace already uses that name", { "name" })
  end
  workspace.name = name
  workspace.updated_at = next_timestamp(state)
  local persist_error = persist_state(state)
  if persist_error then
    return persist_error
  end
  return { ok = true, workspace = copy(workspace), entity = read_model(workspace) }
end

local function delete_workspace(arguments)
  local rejected = unknown_field(arguments, { id = true })
  if rejected then
    return error_result("unknown_field", "workspace delete does not accept field: " .. rejected, { rejected })
  end
  local workspace_id = trim(arguments.id)
  if not workspace_id then
    return error_result("validation_failed", "workspace id is required", { "id" })
  end

  local state, load_error = load_state()
  if load_error then
    return load_error
  end
  local workspace, index = workspace_by_id(state, workspace_id)
  if not workspace then
    return error_result("workspace_not_found", "workspace not found: " .. workspace_id)
  end
  table.remove(state.workspaces, index)
  local persist_error = persist_state(state)
  if persist_error then
    return persist_error
  end
  return {
    ok = true,
    deleted = true,
    workspace = copy(workspace),
    does_not_delete = {
      "hub_sessions",
      "worktrees",
      "branches",
      "repositories",
    },
  }
end

local function add_session(arguments)
  local rejected = unknown_field(arguments, { workspace_id = true, session_id = true })
  if rejected then
    return error_result("unknown_field", "add session does not accept field: " .. rejected, { rejected })
  end
  local workspace_id = trim(arguments.workspace_id)
  local session_id = trim(arguments.session_id)
  local missing = {}
  if not workspace_id then
    missing[#missing + 1] = "workspace_id"
  end
  if not valid_session_id(session_id) then
    missing[#missing + 1] = "session_id"
  end
  if #missing > 0 then
    return error_result("validation_failed", "add session requires a workspace and canonical session UUID", missing)
  end

  local state, load_error = load_state()
  if load_error then
    return load_error
  end
  local workspace = workspace_by_id(state, workspace_id)
  if not workspace then
    return error_result("workspace_not_found", "workspace not found: " .. workspace_id)
  end
  local owner = workspace_by_session(state, session_id)
  if owner then
    return error_result("session_already_owned", "session already belongs to workspace: " .. owner.id, nil, {
      owner_workspace_id = owner.id,
    })
  end
  workspace.session_refs[#workspace.session_refs + 1] = session_id
  workspace.updated_at = next_timestamp(state)
  local persist_error = persist_state(state)
  if persist_error then
    return persist_error
  end
  return { ok = true, workspace = copy(workspace), entity = read_model(workspace) }
end

local function move_session(arguments)
  local rejected = unknown_field(arguments, {
    destination_workspace_id = true,
    session_id = true,
  })
  if rejected then
    return error_result("unknown_field", "move session does not accept field: " .. rejected, { rejected })
  end
  local destination_id = trim(arguments.destination_workspace_id)
  local session_id = trim(arguments.session_id)
  local missing = {}
  if not destination_id then
    missing[#missing + 1] = "destination_workspace_id"
  end
  if not valid_session_id(session_id) then
    missing[#missing + 1] = "session_id"
  end
  if #missing > 0 then
    return error_result("validation_failed", "move session requires a destination and canonical session UUID", missing)
  end

  local state, load_error = load_state()
  if load_error then
    return load_error
  end
  local destination = workspace_by_id(state, destination_id)
  if not destination then
    return error_result("workspace_not_found", "workspace not found: " .. destination_id)
  end
  local source = workspace_by_session(state, session_id)
  if not source then
    return error_result("session_not_grouped", "session does not belong to a workspace")
  end
  if source.id == destination.id then
    return error_result("session_already_owned", "session already belongs to workspace: " .. destination.id, nil, {
      owner_workspace_id = destination.id,
    })
  end

  for index, candidate in ipairs(source.session_refs) do
    if candidate == session_id then
      table.remove(source.session_refs, index)
      break
    end
  end
  destination.session_refs[#destination.session_refs + 1] = session_id
  local timestamp = next_timestamp(state)
  source.updated_at = timestamp
  destination.updated_at = timestamp
  local persist_error = persist_state(state)
  if persist_error then
    return persist_error
  end
  return {
    ok = true,
    source = copy(source),
    destination = copy(destination),
    entities = { read_model(source), read_model(destination) },
  }
end

local function remove_session(arguments)
  local rejected = unknown_field(arguments, { workspace_id = true, session_id = true })
  if rejected then
    return error_result("unknown_field", "remove session does not accept field: " .. rejected, { rejected })
  end
  local workspace_id = trim(arguments.workspace_id)
  local session_id = trim(arguments.session_id)
  if not workspace_id or not valid_session_id(session_id) then
    return error_result(
      "validation_failed",
      "remove session requires a workspace and canonical session UUID",
      { "workspace_id", "session_id" }
    )
  end

  local state, load_error = load_state()
  if load_error then
    return load_error
  end
  local workspace = workspace_by_id(state, workspace_id)
  if not workspace then
    return error_result("workspace_not_found", "workspace not found: " .. workspace_id)
  end
  local removed = false
  for index, candidate in ipairs(workspace.session_refs) do
    if candidate == session_id then
      table.remove(workspace.session_refs, index)
      removed = true
      break
    end
  end
  if not removed then
    return error_result("session_not_in_workspace", "session does not belong to workspace: " .. workspace_id)
  end
  workspace.updated_at = next_timestamp(state)
  local persist_error = persist_state(state)
  if persist_error then
    return persist_error
  end
  return { ok = true, workspace = copy(workspace), entity = read_model(workspace) }
end

local function spawn_targets()
  local capability = botster and botster.capabilities
    and botster.capabilities.spawn_targets
  if not capability or type(capability.list) ~= "function" then
    return nil, error_result("spawn_targets_unavailable", "Hub spawn-target projection is unavailable")
  end
  local ok, result = pcall(capability.list)
  if not ok or type(result) ~= "table" then
    return nil, error_result("spawn_targets_failed", "failed to list Hub spawn points")
  end
  local targets = {}
  for _, target in ipairs(result) do
    if type(target) == "table"
      and target.enabled ~= false
      and target.kind == "git"
      and trim(target.target_id or target.id) then
      targets[#targets + 1] = {
        id = trim(target.target_id or target.id),
        label = trim(target.label or target.name) or trim(target.target_id or target.id),
      }
    end
  end
  return targets, nil
end

local function session_types_for_target(target_id)
  local capability = botster and botster.capabilities
    and botster.capabilities.session_types
  if not capability or type(capability.list) ~= "function" then
    return nil, error_result("session_types_unavailable", "Hub session-type projection is unavailable")
  end
  local ok, result = pcall(capability.list, { target_id = target_id })
  if not ok or type(result) ~= "table" then
    return nil, error_result("session_types_failed", "failed to list effective Hub session types")
  end
  local session_types = {}
  for _, session_type in ipairs(result) do
    if type(session_type) == "table" and trim(session_type.session_type_id) then
      session_types[#session_types + 1] = {
        id = trim(session_type.session_type_id),
        label = trim(session_type.label) or trim(session_type.session_type_id),
      }
    end
  end
  return session_types, nil
end

local function spawn_session(arguments)
  local rejected = unknown_field(arguments, {
    workspace_id = true,
    target_id = true,
    branch = true,
    session_type_id = true,
    prompt = true,
    ticket_id = true,
  })
  if rejected then
    return error_result("unknown_field", "spawn session does not accept field: " .. rejected, { rejected })
  end

  local workspace_id = trim(arguments.workspace_id)
  local target_id = trim(arguments.target_id)
  local branch = trim(arguments.branch)
  local session_type_id = trim(arguments.session_type_id)
  local missing = {}
  if not workspace_id then
    missing[#missing + 1] = "workspace_id"
  end
  if not target_id then
    missing[#missing + 1] = "target_id"
  end
  if not branch then
    missing[#missing + 1] = "branch"
  end
  if not session_type_id then
    missing[#missing + 1] = "session_type_id"
  end
  if #missing > 0 then
    return error_result("validation_failed", "spawn requires workspace, spawn point, branch, and session type", missing)
  end

  local state, load_error = load_state()
  if load_error then
    return load_error
  end
  local workspace = workspace_by_id(state, workspace_id)
  if not workspace then
    return error_result("workspace_not_found", "workspace not found: " .. workspace_id)
  end

  local capability = botster and botster.capabilities
    and botster.capabilities.session_types
  if not capability or type(capability.ensure_worktree_and_spawn) ~= "function" then
    return error_result("managed_git_spawn_unavailable", "Hub atomic managed-Git spawn is unavailable")
  end
  local ok, result = pcall(capability.ensure_worktree_and_spawn, {
    target_id = target_id,
    branch = branch,
    session_type_id = session_type_id,
    context = {
      workspace_id = workspace_id,
      prompt = trim(arguments.prompt),
      ticket_id = trim(arguments.ticket_id),
    },
  })
  if not ok then
    return error_result("hub_spawn_failed", "Hub atomic managed-Git spawn failed")
  end
  if type(result) ~= "table" or result.ok ~= true or type(result.result) ~= "table" then
    local hub_error = type(result) == "table" and result.error or nil
    return error_result(
      hub_error and hub_error.kind or "hub_spawn_rejected",
      hub_error and hub_error.message or "Hub rejected the atomic managed-Git spawn"
    )
  end
  local session_id = trim(result.result.session_id)
  if not valid_session_id(session_id) then
    return error_result("invalid_hub_session_id", "Hub spawn did not return a canonical session UUID")
  end
  if workspace_by_session(state, session_id) then
    return error_result("duplicate_hub_session_id", "Hub returned a session UUID that is already grouped")
  end

  workspace.session_refs[#workspace.session_refs + 1] = session_id
  workspace.updated_at = next_timestamp(state)
  local persist_error = persist_state(state)
  if persist_error then
    return error_result("persist_failed", "Hub spawned the session but workspace membership could not be persisted", nil, {
      spawned_session_id = session_id,
      membership_recorded = false,
    })
  end
  return {
    ok = true,
    session_id = session_id,
    workspace = copy(workspace),
    entity = read_model(workspace),
    hub_result = copy(result.result),
  }
end

local function entity_snapshot()
  local state, load_error = load_state()
  if load_error then
    return load_error
  end
  return { ok = true, entity_family = ENTITY_FAMILY, rows = sorted_rows(state) }
end

local function action_result(arguments, state, extra)
  local result = {
    request_id = arguments.request_id or arguments.action_id or "workspace-action",
    surface_id = arguments.surface_id or SURFACE_ID,
    action_id = arguments.action_id or "workspace-action",
    node_id = arguments.node_id,
    state = state,
  }
  for key, value in pairs(extra or {}) do
    result[key] = value
  end
  return result
end

local function action_error(arguments, result, field_ids)
  local field_errors = {}
  for _, field in ipairs(result.fields or {}) do
    local id = (field_ids or {})[field] or field
    field_errors[id] = { result.error.message }
  end
  return action_result(arguments, result.error.code == "validation_failed" and "rejected" or "error", {
    field_errors = field_errors,
    form_errors = { result.error.message },
    error = result.error.message,
  })
end

local function form_value(arguments, name, id)
  local values = type(arguments.values) == "table" and arguments.values or {}
  local payload = type(arguments.payload) == "table" and arguments.payload or {}
  local value = values[id] or values[name] or arguments[name] or payload[name]
  if type(value) == "table" and value.value ~= nil then
    value = value.value
  end
  return value
end

local function presentation_set(key, value)
  return { kind = "set", key = key, value = value }
end

local function presentation_clear(key)
  return { kind = "clear", key = key }
end

local function open_presentation(arguments)
  local payload = type(arguments.payload) == "table" and arguments.payload or {}
  local operations = {}
  if payload.selected_workspace then
    operations[#operations + 1] = presentation_set("selected-workspace", payload.selected_workspace)
  end
  if payload.dialog then
    operations[#operations + 1] = presentation_set("workspace-dialog", payload.dialog)
  end
  return action_result(arguments, "accepted", {
    presentation = #operations > 0 and operations or nil,
  })
end

local workspaces_surface

local function mutation_action(arguments, operation, values, close_dialog, field_ids)
  local result = operation(values)
  if not result.ok then
    return action_error(arguments, result, field_ids)
  end
  local presentation = {}
  if close_dialog then
    presentation[#presentation + 1] = presentation_clear("workspace-dialog")
  end
  return action_result(arguments, "accepted", {
    normalized_values = values,
    presentation = #presentation > 0 and presentation or nil,
    replacement = workspaces_surface(),
    payload = result,
  })
end

local function create_workspace_action(arguments)
  return mutation_action(arguments, create_workspace, {
    name = form_value(arguments, "name", "botster-workspaces-create-name"),
  }, true, {
    name = "botster-workspaces-create-name",
  })
end

local function rename_workspace_action(arguments)
  return mutation_action(arguments, rename_workspace, {
    id = form_value(arguments, "workspace_id", "botster-workspaces-rename-workspace-id"),
    name = form_value(arguments, "name", "botster-workspaces-rename-name"),
  }, true, {
    id = "botster-workspaces-rename-workspace-id",
    name = "botster-workspaces-rename-name",
  })
end

local function delete_workspace_action(arguments)
  local result = delete_workspace({
    id = form_value(arguments, "workspace_id", "botster-workspaces-delete-workspace-id"),
  })
  if not result.ok then
    return action_error(arguments, result, {
      id = "botster-workspaces-delete-workspace-id",
    })
  end
  return action_result(arguments, "accepted", {
    presentation = {
      presentation_clear("workspace-dialog"),
      presentation_clear("selected-workspace"),
    },
    replacement = workspaces_surface(),
    payload = result,
  })
end

local function add_session_action(arguments)
  return mutation_action(arguments, add_session, {
    workspace_id = form_value(arguments, "workspace_id", "botster-workspaces-add-workspace-id"),
    session_id = form_value(arguments, "session_id", "botster-workspaces-add-session-id"),
  }, true, {
    workspace_id = "botster-workspaces-add-workspace-id",
    session_id = "botster-workspaces-add-session-id",
  })
end

local function move_session_action(arguments)
  return mutation_action(arguments, move_session, {
    destination_workspace_id = form_value(
      arguments,
      "destination_workspace_id",
      "botster-workspaces-move-destination-id"
    ),
    session_id = form_value(arguments, "session_id", "botster-workspaces-move-session-id"),
  }, true, {
    destination_workspace_id = "botster-workspaces-move-destination-id",
    session_id = "botster-workspaces-move-session-id",
  })
end

local function remove_session_action(arguments)
  local payload = type(arguments.payload) == "table" and arguments.payload or {}
  return mutation_action(arguments, remove_session, {
    workspace_id = payload.workspace_id,
    session_id = payload.session_id,
  }, false, {
    workspace_id = "botster-workspaces-remove-workspace-id",
    session_id = "botster-workspaces-remove-session-id",
  })
end

local function select_spawn_target_action(arguments)
  local workspace_id = form_value(arguments, "workspace_id", "botster-workspaces-spawn-workspace-id")
  local target_id = form_value(arguments, "target_id", "botster-workspaces-spawn-target")
  if not trim(workspace_id) or not trim(target_id) then
    return action_error(arguments, error_result(
      "validation_failed",
      "choose a spawn point",
      { "target_id" }
    ), {
      target_id = "botster-workspaces-spawn-target",
    })
  end
  return action_result(arguments, "accepted", {
    normalized_values = {
      workspace_id = workspace_id,
      target_id = target_id,
    },
    presentation = {
      presentation_set("workspace-dialog", "spawn:" .. workspace_id .. ":" .. target_id),
    },
    replacement = workspaces_surface(),
  })
end

local function spawn_session_action(arguments)
  return mutation_action(arguments, spawn_session, {
    workspace_id = form_value(arguments, "workspace_id", "botster-workspaces-spawn-workspace-id"),
    target_id = form_value(arguments, "target_id", "botster-workspaces-spawn-target-id"),
    branch = form_value(arguments, "branch", "botster-workspaces-spawn-branch"),
    session_type_id = form_value(arguments, "session_type_id", "botster-workspaces-spawn-template"),
    prompt = form_value(arguments, "prompt", "botster-workspaces-spawn-prompt"),
    ticket_id = form_value(arguments, "ticket_id", "botster-workspaces-spawn-ticket"),
  }, true, {
    workspace_id = "botster-workspaces-spawn-workspace-id",
    target_id = "botster-workspaces-spawn-target-id",
    branch = "botster-workspaces-spawn-branch",
    session_type_id = "botster-workspaces-spawn-template",
  })
end

local function text_node(id, text, tone)
  local props = { text = text }
  if tone then
    props.tone = tone
  end
  return { type = "text", id = id, props = props }
end

local function button_node(id, label, action_id, payload, tone)
  local props = {
    label = label,
    action = {
      id = action_id,
      payload = payload,
    },
  }
  if tone then
    props.tone = tone
  end
  return { type = "button", id = id, props = props }
end

local function text_input(id, name, label, options)
  local props = {
    name = name,
    label = label,
  }
  for key, value in pairs(options or {}) do
    props[key] = value
  end
  return { type = "text_input", id = id, props = props }
end

local function select_input(id, name, label, options)
  local children = {}
  for _, option in ipairs(options) do
    children[#children + 1] = {
      type = "select_option",
      id = id .. "-" .. option.id,
      props = {
        value = option.id,
        label = option.label,
      },
    }
  end
  return {
    type = "select",
    id = id,
    props = {
      name = name,
      label = label,
      required = true,
    },
    slots = {
      options = children,
    },
  }
end

local function form_node(id, action_id, submit_label, children, payload)
  return {
    type = "form",
    id = id,
    props = {
      action = {
        id = action_id,
        payload = payload,
      },
      submit_label = submit_label,
    },
    children = children,
  }
end

local function dialog_if(key, value, id, title, body)
  return {
    ["$kind"] = "presentation_if",
    predicate = {
      kind = "equals",
      key = key,
      value = value,
    },
    node = {
      type = "dialog",
      id = id,
      props = {
        title = title,
        presentation = "auto",
      },
      slots = {
        body = body,
      },
    },
  }
end

local function create_dialog()
  return dialog_if(
    "workspace-dialog",
    "create",
    "botster-workspaces-create-dialog",
    "New workspace",
    {
      form_node(
        "botster-workspaces-create-form",
        "botster_workspaces.create",
        "Create workspace",
        {
          text_input("botster-workspaces-create-name", "name", "Name", {
            placeholder = "Release planning",
            required = true,
          }),
        }
      ),
    }
  )
end

local function workspace_dialogs(workspace, rows, targets, session_types_by_target)
  local move_destinations = {}
  for _, row in ipairs(rows) do
    if row.id ~= workspace.id then
      move_destinations[#move_destinations + 1] = {
        id = row.id,
        label = row.name,
      }
    end
  end
  local move_body
  if #move_destinations == 0 then
    move_body = {
      {
        type = "empty_state",
        id = "botster-workspaces-move-empty-" .. workspace.id,
        props = {
          title = "No destination workspace",
          description = "Create another workspace before moving a session.",
        },
      },
    }
  else
    move_body = {
      form_node(
        "botster-workspaces-move-form-" .. workspace.id,
        "botster_workspaces.move_session",
        "Move session",
        {
          select_input(
            "botster-workspaces-move-destination-id",
            "destination_workspace_id",
            "Destination workspace",
            move_destinations
          ),
          text_input(
            "botster-workspaces-move-session-id",
            "session_id",
            "Session UUID",
            { required = true }
          ),
        },
        { workspace_id = workspace.id }
      ),
    }
  end
  local dialogs = {
    dialog_if(
      "workspace-dialog",
      "rename:" .. workspace.id,
      "botster-workspaces-rename-dialog-" .. workspace.id,
      "Rename workspace",
      {
        form_node(
          "botster-workspaces-rename-form-" .. workspace.id,
          "botster_workspaces.rename",
          "Rename workspace",
          {
            text_input(
              "botster-workspaces-rename-workspace-id",
              "workspace_id",
              "Workspace",
              { value = workspace.id, disabled = true }
            ),
            text_input(
              "botster-workspaces-rename-name",
              "name",
              "Name",
              { value = workspace.name, required = true }
            ),
          },
          { workspace_id = workspace.id }
        ),
      }
    ),
    dialog_if(
      "workspace-dialog",
      "delete:" .. workspace.id,
      "botster-workspaces-delete-dialog-" .. workspace.id,
      "Delete workspace",
      {
        text_node(
          "botster-workspaces-delete-warning-" .. workspace.id,
          "This removes only the grouping. Sessions and managed Git resources remain."
        ),
        form_node(
          "botster-workspaces-delete-form-" .. workspace.id,
          "botster_workspaces.delete",
          "Delete workspace",
          {
            text_input(
              "botster-workspaces-delete-workspace-id",
              "workspace_id",
              "Workspace",
              { value = workspace.id, disabled = true }
            ),
          },
          { workspace_id = workspace.id }
        ),
      }
    ),
    dialog_if(
      "workspace-dialog",
      "add:" .. workspace.id,
      "botster-workspaces-add-dialog-" .. workspace.id,
      "Add existing session",
      {
        form_node(
          "botster-workspaces-add-form-" .. workspace.id,
          "botster_workspaces.add_session",
          "Add session",
          {
            text_input(
              "botster-workspaces-add-workspace-id",
              "workspace_id",
              "Workspace",
              { value = workspace.id, disabled = true }
            ),
            text_input(
              "botster-workspaces-add-session-id",
              "session_id",
              "Session UUID",
              { required = true }
            ),
          },
          { workspace_id = workspace.id }
        ),
      }
    ),
    dialog_if(
      "workspace-dialog",
      "move:" .. workspace.id,
      "botster-workspaces-move-dialog-" .. workspace.id,
      "Move existing session",
      move_body
    ),
  }

  if #targets > 0 then
    dialogs[#dialogs + 1] = dialog_if(
      "workspace-dialog",
      "spawn-target:" .. workspace.id,
      "botster-workspaces-spawn-target-dialog-" .. workspace.id,
      "Spawn session",
      {
        form_node(
          "botster-workspaces-spawn-target-form-" .. workspace.id,
          "botster_workspaces.select_spawn_target",
          "Continue",
          {
            text_input(
              "botster-workspaces-spawn-workspace-id",
              "workspace_id",
              "Workspace",
              { value = workspace.id, disabled = true }
            ),
            select_input(
              "botster-workspaces-spawn-target",
              "target_id",
              "Spawn point",
              targets
            ),
          },
          { workspace_id = workspace.id }
        ),
      }
    )
  end

  for _, target in ipairs(targets) do
    local projection = session_types_by_target[target.id]
    local session_types = projection.session_types
    local spawn_body
    if projection.error then
      spawn_body = {
        {
          type = "empty_state",
          id = "botster-workspaces-spawn-error-" .. workspace.id .. "-" .. target.id,
          props = {
            title = "Session types unavailable",
            description = projection.error.error.message,
          },
        },
      }
    elseif #session_types == 0 then
      spawn_body = {
        {
          type = "empty_state",
          id = "botster-workspaces-spawn-empty-" .. workspace.id .. "-" .. target.id,
          props = {
            title = "No session types",
            description = "No session types are available for this spawn point.",
          },
        },
      }
    else
      spawn_body = {
        form_node(
          "botster-workspaces-spawn-form-" .. workspace.id .. "-" .. target.id,
          "botster_workspaces.spawn",
          "Spawn session",
          {
            text_input(
              "botster-workspaces-spawn-target-id",
              "target_id",
              "Spawn point",
              { value = target.id, disabled = true }
            ),
            text_input(
              "botster-workspaces-spawn-workspace-id",
              "workspace_id",
              "Workspace",
              { value = workspace.id, disabled = true }
            ),
            text_input(
              "botster-workspaces-spawn-branch",
              "branch",
              "Branch / worktree",
              { required = true }
            ),
            select_input(
              "botster-workspaces-spawn-template",
              "session_type_id",
              "Session type",
              session_types
            ),
            text_input("botster-workspaces-spawn-prompt", "prompt", "Prompt"),
            text_input("botster-workspaces-spawn-ticket", "ticket_id", "Ticket"),
          },
          { workspace_id = workspace.id, target_id = target.id }
        ),
      }
    end
    dialogs[#dialogs + 1] = dialog_if(
      "workspace-dialog",
      "spawn:" .. workspace.id .. ":" .. target.id,
      "botster-workspaces-spawn-dialog-" .. workspace.id .. "-" .. target.id,
      "Spawn session",
      spawn_body
    )
  end
  return dialogs
end

local function session_row(workspace, session_id, group, subtitle)
  local slots = {
    title = {
      text_node(
        "botster-workspaces-session-label-" .. group .. "-" .. workspace.id .. "-" .. session_id,
        session_id
      ),
    },
    actions = {
      button_node(
        "botster-workspaces-remove-" .. group .. "-" .. workspace.id .. "-" .. session_id,
        "Remove",
        "botster_workspaces.remove_session",
        { workspace_id = workspace.id, session_id = session_id },
        "danger"
      ),
    },
  }
  if subtitle then
    slots.subtitle = {
      text_node(
        "botster-workspaces-session-subtitle-" .. group .. "-" .. workspace.id .. "-" .. session_id,
        subtitle
      ),
    }
  end
  return {
    type = "list_item",
    id = "botster-workspaces-session-" .. group .. "-" .. workspace.id .. "-" .. session_id,
    slots = slots,
  }
end

local function lifecycle_binding(workspace, session_id, lifecycle_class, subtitle)
  return {
    ["$kind"] = "bind_list",
    source = "/session",
    where = {
      session_uuid = session_id,
      lifecycle_class = lifecycle_class,
    },
    item_template = session_row(workspace, session_id, lifecycle_class, subtitle),
  }
end

local function absence_binding(workspace, session_id)
  return {
    ["$kind"] = "bind_list",
    source = "/session",
    where = {
      session_uuid = session_id,
    },
    item_template = {
      type = "stack",
      id = "botster-workspaces-session-present-" .. workspace.id .. "-" .. session_id,
      props = {
        direction = "vertical",
      },
    },
    empty_template = session_row(workspace, session_id, "absent", "Session unavailable"),
  }
end

local function session_group(workspace, group, title, aria_label, children)
  return {
    type = "section",
    id = "botster-workspaces-sessions-" .. group .. "-" .. workspace.id,
    props = {
      title = title,
    },
    slots = {
      body = {
        {
          type = "list",
          id = "botster-workspaces-session-list-" .. group .. "-" .. workspace.id,
          props = {
            aria_label = aria_label,
          },
          children = children,
        },
      },
    },
  }
end

local function session_groups(workspace)
  if #workspace.session_refs == 0 then
    return {
      {
        type = "empty_state",
        id = "botster-workspaces-sessions-empty-" .. workspace.id,
        props = {
          title = "No sessions",
          description = "Add an existing session or spawn a new one.",
        },
      },
    }
  end

  local current = {}
  local ended = {}
  local unavailable = {}
  for _, session_id in ipairs(workspace.session_refs) do
    current[#current + 1] = lifecycle_binding(workspace, session_id, "current")
    ended[#ended + 1] = lifecycle_binding(workspace, session_id, "ended")
    unavailable[#unavailable + 1] = lifecycle_binding(
      workspace,
      session_id,
      "indeterminate",
      "Lifecycle status is uncertain"
    )
    unavailable[#unavailable + 1] = absence_binding(workspace, session_id)
  end

  return {
    session_group(workspace, "current", "Current", "Current workspace sessions", current),
    session_group(workspace, "ended", "Ended", "Ended workspace sessions", ended),
    session_group(
      workspace,
      "unavailable",
      "Unavailable / uncertain",
      "Unavailable or uncertain workspace sessions",
      unavailable
    ),
  }
end

local function workspace_detail(workspace, rows, targets, session_types_by_target)
  local actions = {
    button_node(
      "botster-workspaces-spawn-" .. workspace.id,
      "Spawn",
      "botster_workspaces.open_spawn",
      { selected_workspace = workspace.id, dialog = "spawn-target:" .. workspace.id }
    ),
    button_node(
      "botster-workspaces-rename-" .. workspace.id,
      "Rename",
      "botster_workspaces.open",
      { selected_workspace = workspace.id, dialog = "rename:" .. workspace.id }
    ),
    button_node(
      "botster-workspaces-delete-" .. workspace.id,
      "Delete",
      "botster_workspaces.open",
      { selected_workspace = workspace.id, dialog = "delete:" .. workspace.id },
      "danger"
    ),
    button_node(
      "botster-workspaces-add-" .. workspace.id,
      "Add existing session",
      "botster_workspaces.open",
      { selected_workspace = workspace.id, dialog = "add:" .. workspace.id }
    ),
    button_node(
      "botster-workspaces-move-" .. workspace.id,
      "Move existing session",
      "botster_workspaces.open",
      { selected_workspace = workspace.id, dialog = "move:" .. workspace.id }
    ),
  }
  local body = {
    {
      type = "section",
      id = "botster-workspaces-detail-" .. workspace.id,
      props = {
        title = workspace.name,
        description = "Referenced session identities are preserved as workspace history.",
      },
      slots = {
        actions = actions,
        body = session_groups(workspace),
      },
    },
  }
  for _, dialog in ipairs(workspace_dialogs(workspace, rows, targets, session_types_by_target)) do
    body[#body + 1] = dialog
  end
  return {
    ["$kind"] = "presentation_if",
    predicate = {
      kind = "equals",
      key = "selected-workspace",
      value = workspace.id,
    },
    node = {
      type = "panel",
      id = "botster-workspaces-selected-" .. workspace.id,
      props = {
        title = workspace.name,
      },
      slots = {
        body = body,
      },
    },
  }
end

local function workspace_index(rows)
  local children = {}
  if #rows == 0 then
    children[#children + 1] = {
      type = "empty_state",
      id = "botster-workspaces-empty",
      props = {
        title = "No workspaces",
        description = "Create a workspace to group related Botster sessions.",
      },
    }
    children[#children + 1] = button_node(
      "botster-workspaces-empty-create",
      "New workspace",
      "botster_workspaces.open",
      { dialog = "create" }
    )
  else
    for _, row in ipairs(rows) do
      children[#children + 1] = {
        type = "list_item",
        id = "botster-workspaces-row-" .. row.id,
        props = {
          value = row.id,
          action = {
            id = "botster_workspaces.open",
            payload = { selected_workspace = row.id },
          },
        },
        slots = {
          title = {
            text_node("botster-workspaces-row-title-" .. row.id, row.name),
          },
          meta = {
            text_node(
              "botster-workspaces-row-count-" .. row.id,
              tostring(row.session_count) .. " sessions",
              "muted"
            ),
          },
        },
      }
    end
  end
  return {
    type = "list",
    id = "botster-workspaces-list",
    props = {
      aria_label = "Workspaces",
    },
    children = children,
  }
end

workspaces_surface = function()
  local state, load_error = load_state()
  if load_error then
    return {
      type = "panel",
      id = "botster-workspaces-schema-error",
      props = { title = "Workspaces unavailable" },
      slots = {
        body = {
          text_node("botster-workspaces-schema-error-message", load_error.error.message, "danger"),
        },
      },
    }
  end
  local rows = sorted_rows(state)
  local targets = spawn_targets() or {}
  local session_types_by_target = {}
  for _, target in ipairs(targets) do
    local session_types, session_type_error = session_types_for_target(target.id)
    session_types_by_target[target.id] = {
      session_types = session_types or {},
      error = session_type_error,
    }
  end
  local body = {
    workspace_index(rows),
    create_dialog(),
  }
  for _, workspace in ipairs(state.workspaces) do
    body[#body + 1] = workspace_detail(workspace, rows, targets, session_types_by_target)
  end
  return {
    type = "panel",
    id = "botster-workspaces-app",
    props = {
      title = "Workspaces",
    },
    slots = {
      toolbar = {
        {
          type = "toolbar",
          id = "botster-workspaces-toolbar",
          props = {
            label = "Workspace actions",
            density = "compact",
          },
          slots = {
            actions = {
              button_node(
                "botster-workspaces-new",
                "New workspace",
                "botster_workspaces.open",
                { dialog = "create" }
              ),
            },
          },
        },
      },
      body = body,
    },
  }
end

return botster.register({
  handlers = {
    {
      id = "workspaces_surface",
      kind = "surface_route",
      descriptor_id = SURFACE_ID,
      descriptor = {
        title = "Workspaces",
        surface_id = SURFACE_ID,
      },
      call = workspaces_surface,
    },
    {
      id = "open_workspace_presentation_action",
      kind = "ui_action",
      descriptor_id = "botster_workspaces.open",
      descriptor = { action_id = "botster_workspaces.open", surface_id = SURFACE_ID },
      call = open_presentation,
    },
    {
      id = "open_spawn_presentation_action",
      kind = "ui_action",
      descriptor_id = "botster_workspaces.open_spawn",
      descriptor = { action_id = "botster_workspaces.open_spawn", surface_id = SURFACE_ID },
      call = open_presentation,
    },
    {
      id = "create_workspace_action",
      kind = "ui_action",
      descriptor_id = "botster_workspaces.create",
      descriptor = { action_id = "botster_workspaces.create", surface_id = SURFACE_ID },
      call = create_workspace_action,
    },
    {
      id = "rename_workspace_action",
      kind = "ui_action",
      descriptor_id = "botster_workspaces.rename",
      descriptor = { action_id = "botster_workspaces.rename", surface_id = SURFACE_ID },
      call = rename_workspace_action,
    },
    {
      id = "delete_workspace_action",
      kind = "ui_action",
      descriptor_id = "botster_workspaces.delete",
      descriptor = { action_id = "botster_workspaces.delete", surface_id = SURFACE_ID },
      call = delete_workspace_action,
    },
    {
      id = "add_session_action",
      kind = "ui_action",
      descriptor_id = "botster_workspaces.add_session",
      descriptor = { action_id = "botster_workspaces.add_session", surface_id = SURFACE_ID },
      call = add_session_action,
    },
    {
      id = "move_session_action",
      kind = "ui_action",
      descriptor_id = "botster_workspaces.move_session",
      descriptor = { action_id = "botster_workspaces.move_session", surface_id = SURFACE_ID },
      call = move_session_action,
    },
    {
      id = "remove_session_action",
      kind = "ui_action",
      descriptor_id = "botster_workspaces.remove_session",
      descriptor = { action_id = "botster_workspaces.remove_session", surface_id = SURFACE_ID },
      call = remove_session_action,
    },
    {
      id = "select_spawn_target_action",
      kind = "ui_action",
      descriptor_id = "botster_workspaces.select_spawn_target",
      descriptor = { action_id = "botster_workspaces.select_spawn_target", surface_id = SURFACE_ID },
      call = select_spawn_target_action,
    },
    {
      id = "spawn_session_action",
      kind = "ui_action",
      descriptor_id = "botster_workspaces.spawn",
      descriptor = { action_id = "botster_workspaces.spawn", surface_id = SURFACE_ID },
      call = spawn_session_action,
    },
  },
  tools = {
    {
      name = "botster_workspaces.create",
      description = "Create a contextual workspace grouping.",
      input_schema = {
        type = "object",
        properties = { name = { type = "string" } },
        required = { "name" },
        additionalProperties = false,
      },
      handler = "create_workspace",
      call = create_workspace,
    },
    {
      name = "botster_workspaces.list",
      description = "List contextual workspace groupings.",
      input_schema = empty_schema(),
      handler = "list_workspaces",
      call = list_workspaces,
    },
    {
      name = "botster_workspaces.show",
      description = "Show one contextual workspace grouping.",
      input_schema = {
        type = "object",
        properties = {
          id = { type = "string" },
        },
        required = { "id" },
        additionalProperties = false,
      },
      handler = "show_workspace",
      call = show_workspace,
    },
    {
      name = "botster_workspaces.rename",
      description = "Rename a contextual workspace grouping.",
      input_schema = {
        type = "object",
        properties = {
          id = { type = "string" },
          name = { type = "string" },
        },
        required = { "id", "name" },
        additionalProperties = false,
      },
      handler = "rename_workspace",
      call = rename_workspace,
    },
    {
      name = "botster_workspaces.delete",
      description = "Delete only the contextual grouping record.",
      input_schema = {
        type = "object",
        properties = {
          id = { type = "string" },
        },
        required = { "id" },
        additionalProperties = false,
      },
      handler = "delete_workspace",
      call = delete_workspace,
    },
    {
      name = "botster_workspaces.add_session",
      description = "Add an ungrouped Hub session UUID to a workspace.",
      input_schema = {
        type = "object",
        properties = {
          workspace_id = { type = "string" },
          session_id = { type = "string" },
        },
        required = { "workspace_id", "session_id" },
        additionalProperties = false,
      },
      handler = "add_session",
      call = add_session,
    },
    {
      name = "botster_workspaces.move_session",
      description = "Move a grouped Hub session UUID to another workspace atomically.",
      input_schema = {
        type = "object",
        properties = {
          destination_workspace_id = { type = "string" },
          session_id = { type = "string" },
        },
        required = { "destination_workspace_id", "session_id" },
        additionalProperties = false,
      },
      handler = "move_session",
      call = move_session,
    },
    {
      name = "botster_workspaces.remove_session",
      description = "Remove only a workspace membership reference.",
      input_schema = {
        type = "object",
        properties = {
          workspace_id = { type = "string" },
          session_id = { type = "string" },
        },
        required = { "workspace_id", "session_id" },
        additionalProperties = false,
      },
      handler = "remove_session",
      call = remove_session,
    },
    {
      name = "botster_workspaces.spawn",
      description = "Atomically ensure a Hub-managed worktree, spawn a session, and record its returned UUID.",
      input_schema = {
        type = "object",
        properties = {
          workspace_id = { type = "string" },
          target_id = { type = "string" },
          branch = { type = "string" },
          session_type_id = { type = "string" },
          prompt = { type = "string" },
          ticket_id = { type = "string" },
        },
        required = { "workspace_id", "target_id", "branch", "session_type_id" },
        additionalProperties = false,
      },
      handler = "spawn_session",
      call = spawn_session,
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
