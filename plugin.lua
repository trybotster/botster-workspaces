local PLUGIN = "botster-workspaces"
local STATE_KEY = "workspace_state"
local ENTITY_FAMILY = "botster-workspaces.workspace"

local HUB_OWNED_FIELDS = {
  process_state = true,
  process_spawn_request = true,
  pty_state = true,
  pty_request = true,
  raw_spawn_request = true,
  spawn_command = true,
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

local function package_config_values()
  local capabilities = botster and botster.capabilities or {}
  local config = capabilities.config
  if not config or type(config.get) ~= "function" then
    return {}
  end

  local ok, result = pcall(config.get)
  if not ok or type(result) ~= "table" or type(result.values) ~= "table" then
    return {}
  end
  return result.values
end

local function configured_archive_policy()
  local value = package_config_values().archive_policy
  if type(value) == "table" then
    value = value.value
  end
  if value == "archive" or value == "mark_deleted" then
    return value
  end
  return "mark_deleted"
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

local function action_result(arguments, surface_id, action_id, node_id, state, extra)
  local result = {
    request_id = arguments.request_id or action_id,
    surface_id = surface_id,
    action_id = action_id,
    node_id = node_id,
    state = state,
  }
  for key, value in pairs(extra or {}) do
    result[key] = value
  end
  return result
end

local function ui_field_errors(fields, message)
  local errors = {}
  local field_ids = {
    name = "botster-workspaces-create-name",
    purpose = "botster-workspaces-create-purpose",
    local_repo_ref = "botster-workspaces-create-repo-id",
    spawn_target_ref = "botster-workspaces-create-spawn-target-id",
  }
  for _, field in ipairs(fields or {}) do
    errors[field_ids[field] or field] = { message }
  end
  return errors
end

local function form_value(arguments, key, node_id)
  local values = type(arguments.values) == "table" and arguments.values or {}
  local value = values[node_id] or values[key] or arguments[node_id] or arguments[key]
  if type(value) == "table" and value.value ~= nil then
    return value.value
  end
  return value
end

local function spawn_point_options(arguments)
  local capabilities = botster and botster.capabilities or {}
  local spawn_targets = capabilities.spawn_targets
  if spawn_targets and type(spawn_targets.list) == "function" then
    local ok, targets = pcall(spawn_targets.list)
    if ok and type(targets) == "table" then
      local options = {}
      for _, target in ipairs(targets) do
        if type(target) == "table" and target.enabled ~= false then
          local value = trim(target.target_id or target.id or target.value)
          if value then
            local label = trim(target.label or target.name or target.title) or value
            options[#options + 1] = {
              value = value,
              label = label,
            }
          end
        end
      end
      if #options > 0 then
        return options
      end
    end
  end

  local source = type(arguments) == "table" and (arguments.spawn_points or arguments.spawnPoints) or nil
  local options = {}
  if type(source) ~= "table" then
    return options
  end

  for _, spawn_point in ipairs(source) do
    local value = nil
    local label = nil
    if type(spawn_point) == "table" then
      value = trim(spawn_point.id or spawn_point.value or spawn_point.spawn_point_id)
      label = trim(spawn_point.label or spawn_point.name or spawn_point.title) or value
    else
      value = trim(spawn_point)
      label = value
    end
    if value then
      options[#options + 1] = {
        value = value,
        label = label,
      }
    end
  end
  return options
end

local function action_error(arguments, surface_id, action_id, node_id, result)
  local validation = result.error and result.error.code == "validation_failed"
  return action_result(arguments, surface_id, action_id, node_id, validation and "rejected" or "error", {
    field_errors = validation and ui_field_errors(result.fields, result.error.message) or {},
    form_errors = { result.error and result.error.message or "workspace action failed" },
    error = result.error and result.error.message or "workspace action failed",
  })
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
    default_session_template_refs = {},
    archive_policy = configured_archive_policy(),
  }
end

