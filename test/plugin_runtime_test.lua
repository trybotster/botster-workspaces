local database = {}
local registrations = {}
local set_calls = 0
local fail_next_set = false
local fail_next_get = false
local spawn_calls = {}
local template_list_calls = {}
local fail_template_list_for = nil
local spawn_mode = "success"
local next_spawn_uuid = "11111111-1111-4111-8111-111111111111"

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

botster = {
  capabilities = {
    plugin_db = {
      get = function(request)
        if fail_next_get then
          fail_next_get = false
          error("injected read failure")
        end
        local record = database[request.key]
        if not record then
          return { kind = "record" }
        end
        return { record = copy(record) }
      end,
      set = function(request)
        set_calls = set_calls + 1
        if fail_next_set then
          fail_next_set = false
          error("injected persistence failure")
        end
        database[request.key] = {
          schema_version = request.schema_version,
          payload = copy(request.payload),
        }
        return { ok = true }
      end,
    },
    spawn_targets = {
      list = function()
        return {
          { target_id = "tgt_git", label = "Local Git", kind = "git", enabled = true },
          { target_id = "tgt_empty", label = "Git without templates", kind = "git", enabled = true },
          { target_id = "tgt_disabled", label = "Disabled Git", kind = "git", enabled = false },
          { target_id = "tgt_directory", label = "Directory", kind = "directory", enabled = true },
        }
      end,
    },
    session_templates = {
      list = function(request)
        template_list_calls[#template_list_calls + 1] = copy(request)
        if request.target_id == fail_template_list_for then
          error("injected template projection failure")
        end
        if request.target_id == "tgt_git" then
          return {
            { template_id = "implement", label = "Implement" },
            { template_id = "review", label = "Review" },
          }
        end
        return {}
      end,
      ensure_worktree_and_spawn = function(request)
        spawn_calls[#spawn_calls + 1] = copy(request)
        if spawn_mode == "throw" then
          error("injected worker error")
        end
        if spawn_mode == "reject" then
          return {
            ok = false,
            error = {
              code = "branch_conflict",
              message = "branch is already owned",
            },
          }
        end
        return {
          ok = true,
          result = {
            session_id = next_spawn_uuid,
            target_id = request.target_id,
            branch = request.branch,
            worktree_id = "wt-managed",
          },
        }
      end,
    },
  },
  register = function(spec)
    registrations[#registrations + 1] = spec
    return spec
  end,
}

local function assert_true(value, message)
  if not value then
    error(message or "assertion failed")
  end
end

local function assert_eq(actual, expected, message)
  if actual ~= expected then
    error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
  end
end

local function assert_keys(value, expected, message)
  local keys = {}
  for key in pairs(value) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  table.sort(expected)
  assert_eq(table.concat(keys, ","), table.concat(expected, ","), message)
end

local function tool(spec, name)
  for _, candidate in ipairs(spec.tools or {}) do
    if candidate.name == name then
      return candidate.call
    end
  end
  error("missing tool " .. name)
end

local function registered_tool(spec, name)
  for _, candidate in ipairs(spec.tools or {}) do
    if candidate.name == name then
      return candidate
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

local function registered_handler(spec, id)
  for _, candidate in ipairs(spec.handlers or {}) do
    if candidate.id == id then
      return candidate
    end
  end
  error("missing handler " .. id)
end

local function children_of(node)
  local children = {}
  for _, child in ipairs(node.children or {}) do
    children[#children + 1] = child
  end
  for _, slot in pairs(node.slots or {}) do
    for _, child in ipairs(slot) do
      children[#children + 1] = child
    end
  end
  if node["$kind"] == "presentation_if" and node.node then
    children[#children + 1] = node.node
  end
  if node["$kind"] == "bind_list" then
    children[#children + 1] = node.item_template
    if node.empty_template then
      children[#children + 1] = node.empty_template
    end
  end
  return children
end

local function collect_bind_lists(node, result)
  if node["$kind"] == "bind_list" then
    result[#result + 1] = node
  end
  for _, child in ipairs(children_of(node)) do
    collect_bind_lists(child, result)
  end
end

local function collect_node_ids(node, result)
  if node.id then
    result[#result + 1] = node.id
  end
  for _, child in ipairs(children_of(node)) do
    collect_node_ids(child, result)
  end
end

local function find_node(node, id)
  if node.id == id then
    return node
  end
  for _, child in ipairs(children_of(node)) do
    local found = find_node(child, id)
    if found then
      return found
    end
  end
  return nil
end

local function collect_type(node, kind, result)
  if node.type == kind then
    result[#result + 1] = node
  end
  for _, child in ipairs(children_of(node)) do
    collect_type(child, kind, result)
  end
end

local function presentation_matches(predicate, state)
  if predicate.kind == "equals" then
    return state[predicate.key] == predicate.value
  end
  if predicate.kind == "present" then
    return state[predicate.key] ~= nil
  end
  if predicate.kind == "truthy" then
    return not not state[predicate.key]
  end
  return false
end

local function materialize(node, state)
  if node["$kind"] == "presentation_if" then
    if not presentation_matches(node.predicate, state) then
      return nil
    end
    return materialize(node.node, state)
  end
  local result = copy(node)
  result.children = nil
  result.slots = nil
  if node.children then
    result.children = {}
    for _, child in ipairs(node.children) do
      local visible = materialize(child, state)
      if visible then
        result.children[#result.children + 1] = visible
      end
    end
  end
  if node.slots then
    result.slots = {}
    for name, slot in pairs(node.slots) do
      result.slots[name] = {}
      for _, child in ipairs(slot) do
        local visible = materialize(child, state)
        if visible then
          result.slots[name][#result.slots[name] + 1] = visible
        end
      end
    end
  end
  return result
end

local function apply_presentation(state, result)
  for _, operation in ipairs(result.presentation or {}) do
    if operation.kind == "set" then
      state[operation.key] = operation.value
    elseif operation.kind == "clear" then
      state[operation.key] = nil
    elseif operation.kind == "toggle" then
      state[operation.key] = not state[operation.key]
    end
  end
end

local function action_arguments(action, request_id, values)
  return {
    request_id = request_id,
    surface_id = "workspaces",
    action_id = action.id,
    node_id = "test-node",
    payload = copy(action.payload),
    values = values or {},
  }
end

local function json_escape(value)
  return '"' .. value:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
end

local function is_array(value)
  local largest = 0
  local count = 0
  for key in pairs(value) do
    if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
      return false
    end
    count = count + 1
    largest = math.max(largest, key)
  end
  return largest == count
end

local function json_encode(value)
  if value == nil then
    return "null"
  elseif type(value) == "boolean" or type(value) == "number" then
    return tostring(value)
  elseif type(value) == "string" then
    return json_escape(value)
  elseif type(value) ~= "table" then
    error("unsupported JSON value")
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

local spec = dofile("plugin.lua")
assert_eq(#registrations, 1, "plugin registers exactly once")

local tool_names = {
  "botster_workspaces.create",
  "botster_workspaces.list",
  "botster_workspaces.show",
  "botster_workspaces.rename",
  "botster_workspaces.delete",
  "botster_workspaces.add_session",
  "botster_workspaces.move_session",
  "botster_workspaces.remove_session",
  "botster_workspaces.spawn",
  "botster_workspaces.entity_snapshot",
}
for _, name in ipairs(tool_names) do
  assert_true(tool(spec, name), name .. " is registered")
end

local create = tool(spec, "botster_workspaces.create")
local list = tool(spec, "botster_workspaces.list")
local show = tool(spec, "botster_workspaces.show")
local rename = tool(spec, "botster_workspaces.rename")
local delete = tool(spec, "botster_workspaces.delete")
local add_session = tool(spec, "botster_workspaces.add_session")
local move_session = tool(spec, "botster_workspaces.move_session")
local remove_session = tool(spec, "botster_workspaces.remove_session")
local spawn = tool(spec, "botster_workspaces.spawn")
local snapshot = tool(spec, "botster_workspaces.entity_snapshot")

assert_eq(#list({}).workspaces, 0, "missing plugin_db record is a cold empty state")
local writes_before_read_failure = set_calls
fail_next_get = true
assert_eq(list({}).error.code, "workspace_state_read_failed", "plugin_db read failure fails closed")
assert_eq(set_calls, writes_before_read_failure, "plugin_db read failure cannot trigger a destructive write")

assert_keys(
  registered_tool(spec, "botster_workspaces.show").input_schema.properties,
  { "id" },
  "show schema has one canonical identifier"
)
assert_eq(registered_tool(spec, "botster_workspaces.show").input_schema.required[1], "id", "show schema requires id")
assert_keys(
  registered_tool(spec, "botster_workspaces.add_session").input_schema.properties,
  { "workspace_id", "session_id" },
  "add schema has no id alias"
)
assert_keys(
  registered_tool(spec, "botster_workspaces.move_session").input_schema.properties,
  { "destination_workspace_id", "session_id" },
  "move schema has one destination identifier"
)

local empty_surface = handler(spec, "workspaces_surface")({})
assert_eq(empty_surface.id, "botster-workspaces-app", "stable app surface renders")
local initial_materialized = materialize(empty_surface, {})
local initial_forms = {}
collect_type(initial_materialized, "form", initial_forms)
assert_eq(#initial_forms, 0, "contextual forms are absent before an accepted open action")
assert_true(find_node(initial_materialized, "botster-workspaces-new"), "empty index has New workspace action")
assert_true(find_node(initial_materialized, "botster-workspaces-empty"), "empty index has empty state")
assert_eq(
  find_node(initial_materialized, "botster-workspaces-empty-create").props.label,
  "New workspace",
  "empty state has an explicitly labelled sibling action"
)

local open = handler(spec, "open_workspace_presentation_action")
local new_button = find_node(empty_surface, "botster-workspaces-new")
local presentation_state = {}
local opened_create = open(action_arguments(new_button.props.action, "request-open-create"))
assert_eq(opened_create.state, "accepted", "New workspace action is accepted")
assert_eq(opened_create.action_id, new_button.props.action.id, "dispatch uses rendered action id")
apply_presentation(presentation_state, opened_create)
local create_visible = materialize(empty_surface, presentation_state)
assert_true(find_node(create_visible, "botster-workspaces-create-form"), "accepted set reveals create dialog")

local create_action = handler(spec, "create_workspace_action")
local rejected_create = create_action({
  request_id = "request-create-invalid",
  surface_id = "workspaces",
  action_id = "botster_workspaces.create",
  node_id = "botster-workspaces-create-form",
  values = {},
})
assert_eq(rejected_create.state, "rejected", "invalid create retains contextual form")
local create_name_input = find_node(create_visible, "botster-workspaces-create-name")
assert_true(create_name_input, "create form renders its name input")
assert_true(rejected_create.field_errors[create_name_input.id], "invalid create keys its error to the rendered field")
assert_eq(rejected_create.presentation, nil, "rejected create cannot mutate presentation")
assert_eq(rejected_create.replacement, nil, "rejected create cannot replace the tree")

local created = create({ name = "  Release planning  " })
assert_eq(created.ok, true, "create succeeds")
assert_keys(
  created.workspace,
  { "id", "name", "session_refs", "created_at", "updated_at" },
  "workspace record has the exact five-field schema"
)
assert_eq(created.workspace.name, "Release planning", "create trims name")
assert_eq(#created.workspace.session_refs, 0, "new workspace has no memberships")

local single_workspace_move = materialize(handler(spec, "workspaces_surface")({}), {
  ["selected-workspace"] = created.workspace.id,
  ["workspace-dialog"] = "move:" .. created.workspace.id,
})
assert_true(
  find_node(single_workspace_move, "botster-workspaces-move-empty-" .. created.workspace.id),
  "single-workspace Move dialog renders a valid empty state"
)
assert_eq(
  find_node(single_workspace_move, "botster-workspaces-move-form-" .. created.workspace.id),
  nil,
  "single-workspace Move dialog does not emit an empty select"
)

for _, field in ipairs({
  "purpose",
  "local_repo_ref",
  "spawn_target_ref",
  "default_session_template_id",
  "archive_policy",
  "settings",
  "status",
}) do
  local invalid = create({ name = "Invalid " .. field, [field] = true })
  assert_eq(invalid.ok, false, "create rejects obsolete " .. field)
  assert_eq(invalid.error.code, "obsolete_field", "obsolete create field is typed")
end
local unknown = create({ name = "Unknown", future_field = true })
assert_eq(unknown.error.code, "unknown_field", "create rejects unknown fields")

local duplicate = create({ name = "Release planning" })
assert_eq(duplicate.error.code, "duplicate_name", "existing names are unique")
local second = create({ name = "Review queue" })
assert_eq(second.ok, true, "second workspace creates")

local renamed = rename({ id = created.workspace.id, name = "  Release train  " })
assert_eq(renamed.workspace.name, "Release train", "rename trims and changes only name")
assert_eq(renamed.workspace.id, created.workspace.id, "rename preserves id")
assert_eq(renamed.workspace.created_at, created.workspace.created_at, "rename preserves creation")
local duplicate_rename = rename({ id = second.workspace.id, name = "Release train" })
assert_eq(duplicate_rename.error.code, "duplicate_name", "rename enforces name uniqueness")
local rename_obsolete = rename({ id = second.workspace.id, name = "Other", purpose = "legacy" })
assert_eq(rename_obsolete.error.code, "unknown_field", "rename rejects obsolete extras")

local session_one = "22222222-2222-4222-8222-222222222222"
local session_two = "33333333-3333-4333-8333-333333333333"
local before_add = set_calls
local added = add_session({ workspace_id = renamed.workspace.id, session_id = session_one })
assert_eq(added.ok, true, "add existing session succeeds")
assert_eq(set_calls, before_add + 1, "add persists complete state once")
assert_eq(added.workspace.session_refs[1], session_one, "add preserves canonical session identity")

local duplicate_add = add_session({ workspace_id = second.workspace.id, session_id = session_one })
assert_eq(duplicate_add.error.code, "session_already_owned", "add rejects another owner")
assert_eq(duplicate_add.owner_workspace_id, renamed.workspace.id, "duplicate identifies current owner")
local invalid_session = add_session({ workspace_id = second.workspace.id, session_id = "not-a-uuid" })
assert_eq(invalid_session.error.code, "validation_failed", "membership requires canonical UUID")
local short_uuid = add_session({ workspace_id = second.workspace.id, session_id = "1-2-3-4-5" })
assert_eq(short_uuid.error.code, "validation_failed", "membership rejects non-canonical UUID group lengths")

local added_second = add_session({ workspace_id = renamed.workspace.id, session_id = session_two })
assert_eq(added_second.ok, true, "second reference adds")
local before_move = set_calls
local moved = move_session({ destination_workspace_id = second.workspace.id, session_id = session_one })
assert_eq(moved.ok, true, "explicit move succeeds")
assert_eq(set_calls, before_move + 1, "move persists source and destination once")
assert_eq(#moved.source.session_refs, 1, "move removes source membership")
assert_eq(moved.destination.session_refs[1], session_one, "move inserts destination membership")

local before_remove = set_calls
local removed = remove_session({ workspace_id = renamed.workspace.id, session_id = session_two })
assert_eq(removed.ok, true, "remove membership succeeds")
assert_eq(set_calls, before_remove + 1, "remove persists once")
assert_eq(#removed.workspace.session_refs, 0, "remove changes grouping only")

local restart_spec = dofile("plugin.lua")
local restarted = tool(restart_spec, "botster_workspaces.list")({})
assert_eq(#restarted.workspaces, 2, "restart preserves workspace state")
assert_eq(restarted.workspaces[2].session_refs[1], session_one, "restart preserves moved membership")

local spawn_before = show({ id = renamed.workspace.id })
local spawn_result = spawn({
  workspace_id = renamed.workspace.id,
  target_id = "tgt_git",
  branch = "feature/contextual-workspaces",
  template_id = "implement",
  prompt = "Implement this ticket",
  ticket_id = "ticket-example",
})
local persisted_spawn_uuid = spawn_result.session_id
assert_eq(spawn_result.ok, true, "atomic Hub spawn succeeds")
assert_eq(spawn_result.session_id, next_spawn_uuid, "only returned Hub UUID is recorded")
assert_eq(#spawn_result.workspace.session_refs, #spawn_before.workspace.session_refs + 1, "spawn appends one membership")
assert_eq(spawn_result.workspace.session_refs[#spawn_result.workspace.session_refs], next_spawn_uuid, "spawn persists returned UUID")
local spawn_request = spawn_calls[#spawn_calls]
assert_eq(spawn_request.target_id, "tgt_git", "spawn sends semantic target")
assert_eq(spawn_request.branch, "feature/contextual-workspaces", "spawn sends branch")
assert_eq(spawn_request.template_id, "implement", "spawn sends effective session type")
assert_eq(spawn_request.context.workspace_id, renamed.workspace.id, "spawn sends safe workspace context")
assert_eq(spawn_request.session_id, nil, "spawn never supplies session id")
assert_eq(spawn_request.cwd, nil, "spawn never supplies cwd")
assert_eq(spawn_request.repo_path, nil, "spawn never supplies repo path")
assert_eq(spawn_request.worktree_path, nil, "spawn never supplies worktree path")
assert_eq(spawn_request.base_ref, nil, "spawn never supplies base ref")

local caller_id_rejected = spawn({
  workspace_id = renamed.workspace.id,
  target_id = "tgt_git",
  branch = "caller-id",
  template_id = "implement",
  session_id = "44444444-4444-4444-8444-444444444444",
})
assert_eq(caller_id_rejected.error.code, "unknown_field", "spawn rejects caller session id")

spawn_mode = "reject"
local membership_before_reject = #show({ id = renamed.workspace.id }).workspace.session_refs
local rejected_spawn = spawn({
  workspace_id = renamed.workspace.id,
  target_id = "tgt_git",
  branch = "conflict",
  template_id = "implement",
})
assert_eq(rejected_spawn.error.code, "branch_conflict", "typed Hub rejection is preserved")
assert_eq(#show({ id = renamed.workspace.id }).workspace.session_refs, membership_before_reject, "Hub rejection records nothing")

spawn_mode = "throw"
local thrown_spawn = spawn({
  workspace_id = renamed.workspace.id,
  target_id = "tgt_git",
  branch = "worker-error",
  template_id = "implement",
})
assert_eq(thrown_spawn.error.code, "hub_spawn_failed", "worker error is typed")
assert_eq(#show({ id = renamed.workspace.id }).workspace.session_refs, membership_before_reject, "worker error records nothing")

spawn_mode = "success"
next_spawn_uuid = "55555555-5555-4555-8555-555555555555"
fail_next_set = true
local persist_failed_spawn = spawn({
  workspace_id = renamed.workspace.id,
  target_id = "tgt_git",
  branch = "persistence-failure",
  template_id = "review",
})
assert_eq(persist_failed_spawn.error.code, "persist_failed", "post-spawn persistence failure is explicit")
assert_eq(persist_failed_spawn.spawned_session_id, next_spawn_uuid, "exception exposes ungrouped spawned session")
assert_eq(persist_failed_spawn.membership_recorded, false, "exception never claims membership")
assert_eq(#show({ id = renamed.workspace.id }).workspace.session_refs, membership_before_reject, "failed persistence does not mutate durable membership")

local entity_rows = snapshot({})
assert_eq(entity_rows.entity_family, "botster-workspaces.workspace", "entity family is plugin-namespaced")
assert_eq(#entity_rows.rows, 2, "entity snapshot contains current records")
assert_keys(
  entity_rows.rows[1],
  { "id", "name", "session_refs", "session_count", "created_at", "updated_at", "entity_family" },
  "entity row contains grouping read model only"
)

local template_calls_before_surface = #template_list_calls
local surface = handler(spec, "workspaces_surface")({})
assert_eq(
  #template_list_calls,
  template_calls_before_surface + 2,
  "one surface render lists templates once per enabled Git target"
)
local raw_forms = {}
collect_type(surface, "form", raw_forms)
assert_true(#raw_forms > 0, "owner-authored contextual forms exist behind presentation predicates")
local closed_surface = materialize(surface, {})
local closed_forms = {}
collect_type(closed_surface, "form", closed_forms)
assert_eq(#closed_forms, 0, "no form materializes before an accepted open action")

local first_row = find_node(surface, "botster-workspaces-row-" .. renamed.workspace.id)
assert_true(first_row.props.action, "workspace row carries selection action metadata")
local selected = open(action_arguments(first_row.props.action, "request-select-workspace"))
assert_eq(selected.action_id, first_row.props.action.id, "row dispatch uses rendered action id")
apply_presentation(presentation_state, selected)
local selected_surface = materialize(surface, presentation_state)
assert_true(find_node(selected_surface, "botster-workspaces-selected-" .. renamed.workspace.id), "selection reveals same-route detail")

local rerendered = materialize(handler(spec, "workspaces_surface")({}), presentation_state)
assert_true(find_node(rerendered, "botster-workspaces-selected-" .. renamed.workspace.id), "selected workspace stays stable across rerender")
assert_true(find_node(rerendered, "botster-workspaces-spawn-" .. renamed.workspace.id), "detail exposes Spawn")
assert_true(find_node(rerendered, "botster-workspaces-rename-" .. renamed.workspace.id), "detail exposes rename")
assert_true(find_node(rerendered, "botster-workspaces-delete-" .. renamed.workspace.id), "detail exposes delete")
assert_true(find_node(rerendered, "botster-workspaces-add-" .. renamed.workspace.id), "detail exposes Add existing session")
assert_true(find_node(rerendered, "botster-workspaces-move-" .. renamed.workspace.id), "detail exposes Move existing session")
assert_true(
  find_node(
    rerendered,
    "botster-workspaces-remove-current-" .. renamed.workspace.id .. "-" .. persisted_spawn_uuid
  ),
  "detail exposes lifecycle-bound remove membership"
)

local lifecycle_bindings = {}
collect_bind_lists(surface, lifecycle_bindings)
assert_eq(#lifecycle_bindings, 8, "each stored reference authors exactly four canonical session bindings")
for _, binding in ipairs(lifecycle_bindings) do
  assert_eq(binding.source, "/session", "lifecycle bindings use the canonical Hub session family")
end
for _, group in ipairs({ "current", "ended", "indeterminate" }) do
  local expected_id = "botster-workspaces-session-" .. group .. "-" .. renamed.workspace.id .. "-" .. persisted_spawn_uuid
  local binding
  for _, candidate in ipairs(lifecycle_bindings) do
    if candidate.item_template and candidate.item_template.id == expected_id then
      binding = candidate
      break
    end
  end
  assert_true(binding, group .. " lifecycle binding is present")
  assert_eq(binding.where.session_uuid, persisted_spawn_uuid, group .. " binding filters exact session UUID")
  assert_eq(binding.where.lifecycle_class, group, group .. " binding filters canonical lifecycle class")
  assert_eq(binding.empty_template, nil, group .. " binding renders nothing when it does not match")
  local remove = find_node(binding.item_template, "botster-workspaces-remove-" .. group .. "-" .. renamed.workspace.id .. "-" .. persisted_spawn_uuid)
  assert_true(remove, group .. " row retains a literal Remove action")
  assert_eq(remove.props.action.payload.workspace_id, renamed.workspace.id, group .. " Remove action keeps workspace identity")
  assert_eq(remove.props.action.payload.session_id, persisted_spawn_uuid, group .. " Remove action keeps session identity")
end
local absence_binding
for _, candidate in ipairs(lifecycle_bindings) do
  if candidate.item_template
    and candidate.item_template.id == "botster-workspaces-session-present-" .. renamed.workspace.id .. "-" .. persisted_spawn_uuid
  then
    absence_binding = candidate
    break
  end
end
assert_true(absence_binding, "absence projection is present")
assert_eq(absence_binding.where.session_uuid, persisted_spawn_uuid, "absence projection filters exact session UUID")
assert_eq(absence_binding.where.lifecycle_class, nil, "absence projection does not guess lifecycle")
assert_eq(absence_binding.item_template.type, "stack", "present absence template is structurally inert")
assert_eq(#(absence_binding.item_template.children or {}), 0, "present absence template has no visible descendants")
assert_true(
  find_node(
    absence_binding.empty_template,
    "botster-workspaces-remove-absent-" .. renamed.workspace.id .. "-" .. persisted_spawn_uuid
  ),
  "absent reference remains legible and removable"
)

local scale_workspace = create({ name = "Lifecycle binding scale" }).workspace
for index = 1, 16 do
  local session_id = string.format("90000000-0000-4000-8000-%012d", index)
  assert_eq(
    add_session({ workspace_id = scale_workspace.id, session_id = session_id }).ok,
    true,
    "scale reference adds"
  )
end
local scale_surface = handler(spec, "workspaces_surface")({})
local scale_detail = find_node(scale_surface, "botster-workspaces-detail-" .. scale_workspace.id)
assert_true(scale_detail, "16-reference workspace detail is authored")
local scale_bindings = {}
collect_bind_lists(scale_detail, scale_bindings)
assert_eq(#scale_bindings, 64, "16 references author no more than 64 bindings")
local scale_ids = {}
collect_node_ids(scale_detail, scale_ids)
local seen_scale_ids = {}
for _, id in ipairs(scale_ids) do
  assert_eq(seen_scale_ids[id], nil, "16-reference tree keeps literal node ids unique")
  seen_scale_ids[id] = true
end
for index = 1, 16 do
  local session_id = string.format("90000000-0000-4000-8000-%012d", index)
  local remove = find_node(
    scale_detail,
    "botster-workspaces-remove-ended-" .. scale_workspace.id .. "-" .. session_id
  )
  assert_true(remove, "scale row keeps an actionable literal descendant")
  assert_eq(remove.props.action.payload.session_id, session_id, "scale action preserves its literal session UUID")
end
assert_eq(delete({ id = scale_workspace.id }).ok, true, "scale fixture cleans up through workspace semantics")

presentation_state["workspace-dialog"] = "move:" .. renamed.workspace.id
local move_dialog = materialize(surface, presentation_state)
local move_destination = find_node(move_dialog, "botster-workspaces-move-destination-id-" .. second.workspace.id)
assert_true(move_destination, "move dialog lists another workspace")
assert_eq(move_destination.props.value, second.workspace.id, "move option uses destination id")
assert_eq(move_destination.props.label, "Review queue", "move option has required destination label")
presentation_state["workspace-dialog"] = nil

local spawn_button = find_node(surface, "botster-workspaces-spawn-" .. renamed.workspace.id)
local open_spawn = open(action_arguments(spawn_button.props.action, "request-open-spawn"))
apply_presentation(presentation_state, open_spawn)
local target_dialog = materialize(surface, presentation_state)
local target_form = find_node(target_dialog, "botster-workspaces-spawn-target-form-" .. renamed.workspace.id)
assert_true(target_form, "Spawn opens target-first dialog")
local target_select = find_node(target_form, "botster-workspaces-spawn-target")
assert_eq(#target_select.slots.options, 2, "spawn point projection includes enabled Git targets only")
assert_eq(target_select.slots.options[1].props.value, "tgt_git", "spawn point uses Hub target id")

presentation_state["workspace-dialog"] = "spawn:" .. renamed.workspace.id .. ":tgt_empty"
local empty_template_dialog = materialize(surface, presentation_state)
assert_true(
  find_node(empty_template_dialog, "botster-workspaces-spawn-empty-" .. renamed.workspace.id .. "-tgt_empty"),
  "target with no effective session types renders an explicit empty state"
)
fail_template_list_for = "tgt_empty"
local failed_projection_surface = handler(spec, "workspaces_surface")({})
local failed_projection_dialog = materialize(failed_projection_surface, presentation_state)
assert_true(
  find_node(failed_projection_dialog, "botster-workspaces-spawn-error-" .. renamed.workspace.id .. "-tgt_empty"),
  "template projection failure renders an explicit unavailable state"
)
fail_template_list_for = nil
presentation_state["workspace-dialog"] = "spawn-target:" .. renamed.workspace.id

local select_target = handler(spec, "select_spawn_target_action")
local selected_target = select_target({
  request_id = "request-select-target",
  surface_id = "workspaces",
  action_id = target_form.props.action.id,
  node_id = target_form.id,
  payload = target_form.props.action.payload,
  values = {
    ["botster-workspaces-spawn-target"] = "tgt_git",
  },
})
assert_eq(selected_target.state, "accepted", "target selection is accepted")
apply_presentation(presentation_state, selected_target)
local spawn_dialog = materialize(selected_target.replacement, presentation_state)
local spawn_form = find_node(
  spawn_dialog,
  "botster-workspaces-spawn-form-" .. renamed.workspace.id .. "-tgt_git"
)
assert_true(spawn_form, "target selection installs target-filtered spawn form")
assert_eq(spawn_form.children[1].props.label, "Spawn point", "spawn form begins with selected spawn point")
assert_eq(spawn_form.children[3].props.label, "Branch / worktree", "branch/worktree follows spawn point")
assert_eq(spawn_form.children[4].props.label, "Session type", "effective session type follows branch/worktree")
assert_eq(#spawn_form.children[4].slots.options, 2, "session type options are target-filtered")
for _, request in ipairs(template_list_calls) do
  assert_true(
    request.target_id == "tgt_git" or request.target_id == "tgt_empty",
    "every template projection is scoped to an enabled Git target"
  )
end

local accepted_create = create_action({
  request_id = "request-create-valid",
  surface_id = "workspaces",
  action_id = "botster_workspaces.create",
  node_id = "botster-workspaces-create-form",
  values = {
    ["botster-workspaces-create-name"] = "Action-created",
  },
})
assert_eq(accepted_create.state, "accepted", "valid create action is accepted")
assert_eq(accepted_create.presentation[1].kind, "clear", "accepted submit clears its dialog")
assert_true(accepted_create.replacement, "accepted submit installs owner-authored replacement")
assert_eq(accepted_create.payload.workspace.name, "Action-created", "accepted action returns created workspace")

local action_remove_session_id = "77777777-7777-4777-8777-777777777777"
assert_eq(add_session({
  workspace_id = accepted_create.payload.workspace.id,
  session_id = action_remove_session_id,
}).ok, true, "remove action fixture membership adds")
local removed_action = handler(spec, "remove_session_action")({
  request_id = "request-remove-session",
  surface_id = "workspaces",
  action_id = "botster_workspaces.remove_session",
  node_id = "botster-workspaces-remove-" .. action_remove_session_id,
  payload = {
    workspace_id = accepted_create.payload.workspace.id,
    session_id = action_remove_session_id,
  },
})
assert_eq(removed_action.state, "accepted", "remove membership action is accepted")
assert_eq(removed_action.presentation, nil, "remove membership omits empty presentation operations")
assert_true(removed_action.replacement, "remove membership installs owner-authored replacement")

local delete_target = create({ name = "Disposable grouping" })
local session_to_preserve = "66666666-6666-4666-8666-666666666666"
assert_eq(add_session({ workspace_id = delete_target.workspace.id, session_id = session_to_preserve }).ok, true, "delete fixture membership adds")
local spawn_call_count = #spawn_calls
local deleted = delete({ id = delete_target.workspace.id })
assert_eq(deleted.ok, true, "delete removes grouping")
assert_eq(deleted.workspace.session_refs[1], session_to_preserve, "delete reports preserved membership history")
assert_eq(show({ id = delete_target.workspace.id }).error.code, "workspace_not_found", "grouping record is physically removed")
assert_eq(#spawn_calls, spawn_call_count, "delete never invokes Hub spawn or lifecycle mutation")
assert_eq(create({ name = "Disposable grouping" }).ok, true, "delete releases name immediately")

database.workspace_state = {
  schema_version = 1,
  payload = {
    next_workspace = 1,
    next_timestamp = 1,
    workspaces = {
      {
        id = "legacy",
        name = "Legacy repository workspace",
        purpose = "old shape",
        session_refs = {},
        created_at = "old",
        updated_at = "old",
      },
    },
  },
}
local legacy = list({})
assert_eq(legacy.error.code, "legacy_workspace_schema", "persisted legacy workspace fails closed")
local legacy_surface = handler(spec, "workspaces_surface")({})
assert_eq(legacy_surface.id, "botster-workspaces-schema-error", "legacy state renders operator-legible error")

local output_path = os.getenv("BOTSTER_WORKSPACES_SURFACE_JSON")
if output_path and output_path ~= "" then
  database = {
    workspace_state = {
      schema_version = 1,
      payload = {
        next_workspace = 2,
        next_timestamp = 2,
        workspaces = {
          {
            id = "ws_contract_alpha",
            name = "Contract alpha",
            session_refs = { "88888888-8888-4888-8888-888888888888" },
            created_at = "plugin-clock-000001",
            updated_at = "plugin-clock-000001",
          },
          {
            id = "ws_contract_beta",
            name = "Contract beta",
            session_refs = {},
            created_at = "plugin-clock-000002",
            updated_at = "plugin-clock-000002",
          },
        },
      },
    },
  }
  local file = assert(io.open(output_path, "w"))
  file:write(json_encode({
    empty_surface,
    handler(spec, "workspaces_surface")({}),
  }))
  file:write("\n")
  file:close()
end

assert_eq(registered_handler(spec, "workspaces_surface").kind, "surface_route", "production surface handler is registered")
assert_eq(registered_handler(spec, "spawn_session_action").kind, "ui_action", "production spawn action is registered")

if os.getenv("BOTSTER_WORKSPACES_INJECT_FAILURE") == "1" then
  error("deliberate harness failure")
end

print("test/plugin_runtime_test.lua: ok")