local function normalize_template_ref(value, selected)
  if type(value) ~= "table" then
    local template_id = trim(value)
    if not template_id then
      return nil
    end
    return {
      template_id = template_id,
      label = template_id,
      role = "default",
      group = "main",
      accessory = false,
      selected = selected == true,
      validation_status = "unchecked",
      diagnostic = "template reference has not been validated against the hub",
      last_checked = nil,
    }
  end

  local template_id = trim(value.template_id or value.id)
  if not template_id then
    return nil
  end
  local explicit_selected = value.selected

  return {
    template_id = template_id,
    label = trim(value.label or value.name) or template_id,
    role = trim(value.role) or "default",
    group = trim(value.group) or trim(value.session_group) or "main",
    accessory = value.accessory == true,
    selected = explicit_selected == true or (explicit_selected == nil and selected == true),
    validation_status = trim(value.validation_status) or "unchecked",
    diagnostic = trim(value.diagnostic) or "template reference has not been validated against the hub",
    last_checked = value.last_checked,
  }
end

local function normalize_template_refs(workspace)
  local refs = {}
  local seen = {}
  local source = workspace.default_session_template_refs
    or (workspace.settings and workspace.settings.default_session_template_refs)

  if type(source) == "table" then
    for _, ref in ipairs(source) do
      local normalized = normalize_template_ref(ref, #refs == 0)
      if normalized and not seen[normalized.template_id] then
        seen[normalized.template_id] = true
        refs[#refs + 1] = normalized
      end
    end
  end

  local singular = workspace.default_session_template_id
    or (workspace.settings and workspace.settings.default_session_template_id)
  local normalized = normalize_template_ref(singular, #refs == 0)
  if normalized and not seen[normalized.template_id] then
    seen[normalized.template_id] = true
    refs[#refs + 1] = normalized
  end

  if #refs > 0 then
    local selected_seen = false
    for _, ref in ipairs(refs) do
      if ref.selected and not selected_seen then
        selected_seen = true
      elseif ref.selected then
        ref.selected = false
      end
    end
    if not selected_seen then
      refs[1].selected = true
    end
  end

  workspace.default_session_template_refs = refs
  workspace.default_session_template_id = refs[1] and refs[1].template_id or nil
  workspace.settings = workspace.settings or {}
  workspace.settings.workspace_id = workspace.id
  workspace.settings.default_session_template_refs = copy(refs)
  workspace.settings.default_session_template_id = workspace.default_session_template_id
  return refs
end

local function template_refs_from_arguments(arguments)
  if arguments.default_session_template_refs ~= nil then
    return arguments.default_session_template_refs
  end
  if arguments.default_session_templates ~= nil then
    return arguments.default_session_templates
  end
  if arguments.default_session_template_id ~= nil then
    return { arguments.default_session_template_id }
  end
  return {}
end

local function selected_template_ref(workspace, template_id)
  local refs = normalize_template_refs(workspace)
  local wanted = trim(template_id)
  for _, ref in ipairs(refs) do
    if wanted and ref.template_id == wanted then
      return ref
    end
  end
  for _, ref in ipairs(refs) do
    if ref.selected then
      return ref
    end
  end
  return refs[1]
end

local function short_identifier(value, fallback, max_length)
  local text = trim(value) or fallback
  text = text:gsub("[^%w%-_]+", "-"):gsub("%-+", "-"):gsub("^%-+", ""):gsub("%-+$", "")
  if text == "" then
    text = fallback
  end
  if #text > max_length then
    text = text:sub(#text - max_length + 1)
  end
  return text
end

local function cached_template_summary(workspace)
  local refs = normalize_template_refs(workspace)
  local labels = {}
  local diagnostics = {}
  local invalid = 0
  for _, ref in ipairs(refs) do
    labels[#labels + 1] = ref.label or ref.template_id
    if ref.validation_status ~= "valid" then
      diagnostics[#diagnostics + 1] = (ref.template_id or "unknown") .. ": " .. (ref.diagnostic or ref.validation_status)
    end
    if ref.validation_status == "invalid" then
      invalid = invalid + 1
    end
  end
  return {
    count = #refs,
    labels = labels,
    diagnostics = diagnostics,
    invalid_count = invalid,
  }
end

local function read_model(workspace)
  normalize_template_refs(workspace)
  local session_refs = {}
  if workspace.session_group and type(workspace.session_group.session_refs) == "table" then
    session_refs = workspace.session_group.session_refs
  end
  local template_summary = cached_template_summary(workspace)

  return {
    id = workspace.id,
    name = workspace.name,
    purpose = workspace.purpose,
    status = workspace.status,
    repo_label = workspace.local_repo_ref and workspace.local_repo_ref.display_name or nil,
    spawn_target_label = workspace.spawn_target_ref and workspace.spawn_target_ref.label or nil,
    session_count = #session_refs,
    default_session_template_count = template_summary.count,
    default_session_template_labels = template_summary.labels,
    template_diagnostic_count = #template_summary.diagnostics,
    invalid_template_count = template_summary.invalid_count,
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
  local template_refs = {}
  for _, ref in ipairs(template_refs_from_arguments(arguments)) do
    local normalized = normalize_template_ref(ref, #template_refs == 0)
    if normalized then
      template_refs[#template_refs + 1] = normalized
    end
  end
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
    default_session_template_refs = template_refs,
    settings = default_settings(workspace_id, repo_ref, spawn_target_ref, template_id),
    created_at = timestamp,
    updated_at = timestamp,
  }
  normalize_template_refs(workspace)

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
  if patch.default_session_template_refs ~= nil and type(patch.default_session_template_refs) ~= "table" then
    return error_result("validation_failed", "default_session_template_refs is invalid", { "default_session_template_refs" })
  end
  if patch.session_group ~= nil and not validate_session_refs(patch.session_group.session_refs) then
    return error_result("validation_failed", "session_group.session_refs is invalid", { "session_group.session_refs" })
  end

  workspace.name = next_name
  workspace.purpose = patch.purpose ~= nil and trim(patch.purpose) or workspace.purpose
  workspace.local_repo_ref = patch.local_repo_ref ~= nil and copy(patch.local_repo_ref) or workspace.local_repo_ref
  workspace.spawn_target_ref = patch.spawn_target_ref ~= nil and copy(patch.spawn_target_ref) or workspace.spawn_target_ref
  if patch.default_session_template_refs ~= nil
    or patch.default_session_templates ~= nil
    or patch.default_session_template_id ~= nil then
    workspace.default_session_template_refs = {}
    for _, ref in ipairs(template_refs_from_arguments(patch)) do
      local normalized = normalize_template_ref(ref, #workspace.default_session_template_refs == 0)
      if normalized then
        workspace.default_session_template_refs[#workspace.default_session_template_refs + 1] = normalized
      end
    end
    workspace.default_session_template_id = workspace.default_session_template_refs[1]
      and workspace.default_session_template_refs[1].template_id
      or nil
  end
  if patch.settings ~= nil then
    workspace.settings = copy(patch.settings)
    workspace.settings.workspace_id = workspace.id
  end
  if patch.session_group ~= nil and patch.session_group.session_refs ~= nil then
    workspace.session_group = workspace.session_group or { workspace_id = workspace.id, session_refs = {} }
    workspace.session_group.workspace_id = workspace.id
    workspace.session_group.session_refs = copy(patch.session_group.session_refs)
  end
  normalize_template_refs(workspace)
  workspace.updated_at = next_timestamp(state)

  local error = save_or_error(state)
  if error then
    return error
  end
  return { ok = true, workspace = copy(workspace), entity = read_model(workspace) }
end

local function resolve_template_via_hub(template_id)
  local capabilities = botster and botster.capabilities or {}
  local session_templates = capabilities.session_templates
  if session_templates and type(session_templates.resolve) == "function" then
    local ok, result = pcall(session_templates.resolve, { template_id = template_id })
    if ok and result and result.ok ~= false then
      return {
        validation_status = "valid",
        diagnostic = "template resolved by hub session-template API",
        label = result.label or result.name or result.template_id or template_id,
      }
    end
    return {
      validation_status = "invalid",
      diagnostic = result and result.error and (result.error.message or result.error.code) or tostring(result),
    }
  end
  return {
    validation_status = "unchecked",
    diagnostic = "hub session-template resolve capability unavailable; cached reference retained",
  }
end

local function refresh_template_diagnostics(arguments)
  local workspace_id = trim(arguments.id or arguments.workspace_id)
  if not workspace_id then
    return error_result("missing_argument", "missing required argument: id")
  end

  local state = load_state()
  local workspace = workspace_by_id(state, workspace_id)
  if not workspace then
    return error_result("workspace_not_found", "workspace not found: " .. workspace_id)
  end

  local refs = normalize_template_refs(workspace)
  local checked_at = next_timestamp(state)
  for _, ref in ipairs(refs) do
    local diagnostic = resolve_template_via_hub(ref.template_id)
    ref.validation_status = diagnostic.validation_status
    ref.diagnostic = diagnostic.diagnostic
    ref.label = diagnostic.label or ref.label
    ref.last_checked = checked_at
  end
  normalize_template_refs(workspace)
  workspace.updated_at = next_timestamp(state)

  local error = save_or_error(state)
  if error then
    return error
  end
  return { ok = true, workspace = copy(workspace), entity = read_model(workspace) }
end

local function spawn_default_session(arguments)
  local workspace_id = trim(arguments.id or arguments.workspace_id)
  if not workspace_id then
    return error_result("missing_argument", "missing required argument: id")
  end

  local state = load_state()
  local workspace = workspace_by_id(state, workspace_id)
  if not workspace then
    return error_result("workspace_not_found", "workspace not found: " .. workspace_id)
  end

  local ref = selected_template_ref(workspace, arguments.template_id)
  if not ref then
    return error_result("missing_template_reference", "workspace has no default session template reference")
  end

  local session_id = trim(arguments.session_id)
    or ("ws-" .. short_identifier(workspace.id, "workspace", 18) .. "-" .. short_identifier(ref.template_id, "template", 12))
  local request = {
    type = "spawn_session_template",
    template_id = ref.template_id,
    session_id = session_id,
    request = {
      context = {
        workspace_id = workspace.id,
        prompt = trim(arguments.prompt),
        ticket_id = trim(arguments.ticket_id),
        branch_name = trim(arguments.branch_name),
      },
    },
  }
  local spawn_point_id = trim(arguments.spawn_point_id)
  if spawn_point_id then
    request.request.context.metadata = {
      spawn_point_id = spawn_point_id,
    }
  end

  return {
    ok = true,
    workspace_id = workspace.id,
    template_ref = copy(ref),
    hub_api = "spawn_session_template",
    daemon_request = request,
  }
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

local function create_workspace_from_surface(arguments)
  local result = create_workspace({
    name = form_value(arguments, "name", "botster-workspaces-create-name"),
    purpose = form_value(arguments, "purpose", "botster-workspaces-create-purpose"),
    local_repo_ref = {
      id = form_value(arguments, "repo_id", "botster-workspaces-create-repo-id"),
      display_name = form_value(arguments, "repo_display_name", "botster-workspaces-create-repo-display-name"),
      repo_capability_ref = form_value(arguments, "repo_capability_ref", "botster-workspaces-create-repo-capability-ref"),
      default_branch = form_value(arguments, "repo_default_branch", "botster-workspaces-create-repo-default-branch"),
      relative_worktree_hint = form_value(arguments, "repo_worktree_hint", "botster-workspaces-create-repo-worktree-hint"),
    },
    spawn_target_ref = {
      target_id = form_value(arguments, "spawn_target_id", "botster-workspaces-create-spawn-target-id"),
      label = form_value(arguments, "spawn_target_label", "botster-workspaces-create-spawn-target-label"),
      kind = form_value(arguments, "spawn_target_kind", "botster-workspaces-create-spawn-target-kind"),
      capability_ref = form_value(arguments, "spawn_target_capability_ref", "botster-workspaces-create-spawn-target-capability-ref"),
    },
    default_session_template_id = form_value(arguments, "default_session_template_id", "botster-workspaces-create-default-session-template-id"),
  })
  if not result.ok then
    return action_error(
      arguments,
      "workspaces",
      "botster_workspaces.create_workspace",
      "botster-workspaces-create-form",
      result
    )
  end
  return action_result(arguments, "workspaces", "botster_workspaces.create_workspace", "botster-workspaces-create-form", "accepted", {
    normalized_values = {
      name = result.workspace.name,
      purpose = result.workspace.purpose,
      workspace_id = result.workspace.id,
    },
    payload = {
      message = "Workspace created",
      workspace = result.workspace,
      entity = result.entity,
    },
  })
end

local function spawn_default_session_from_surface(arguments)
  local result = spawn_default_session({
    id = form_value(arguments, "workspace_id", "botster-workspaces-spawn-workspace-id") or arguments.id,
    spawn_point_id = form_value(arguments, "spawn_point_id", "botster-workspaces-spawn-point-id"),
    template_id = form_value(arguments, "template_id", "botster-workspaces-spawn-template-id"),
    session_id = form_value(arguments, "session_id", "botster-workspaces-spawn-session-id"),
    prompt = form_value(arguments, "prompt", "botster-workspaces-spawn-prompt"),
    ticket_id = form_value(arguments, "ticket_id", "botster-workspaces-spawn-ticket-id"),
    branch_name = form_value(arguments, "branch_name", "botster-workspaces-spawn-branch-name"),
  })
  if not result.ok then
    return action_error(
      arguments,
      "workspaces",
      "botster_workspaces.spawn_default_session",
      "botster-workspaces-spawn-form",
      result
    )
  end
  return action_result(arguments, "workspaces", "botster_workspaces.spawn_default_session", "botster-workspaces-spawn-form", "accepted", {
    normalized_values = {
      workspace_id = result.workspace_id,
      spawn_point_id = result.daemon_request.request.context.metadata
        and result.daemon_request.request.context.metadata.spawn_point_id
        or nil,
      template_id = result.template_ref.template_id,
      session_id = result.daemon_request.session_id,
    },
    payload = {
      message = "Workspace session spawn request prepared",
      workspace_id = result.workspace_id,
      template_ref = result.template_ref,
      hub_api = result.hub_api,
      daemon_request = result.daemon_request,
    },
  })
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

local function form_field(id, name, label, options)
  options = options or {}
  local schema = {
    kind = "text",
    name = name,
    label = label,
  }
  for key, value in pairs(options) do
    schema[key] = value
  end
  return {
    type = "form_field",
    id = id,
    props = {
      schema = schema,
    },
  }
end

local function button_node(id, label, action)
  return {
    type = "button",
    id = id,
    props = {
      label = label,
      action = {
        id = action,
      },
    },
  }
end

local function metric_node(id, label, value, caption)
  local props = {
    label = label,
    value = tostring(value),
  }
  if caption then
    props.caption = caption
  end
  return {
    type = "metric",
    id = id,
    props = props,
  }
end

local function status_badge(id, label, status)
  local tone = "default"
  if status == "active" then
    tone = "success"
  elseif status == "archived" then
    tone = "warning"
  elseif status == "deleted" then
    tone = "danger"
  end
  return {
    type = "status_badge",
    id = id,
    props = {
      label = label,
      status = status,
      tone = tone,
    },
  }
end

local function archive_policy_label(policy)
  if policy == "mark_deleted" then
    return "Mark deleted"
  elseif policy == "archive" then
    return "Archive"
  end
  return tostring(policy or "mark_deleted")
end

local function template_summary_text(row)
  if row.default_session_template_labels and #row.default_session_template_labels > 0 then
    return table.concat(row.default_session_template_labels, ", ")
  end
  return "No default templates"
end

local function diagnostic_summary_text(row)
  local count = tonumber(row.template_diagnostic_count or 0) or 0
  local invalid = tonumber(row.invalid_template_count or 0) or 0
  if invalid > 0 then
    return tostring(invalid) .. " invalid template diagnostics"
  end
  return tostring(count) .. " template diagnostics"
end

local function create_workspace_form()
  return {
    type = "form",
    id = "botster-workspaces-create-form",
    children = {
      form_field("botster-workspaces-create-name", "name", "Name", {
        placeholder = "Product refactor",
        required = true,
      }),
      form_field("botster-workspaces-create-purpose", "purpose", "Purpose", {
        placeholder = "Coordinate implementation and review sessions",
        required = true,
      }),
      form_field("botster-workspaces-create-repo-id", "repo_id", "Repo reference id", {
        placeholder = "repo_main",
        required = true,
      }),
      form_field("botster-workspaces-create-repo-display-name", "repo_display_name", "Repo label", {
        placeholder = "Main application repo",
        required = true,
      }),
      form_field("botster-workspaces-create-repo-capability-ref", "repo_capability_ref", "Repo capability", {
        placeholder = "repo_capability_main",
        required = true,
      }),
      form_field("botster-workspaces-create-repo-default-branch", "repo_default_branch", "Default branch", {
        default = "main",
        required = true,
      }),
      form_field("botster-workspaces-create-repo-worktree-hint", "repo_worktree_hint", "Worktree hint", {
        placeholder = "worktrees/product-refactor",
        required = true,
      }),
      form_field("botster-workspaces-create-spawn-target-id", "spawn_target_id", "Spawn target id", {
        placeholder = "target_codex_local",
        required = true,
      }),
      form_field("botster-workspaces-create-spawn-target-label", "spawn_target_label", "Spawn target label", {
        placeholder = "Codex local",
        required = true,
      }),
      form_field("botster-workspaces-create-spawn-target-kind", "spawn_target_kind", "Spawn target kind", {
        default = "agent",
        required = true,
      }),
      form_field("botster-workspaces-create-spawn-target-capability-ref", "spawn_target_capability_ref", "Spawn capability", {
        placeholder = "spawn_target_codex_local",
        required = true,
      }),
      form_field("botster-workspaces-create-default-session-template-id", "default_session_template_id", "Default template", {
        placeholder = "template_codex_implement",
      }),
      button_node("botster-workspaces-create-submit", "Create workspace", "botster_workspaces.create_workspace"),
    },
  }
end

local function spawn_session_form(rows, arguments)
  local first_workspace_id = rows[1] and rows[1].id or nil
  local options = spawn_point_options(arguments)
  local selected_spawn_point = options[1] and options[1].value or nil
  local children = {
    form_field("botster-workspaces-spawn-workspace-id", "workspace_id", "Workspace id", {
      default = first_workspace_id,
      placeholder = "ws_product_refactor_1",
      required = true,
    }),
  }
  if #options > 0 then
    children[#children + 1] = form_field("botster-workspaces-spawn-point-id", "spawn_point_id", "Spawn point", {
      kind = "select",
      default = selected_spawn_point,
      required = true,
      options = options,
    })
  end
  children[#children + 1] = form_field("botster-workspaces-spawn-template-id", "template_id", "Template override", {
    placeholder = "Use selected default when blank",
  })
  children[#children + 1] = form_field("botster-workspaces-spawn-session-id", "session_id", "Session id", {
    placeholder = "Generated when blank",
  })
  children[#children + 1] = form_field("botster-workspaces-spawn-prompt", "prompt", "Prompt", {
    placeholder = "Start from this workspace context",
  })
  children[#children + 1] = form_field("botster-workspaces-spawn-ticket-id", "ticket_id", "Ticket id", {
    placeholder = "Optional",
  })
  children[#children + 1] = form_field("botster-workspaces-spawn-branch-name", "branch_name", "Branch", {
    placeholder = "Optional",
  })
  children[#children + 1] = button_node("botster-workspaces-spawn-submit", "Spawn default session", "botster_workspaces.spawn_default_session")
  return {
    type = "form",
    id = "botster-workspaces-spawn-form",
    children = children,
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
  local template_text = template_summary_text(row)
  local diagnostic_text = diagnostic_summary_text(row)
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
        text_node("workspace-row-" .. tostring(row.id) .. "-repo", "Repo: " .. tostring(row.repo_label or "Unknown repo"), "muted"),
        text_node("workspace-row-" .. tostring(row.id) .. "-spawn-target", "Spawn target: " .. tostring(row.spawn_target_label or "Unknown target"), "muted"),
        text_node("workspace-row-" .. tostring(row.id) .. "-templates", "Templates: " .. template_text, "muted"),
      },
      meta = {
        status_badge("workspace-row-" .. tostring(row.id) .. "-status", row.status, row.status),
        text_node("workspace-row-" .. tostring(row.id) .. "-sessions", tostring(row.session_count) .. " sessions"),
        text_node("workspace-row-" .. tostring(row.id) .. "-template-diagnostics", diagnostic_text),
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

local function workspace_metrics(rows)
  local session_count = 0
  local template_count = 0
  local diagnostic_count = 0
  for _, row in ipairs(rows) do
    session_count = session_count + (tonumber(row.session_count or 0) or 0)
    template_count = template_count + (tonumber(row.default_session_template_count or 0) or 0)
    diagnostic_count = diagnostic_count + (tonumber(row.template_diagnostic_count or 0) or 0)
  end
  return {
    type = "metric_grid",
    id = "botster-workspaces-metrics",
    props = {
      density = "compact",
      variant = "subtle",
    },
    children = {
      metric_node("botster-workspaces-metric-workspaces", "Workspaces", #rows, "Active workspace records"),
      metric_node("botster-workspaces-metric-sessions", "Sessions", session_count, "Referenced hub sessions"),
      metric_node("botster-workspaces-metric-templates", "Default templates", template_count, "Stored template references"),
      metric_node("botster-workspaces-metric-diagnostics", "Diagnostics", diagnostic_count, "Cached template checks"),
    },
  }
end

local function workspaces_toolbar()
  return {
    type = "toolbar",
    id = "botster-workspaces-toolbar",
    props = {
      label = "Workspace actions",
      density = "compact",
    },
  }
end

local function workspace_index_section(rows)
  return {
    type = "section",
    id = "botster-workspaces-index-section",
    props = {
      title = "Workspace index",
      description = "Plugin-owned workspace records and hub-owned references.",
    },
    slots = {
      body = {
        {
          type = "list",
          id = "botster-workspaces-list",
          props = {
            aria_label = "Workspaces",
          },
          children = workspace_list_children(rows),
        },
      },
    },
  }
end

local function create_workspace_section()
  return {
    type = "section",
    id = "botster-workspaces-create-section",
    props = {
      title = "Create workspace",
    },
    slots = {
      body = {
        create_workspace_form(),
      },
    },
  }
end

local function spawn_workspace_section(rows, arguments)
  return {
    type = "section",
    id = "botster-workspaces-spawn-section",
    props = {
      title = "Spawn workspace session",
    },
    slots = {
      body = {
        spawn_session_form(rows, arguments),
      },
    },
  }
end

local function workspaces_surface(arguments)
  local rows = active_read_models(load_state())
  return {
    type = "panel",
    id = "botster-workspaces-app",
    props = {
      title = "Workspaces",
    },
    slots = {
      toolbar = {
        workspaces_toolbar(),
      },
      body = {
        text_node("botster-workspaces-read-model", "Read model: " .. ENTITY_FAMILY, "muted"),
        workspace_metrics(rows),
        workspace_index_section(rows),
        create_workspace_section(),
        spawn_workspace_section(rows, arguments),
      },
    },
  }
end

local function settings_surface()
  local rows = active_read_models(load_state())
  local archive_policy = configured_archive_policy()
  local archive_policy_text = archive_policy_label(archive_policy)
  return {
    type = "panel",
    id = "botster-workspaces-settings",
    props = {
      title = "Workspaces Settings",
    },
    slots = {
      body = {
        {
          type = "section",
          id = "botster-workspaces-settings-policy",
          props = {
            title = "Effective archive policy",
            description = "Package defaults applied to newly created workspace records.",
          },
          slots = {
            body = {
              text_node("botster-workspaces-settings-summary", "Archive policy: " .. archive_policy_text),
              text_node("botster-workspaces-settings-defaults", "Defaults: workspace repo, spawn target, and template references stay plugin-owned.", "muted"),
            },
          },
        },
        {
          type = "section",
          id = "botster-workspaces-settings-diagnostics",
          props = {
            title = "Workspace diagnostics",
            description = "Cached spawn target and template diagnostics for active workspaces.",
          },
          slots = {
            body = {
              workspace_metrics(rows),
              {
                type = "list",
                id = "botster-workspaces-settings-list",
                props = {
                  aria_label = "Workspace settings",
                },
                children = workspace_list_children(rows),
              },
            },
          },
        },
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
    {
      id = "create_workspace_action",
      kind = "ui_action",
      descriptor_id = "botster_workspaces.create_workspace",
      descriptor = {
        action_id = "botster_workspaces.create_workspace",
        surface_id = "workspaces",
      },
      call = create_workspace_from_surface,
    },
    {
      id = "spawn_default_session_action",
      kind = "ui_action",
      descriptor_id = "botster_workspaces.spawn_default_session",
      descriptor = {
        action_id = "botster_workspaces.spawn_default_session",
        surface_id = "workspaces",
      },
      call = spawn_default_session_from_surface,
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
          default_session_template_refs = { type = "array" },
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
      name = "botster_workspaces.refresh_template_diagnostics",
      description = "Refresh cached diagnostics for workspace default session template references.",
      input_schema = {
        type = "object",
        properties = {
          id = { type = "string" },
          workspace_id = { type = "string" },
        },
        additionalProperties = false,
      },
      handler = "refresh_template_diagnostics",
      call = refresh_template_diagnostics,
    },
    {
      name = "botster_workspaces.spawn_default_session",
      description = "Request a hub-owned session spawn from a selected workspace default template.",
      input_schema = {
        type = "object",
        properties = {
          id = { type = "string" },
          workspace_id = { type = "string" },
          template_id = { type = "string" },
          session_id = { type = "string" },
          prompt = { type = "string" },
          ticket_id = { type = "string" },
          branch_name = { type = "string" },
        },
        additionalProperties = false,
      },
      handler = "spawn_default_session",
      call = spawn_default_session,
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
