local database = {}
local registrations = {}
local set_calls = 0
local batch_calls = 0
local publish_calls = {}
local fail_next_set = false
local fail_next_get = false
local fail_next_batch = false
local batch_conflict_once = false
local spawn_calls = {}
local session_type_list_calls = {}
local fail_session_type_list_for = nil
local spawn_mode = "success"
local spawn_rejection_kind = "branch_in_use"
local spawn_rejection_message = "branch is already checked out"
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

local function apply_set(request)
  local current = database[request.key]
  local current_revision = current and (current.revision or 1) or 0
  if request.expected_revision ~= nil and request.expected_revision ~= current_revision then
    return {
      ok = false,
      error_kind = "revision_conflict",
      message = "revision conflict for " .. request.key,
      key = request.key,
    }
  end
  local revision = current_revision + 1
  if current_revision == 0 then
    revision = 1
  end
  database[request.key] = {
    schema_version = request.schema_version or 1,
    payload = copy(request.payload),
    revision = revision,
  }
  return { ok = true, record = copy(database[request.key]) }
end

botster = {
  entity_publish = function(frame)
    publish_calls[#publish_calls + 1] = copy(frame)
    return {
      ok = true,
      status = "accepted",
      last_accepted_seq = frame.snapshot_seq,
      high_water_seq = frame.snapshot_seq,
    }
  end,
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
        local result = apply_set(request)
        if not result.ok then
          return result
        end
        return { ok = true, record = result.record }
      end,
      list = function(request)
        local prefix = request.prefix or ""
        local entries = {}
        for key, record in pairs(database) do
          if key:sub(1, #prefix) == prefix then
            entries[#entries + 1] = {
              key = key,
              revision = record.revision or 1,
            }
          end
        end
        table.sort(entries, function(left, right)
          return left.key < right.key
        end)
        return { entries = entries }
      end,
      batch = function(request)
        batch_calls = batch_calls + 1
        if fail_next_batch then
          fail_next_batch = false
          error("injected batch failure")
        end
        if batch_conflict_once then
          batch_conflict_once = false
          return {
            ok = false,
            error_kind = "revision_conflict",
            message = "injected batch revision conflict",
            mutation_index = 1,
            key = request.mutations[1] and request.mutations[1].key,
          }
        end
        local snapshot = copy(database)
        local results = {}
        for index, mutation in ipairs(request.mutations or {}) do
          if mutation.operation == "set" then
            local result = apply_set(mutation)
            if not result.ok then
              database = snapshot
              result.mutation_index = index
              return result
            end
            results[#results + 1] = result
          elseif mutation.operation == "delete" then
            local current = database[mutation.key]
            local current_revision = current and (current.revision or 1) or 0
            if mutation.expected_revision ~= current_revision then
              database = snapshot
              return {
                ok = false,
                error_kind = "revision_conflict",
                message = "delete revision conflict",
                mutation_index = index,
                key = mutation.key,
              }
            end
            if not current then
              database = snapshot
              return {
                ok = false,
                error_kind = "store_not_found",
                message = "missing key",
                mutation_index = index,
                key = mutation.key,
              }
            end
            database[mutation.key] = nil
            results[#results + 1] = { ok = true, key = mutation.key, revision = current_revision }
          else
            database = snapshot
            return {
              ok = false,
              error_kind = "invalid_request",
              message = "unsupported mutation",
              mutation_index = index,
              key = mutation.key,
            }
          end
        end
        return { ok = true, results = results }
      end,
    },
    spawn_targets = {
      list = function()
        return {
          { target_id = "tgt_git", label = "Local Git", kind = "git", enabled = true },
          { target_id = "tgt_empty", label = "Git without session types", kind = "git", enabled = true },
          { target_id = "tgt_disabled", label = "Disabled Git", kind = "git", enabled = false },
          { target_id = "tgt_directory", label = "Directory", kind = "directory", enabled = true },
        }
      end,
    },
    session_types = {
      -- The real Hub returns a bare array of effective rows whose
      -- session_type_id is fully qualified as "<source name>/<id>".
      list = function(request)
        session_type_list_calls[#session_type_list_calls + 1] = copy(request)
        if request.target_id == fail_session_type_list_for then
          error("injected session-type projection failure")
        end
        if request.target_id == "tgt_git" then
          return {
            { session_type_id = "acceptance-package/implement", id = "implement", label = "Implement" },
            { session_type_id = "acceptance-package/review", id = "review", label = "Review" },
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
              kind = spawn_rejection_kind,
              message = spawn_rejection_message,
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

local function collect_action_nodes(node, action_id, result)
  if node.props and node.props.action and node.props.action.id == action_id then
    result[#result + 1] = node
  end
  for _, child in ipairs(children_of(node)) do
    collect_action_nodes(child, action_id, result)
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

-- The spawn descriptor is the downstream agent contract, so its published shape
-- is asserted here and again against real Hub discovery in hub_acceptance_smoke.
local spawn_schema = registered_tool(spec, "botster_workspaces.spawn").input_schema
assert_keys(
  spawn_schema.properties,
  { "workspace_id", "target_id", "branch", "session_type_id", "prompt", "ticket_id" },
  "spawn schema publishes the exact migrated property set"
)
assert_eq(spawn_schema.type, "object", "spawn schema is an object schema")
assert_eq(spawn_schema.additionalProperties, false, "spawn schema forbids additional properties")
assert_eq(table.concat(spawn_schema.required, ","), "workspace_id,target_id,branch,session_type_id", "spawn schema requires the migrated field set in order")
assert_eq(spawn_schema.properties.session_type_id.type, "string", "spawn schema types session_type_id")
assert_eq(spawn_schema.properties.template_id, nil, "spawn schema publishes no superseded field") -- cold-cut negative control

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

-- The three frozen pre-production create arguments are not active Hub
-- vocabulary; they must keep producing obsolete_field rather than being deleted
-- with the rest of the superseded names.
for _, field in ipairs({
  "purpose",
  "local_repo_ref",
  "spawn_target_ref",
  "default_session_template",
  "default_session_template_id",
  "default_session_template_refs",
  "archive_policy",
  "settings",
  "status",
}) do
  local invalid = create({ name = "Invalid " .. field, [field] = true })
  assert_eq(invalid.ok, false, "create rejects obsolete " .. field)
  assert_eq(invalid.error.code, "obsolete_field", "obsolete create field " .. field .. " is typed")
  assert_true(invalid.error.code ~= "unknown_field", "frozen create field " .. field .. " must not degrade to unknown_field")
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
local before_add = batch_calls
local publish_before_add = #publish_calls
local added = add_session({ workspace_id = renamed.workspace.id, session_id = session_one })
assert_eq(added.ok, true, "add existing session succeeds")
assert_eq(batch_calls, before_add + 1, "add persists membership index, state, and seq once")
assert_eq(added.workspace.session_refs[1], session_one, "add preserves canonical session identity")
assert_true(database["membership:" .. session_one], "add writes membership index key")
assert_eq(
  database["membership:" .. session_one].payload.workspace_id,
  renamed.workspace.id,
  "membership index records owner workspace"
)
assert_eq(
  database["membership:" .. session_one].payload.session_uuid,
  session_one,
  "membership payload carries only session identity"
)
assert_eq(database["membership:" .. session_one].payload.lifecycle, nil, "membership does not copy Hub lifecycle")
assert_eq(database["membership:" .. session_one].payload.label, nil, "membership does not copy Hub label")
assert_eq(database["membership_entity_seq"].payload.next_seq, 1, "claim reserves durable next_seq = last+1")
assert_eq(#publish_calls, publish_before_add + 1, "claim publishes one membership upsert")
assert_eq(publish_calls[#publish_calls].type, "entity_upsert", "claim frame is entity_upsert")
assert_eq(publish_calls[#publish_calls].entity_type, "botster-workspaces.membership", "claim frame family")
assert_eq(publish_calls[#publish_calls].snapshot_seq, 1, "claim uses reserved sequence 1")
assert_eq(publish_calls[#publish_calls].id, session_one, "claim frame id is session_uuid")
assert_eq(publish_calls[#publish_calls].entity.workspace_id, renamed.workspace.id, "claim entity owner")

local publish_before_idempotent = #publish_calls
local batch_before_idempotent = batch_calls
local idempotent_add = add_session({ workspace_id = renamed.workspace.id, session_id = session_one })
assert_eq(idempotent_add.ok, true, "same-workspace claim is idempotent success")
assert_eq(idempotent_add.idempotent, true, "same-workspace claim reports idempotent")
assert_eq(#idempotent_add.workspace.session_refs, 1, "idempotent claim does not duplicate session_refs")
assert_eq(batch_calls, batch_before_idempotent, "pure idempotent claim does not batch")
assert_eq(#publish_calls, publish_before_idempotent, "pure idempotent claim publishes nothing")

local publish_before_conflict = #publish_calls
local duplicate_add = add_session({ workspace_id = second.workspace.id, session_id = session_one })
assert_eq(duplicate_add.error.code, "session_already_owned", "add rejects another owner")
assert_eq(duplicate_add.owner_workspace_id, renamed.workspace.id, "duplicate identifies current owner")
assert_eq(#publish_calls, publish_before_conflict, "conflict loser publishes no false state")
local invalid_session = add_session({ workspace_id = second.workspace.id, session_id = "not-a-uuid" })
assert_eq(invalid_session.error.code, "validation_failed", "membership requires canonical UUID")
local short_uuid = add_session({ workspace_id = second.workspace.id, session_id = "1-2-3-4-5" })
assert_eq(short_uuid.error.code, "validation_failed", "membership rejects non-canonical UUID group lengths")

local added_second = add_session({ workspace_id = renamed.workspace.id, session_id = session_two })
assert_eq(added_second.ok, true, "second reference adds")
assert_eq(database["membership_entity_seq"].payload.next_seq, 2, "second claim advances next_seq to 2")
assert_eq(publish_calls[#publish_calls].snapshot_seq, 2, "second claim uses sequence 2")

local before_move = batch_calls
local publish_before_move = #publish_calls
local moved = move_session({ destination_workspace_id = second.workspace.id, session_id = session_one })
assert_eq(moved.ok, true, "explicit move succeeds")
assert_eq(batch_calls, before_move + 1, "move persists source and destination once")
assert_eq(#moved.source.session_refs, 1, "move removes source membership")
assert_eq(moved.destination.session_refs[1], session_one, "move inserts destination membership")
assert_eq(
  database["membership:" .. session_one].payload.workspace_id,
  second.workspace.id,
  "move updates membership index owner"
)
assert_eq(#publish_calls, publish_before_move + 1, "move publishes exactly one upsert")
assert_eq(publish_calls[#publish_calls].type, "entity_upsert", "move frame is single upsert not remove")
assert_eq(publish_calls[#publish_calls].entity.workspace_id, second.workspace.id, "move upsert destination")
assert_eq(publish_calls[#publish_calls].snapshot_seq, 3, "move uses next reserved sequence")
assert_eq(database["membership_entity_seq"].payload.next_seq, 3, "move advances counter by 1")

local before_remove = batch_calls
local publish_before_remove = #publish_calls
local removed = remove_session({ workspace_id = renamed.workspace.id, session_id = session_two })
assert_eq(removed.ok, true, "remove membership succeeds")
assert_eq(batch_calls, before_remove + 1, "remove persists once")
assert_eq(#removed.workspace.session_refs, 0, "remove changes grouping only")
assert_eq(database["membership:" .. session_two], nil, "remove deletes membership index key")
assert_eq(#publish_calls, publish_before_remove + 1, "remove publishes one frame")
assert_eq(publish_calls[#publish_calls].type, "entity_remove", "remove frame is entity_remove")
assert_eq(publish_calls[#publish_calls].id, session_two, "remove frame id is session_uuid")
assert_eq(publish_calls[#publish_calls].snapshot_seq, 4, "remove uses next reserved sequence")

local restart_spec = dofile("plugin.lua")
local restarted = tool(restart_spec, "botster_workspaces.list")({})
assert_eq(#restarted.workspaces, 2, "restart preserves workspace state")
assert_eq(restarted.workspaces[2].session_refs[1], session_one, "restart preserves moved membership")

local spawn_before = show({ id = renamed.workspace.id })
local spawn_result = spawn({
  workspace_id = renamed.workspace.id,
  target_id = "tgt_git",
  branch = "feature/contextual-workspaces",
  session_type_id = "acceptance-package/implement",
  prompt = "Implement this ticket",
  ticket_id = "ticket-example",
})
local persisted_spawn_uuid = spawn_result.session_id
assert_eq(spawn_result.ok, true, "atomic Hub spawn succeeds")
assert_eq(spawn_result.session_id, next_spawn_uuid, "only returned Hub UUID is recorded")
assert_eq(#spawn_result.workspace.session_refs, #spawn_before.workspace.session_refs + 1, "spawn appends one membership")
assert_eq(spawn_result.workspace.session_refs[#spawn_result.workspace.session_refs], next_spawn_uuid, "spawn persists returned UUID")
local spawn_request = spawn_calls[#spawn_calls]
assert_keys(
  spawn_request,
  { "target_id", "branch", "session_type_id", "context" },
  "managed spawn request carries the exact protocol-6 field set"
)
assert_eq(spawn_request.target_id, "tgt_git", "spawn sends semantic target")
assert_eq(spawn_request.branch, "feature/contextual-workspaces", "spawn sends branch")
assert_eq(
  spawn_request.session_type_id,
  "acceptance-package/implement",
  "spawn sends the fully qualified effective session type unchanged"
)
assert_eq(spawn_request.template_id, nil, "spawn never sends the superseded request field") -- cold-cut negative control
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
  session_type_id = "acceptance-package/implement",
  session_id = "44444444-4444-4444-8444-444444444444",
})
assert_eq(caller_id_rejected.error.code, "unknown_field", "spawn rejects caller session id")

-- The superseded request field is rejected before any Hub capability call and
-- before any membership write; it is never translated.
local spawn_calls_before_superseded = #spawn_calls
local membership_before_superseded = show({ id = renamed.workspace.id }).workspace.session_refs
local superseded_field_rejected = spawn({
  workspace_id = renamed.workspace.id,
  target_id = "tgt_git",
  branch = "superseded-field",
  template_id = "acceptance-package/implement", -- cold-cut negative control
})
assert_eq(superseded_field_rejected.ok, false, "spawn rejects the superseded request field")
assert_eq(superseded_field_rejected.error.code, "unknown_field", "superseded spawn field is typed unknown_field")
assert_eq(superseded_field_rejected.fields[1], "template_id", "rejection names the field") -- cold-cut negative control
assert_eq(#spawn_calls, spawn_calls_before_superseded, "superseded spawn field never reaches the Hub capability")
assert_eq(
  table.concat(show({ id = renamed.workspace.id }).workspace.session_refs, ","),
  table.concat(membership_before_superseded, ","),
  "superseded spawn field never mutates membership"
)

local missing_session_type = spawn({
  workspace_id = renamed.workspace.id,
  target_id = "tgt_git",
  branch = "missing-session-type",
})
assert_eq(missing_session_type.error.code, "validation_failed", "spawn requires a session type")
assert_eq(missing_session_type.fields[1], "session_type_id", "missing session type names the current field")

spawn_mode = "reject"
local membership_before_reject = show({ id = renamed.workspace.id }).workspace.session_refs
for _, collision in ipairs({
  { kind = "branch_in_use", message = "branch is already checked out", branch = "branch-conflict" },
  { kind = "path_collision", message = "managed path already exists", branch = "path-conflict" },
}) do
  spawn_rejection_kind = collision.kind
  spawn_rejection_message = collision.message
  local rejected_spawn = spawn({
    workspace_id = renamed.workspace.id,
    target_id = "tgt_git",
    branch = collision.branch,
    session_type_id = "acceptance-package/implement",
  })
  assert_eq(rejected_spawn.error.code, collision.kind, "typed Hub rejection kind is preserved")
  assert_eq(rejected_spawn.error.message, collision.message, "typed Hub rejection message is preserved")
  local membership_after_reject = show({ id = renamed.workspace.id }).workspace.session_refs
  assert_eq(#membership_after_reject, #membership_before_reject, "Hub rejection preserves membership count")
  assert_eq(
    table.concat(membership_after_reject, ","),
    table.concat(membership_before_reject, ","),
    "Hub rejection preserves membership content"
  )
end

spawn_rejection_kind = nil
spawn_rejection_message = "untyped rejection"
local untyped_rejection = spawn({
  workspace_id = renamed.workspace.id,
  target_id = "tgt_git",
  branch = "untyped-rejection",
  session_type_id = "acceptance-package/implement",
})
assert_eq(untyped_rejection.error.code, "hub_spawn_rejected", "untyped Hub rejection retains fallback")
assert_eq(untyped_rejection.error.message, spawn_rejection_message, "untyped Hub rejection retains message")
assert_eq(
  table.concat(show({ id = renamed.workspace.id }).workspace.session_refs, ","),
  table.concat(membership_before_reject, ","),
  "untyped Hub rejection records nothing"
)

spawn_mode = "throw"
local thrown_spawn = spawn({
  workspace_id = renamed.workspace.id,
  target_id = "tgt_git",
  branch = "worker-error",
  session_type_id = "acceptance-package/implement",
})
assert_eq(thrown_spawn.error.code, "hub_spawn_failed", "worker error is typed")
assert_eq(#show({ id = renamed.workspace.id }).workspace.session_refs, #membership_before_reject, "worker error records nothing")

spawn_mode = "success"
next_spawn_uuid = "55555555-5555-4555-8555-555555555555"
fail_next_batch = true
local publish_before_persist_fail = #publish_calls
local persist_failed_spawn = spawn({
  workspace_id = renamed.workspace.id,
  target_id = "tgt_git",
  branch = "persistence-failure",
  session_type_id = "acceptance-package/review",
})
assert_eq(persist_failed_spawn.error.code, "persist_failed", "post-spawn persistence failure is explicit")
assert_eq(persist_failed_spawn.spawned_session_id, next_spawn_uuid, "exception exposes ungrouped spawned session")
assert_eq(persist_failed_spawn.membership_recorded, false, "exception never claims membership")
assert_eq(#show({ id = renamed.workspace.id }).workspace.session_refs, #membership_before_reject, "failed persistence does not mutate durable membership")
assert_eq(#publish_calls, publish_before_persist_fail, "failed batch publishes no membership frames")

local entity_rows = snapshot({})
assert_eq(entity_rows.entity_family, "botster-workspaces.workspace", "entity family is plugin-namespaced")
assert_eq(#entity_rows.rows, 2, "entity snapshot contains current records")
assert_keys(
  entity_rows.rows[1],
  { "id", "name", "session_refs", "session_count", "created_at", "updated_at", "entity_family" },
  "entity row contains grouping read model only"
)

local session_type_calls_before_surface = #session_type_list_calls
local surface = handler(spec, "workspaces_surface")({})
assert_eq(
  #session_type_list_calls,
  session_type_calls_before_surface + 2,
  "one surface render lists session types once per enabled Git target"
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
  if group == "indeterminate" then
    local subtitle = find_node(
      binding.item_template,
      "botster-workspaces-session-subtitle-" .. group .. "-" .. renamed.workspace.id .. "-" .. persisted_spawn_uuid
    )
    assert_true(subtitle, "indeterminate row states its uncertain lifecycle classification")
    assert_eq(subtitle.props.text, "Lifecycle status is uncertain", "indeterminate row remains legible downstream")
  end
end
for group, presentation in pairs({
  current = { title = "Current", aria_label = "Current workspace sessions" },
  ended = { title = "Ended", aria_label = "Ended workspace sessions" },
  unavailable = {
    title = "Unavailable / uncertain",
    aria_label = "Unavailable or uncertain workspace sessions",
  },
}) do
  local section = find_node(surface, "botster-workspaces-sessions-" .. group .. "-" .. renamed.workspace.id)
  assert_true(section, group .. " lifecycle section is present")
  assert_eq(section.props.title, presentation.title, group .. " lifecycle heading uses owner product copy")
  local list = find_node(surface, "botster-workspaces-session-list-" .. group .. "-" .. renamed.workspace.id)
  assert_true(list, group .. " lifecycle list is present")
  assert_eq(list.props.aria_label, presentation.aria_label, group .. " lifecycle list has an explicit accessible label")
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
assert_true(absence_binding.empty_template, "absence projection authors an absent-reference template")
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

local spawn_buttons = {}
collect_action_nodes(rerendered, "botster_workspaces.open_spawn", spawn_buttons)
assert_eq(#spawn_buttons, 1, "selected detail exposes exactly one semantic Spawn opener")
local spawn_button = spawn_buttons[1]
if os.getenv("BOTSTER_WORKSPACES_TEST_REVERT_SPAWN_ACTION") == "1" then
  spawn_button.props.action.id = "botster_workspaces.open"
end
assert_eq(spawn_button.id, "botster-workspaces-spawn-" .. renamed.workspace.id, "Spawn keeps its authored node id")
assert_eq(spawn_button.props.label, "Spawn", "Spawn keeps visible product copy")
assert_eq(spawn_button.props.action.id, "botster_workspaces.open_spawn", "Spawn exposes semantic action identity")
assert_true(spawn_button.props.action.id ~= "botster_workspaces.open", "Spawn no longer advertises the generic opener")
assert_eq(spawn_button.props.action.payload.selected_workspace, renamed.workspace.id, "Spawn payload keeps workspace identity")
assert_eq(
  spawn_button.props.action.payload.dialog,
  "spawn-target:" .. renamed.workspace.id,
  "Spawn payload keeps target-first presentation"
)
if os.getenv("BOTSTER_WORKSPACES_TEST_OMIT_SPAWN_HANDLER") == "1" then
  for index, candidate in ipairs(spec.handlers) do
    if candidate.id == "open_spawn_presentation_action" then
      table.remove(spec.handlers, index)
      break
    end
  end
end
local open_spawn_handler = handler(spec, "open_spawn_presentation_action")
local open_spawn_arguments = action_arguments(spawn_button.props.action, "request-open-spawn")
open_spawn_arguments.node_id = spawn_button.id
if os.getenv("BOTSTER_WORKSPACES_TEST_HARDCODE_SPAWN_ACTION") == "1" then
  open_spawn_arguments.action_id = "botster_workspaces.open"
end
local open_spawn = open_spawn_handler(open_spawn_arguments)
assert_eq(open_spawn.action_id, spawn_button.props.action.id, "Spawn result echoes the read-back action id")
assert_eq(open_spawn.node_id, spawn_button.id, "Spawn result echoes the read-back node id")
apply_presentation(presentation_state, open_spawn)
local target_dialog = materialize(surface, presentation_state)
local target_form = find_node(target_dialog, "botster-workspaces-spawn-target-form-" .. renamed.workspace.id)
assert_true(target_form, "Spawn opens target-first dialog")
local target_select = find_node(target_form, "botster-workspaces-spawn-target")
assert_eq(#target_select.slots.options, 2, "spawn point projection includes enabled Git targets only")
assert_eq(target_select.slots.options[1].props.value, "tgt_git", "spawn point uses Hub target id")

presentation_state["workspace-dialog"] = "spawn:" .. renamed.workspace.id .. ":tgt_empty"
local empty_session_types_dialog = materialize(surface, presentation_state)
assert_true(
  find_node(empty_session_types_dialog, "botster-workspaces-spawn-empty-" .. renamed.workspace.id .. "-tgt_empty"),
  "target with no effective session types renders an explicit empty state"
)
fail_session_type_list_for = "tgt_empty"
local failed_projection_surface = handler(spec, "workspaces_surface")({})
local failed_projection_dialog = materialize(failed_projection_surface, presentation_state)
assert_true(
  find_node(failed_projection_dialog, "botster-workspaces-spawn-error-" .. renamed.workspace.id .. "-tgt_empty"),
  "session-type projection failure renders an explicit unavailable state"
)
fail_session_type_list_for = nil
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
assert_eq(spawn_form.children[4].id, "botster-workspaces-spawn-template", "session type select keeps its authored node id")
assert_eq(spawn_form.children[4].props.name, "session_type_id", "session type select carries the current field name")
assert_eq(#spawn_form.children[4].slots.options, 2, "session type options are target-filtered")
assert_eq(
  spawn_form.children[4].slots.options[1].props.value,
  "acceptance-package/implement",
  "session type option carries the fully qualified Hub id, not the bare id"
)
for _, request in ipairs(session_type_list_calls) do
  assert_true(
    request.target_id == "tgt_git" or request.target_id == "tgt_empty",
    "every session-type projection is scoped to an enabled Git target"
  )
end

local spawn_action_calls_before = #spawn_calls
local spawned_action = handler(spec, "spawn_session_action")({
  request_id = "request-spawn-session",
  surface_id = "workspaces",
  action_id = spawn_form.props.action.id,
  node_id = spawn_form.id,
  payload = spawn_form.props.action.payload,
  values = {
    ["botster-workspaces-spawn-target-id"] = "tgt_git",
    ["botster-workspaces-spawn-workspace-id"] = renamed.workspace.id,
    ["botster-workspaces-spawn-branch"] = "action-adapter",
    ["botster-workspaces-spawn-template"] = "acceptance-package/review",
  },
})
assert_eq(spawned_action.state, "accepted", "spawn action submits through the authored form nodes")
assert_eq(#spawn_calls, spawn_action_calls_before + 1, "spawn action issues exactly one Hub capability call")
assert_eq(
  spawn_calls[#spawn_calls].session_type_id,
  "acceptance-package/review",
  "spawn action forwards the selected session type unchanged"
)

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
assert_eq(database["membership:" .. session_to_preserve], nil, "delete clears membership index keys")
assert_eq(show({ id = delete_target.workspace.id }).error.code, "workspace_not_found", "grouping record is physically removed")
assert_eq(#spawn_calls, spawn_call_count, "delete never invokes Hub spawn or lifecycle mutation")
assert_eq(create({ name = "Disposable grouping" }).ok, true, "delete releases name immediately")



local function run_membership_producer_matrix_tests()
  -- Membership producer matrix needs a valid workspace_state after action fixtures.
  database.workspace_state = {
    schema_version = 1,
    revision = (database.workspace_state and database.workspace_state.revision) or 1,
    payload = {
      next_workspace = 100,
      next_timestamp = 100,
      workspaces = {},
    },
  }

  local multi_ws = create({ name = "Multi delete source" })
  assert_eq(multi_ws.ok, true, "multi-delete workspace creates")
  local multi_a = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
  local multi_b = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
  assert_eq(add_session({ workspace_id = multi_ws.workspace.id, session_id = multi_b }).ok, true, "multi seed b")
  assert_eq(add_session({ workspace_id = multi_ws.workspace.id, session_id = multi_a }).ok, true, "multi seed a")
  local seq_before_delete = database["membership_entity_seq"].payload.next_seq
  local publish_before_delete = #publish_calls
  local batch_before_delete = batch_calls
  local deleted_multi = delete({ id = multi_ws.workspace.id })
  assert_eq(deleted_multi.ok, true, "multi-membership delete succeeds")
  assert_eq(batch_calls, batch_before_delete + 1, "multi-delete uses one batch")
  assert_eq(database["membership:" .. multi_a], nil, "multi-delete clears membership a")
  assert_eq(database["membership:" .. multi_b], nil, "multi-delete clears membership b")
  assert_eq(
    database["membership_entity_seq"].payload.next_seq,
    seq_before_delete + 2,
    "multi-delete range-reserves N=2 consecutive seqs"
  )
  assert_eq(#publish_calls, publish_before_delete + 2, "multi-delete publishes N remove frames")
  local remove_a = publish_calls[publish_before_delete + 1]
  local remove_b = publish_calls[publish_before_delete + 2]
  assert_eq(remove_a.type, "entity_remove", "first multi-delete frame is remove")
  assert_eq(remove_b.type, "entity_remove", "second multi-delete frame is remove")
  assert_eq(remove_a.id, multi_a, "multi-delete removes in ascending session_uuid order first")
  assert_eq(remove_b.id, multi_b, "multi-delete removes in ascending session_uuid order second")
  assert_eq(remove_a.snapshot_seq, seq_before_delete + 1, "multi-delete first reserved seq")
  assert_eq(remove_b.snapshot_seq, seq_before_delete + 2, "multi-delete second reserved seq")

  local silence_ws = create({ name = "Batch silence" })
  assert_eq(add_session({
    workspace_id = silence_ws.workspace.id,
    session_id = "cccccccc-cccc-4ccc-8ccc-cccccccccccc",
  }).ok, true, "silence seed claim")
  local seq_before_fail = database["membership_entity_seq"].payload.next_seq
  local publish_before_fail = #publish_calls
  fail_next_batch = true
  local failed_remove = remove_session({
    workspace_id = silence_ws.workspace.id,
    session_id = "cccccccc-cccc-4ccc-8ccc-cccccccccccc",
  })
  assert_eq(failed_remove.ok, false, "failed batch remove fails closed")
  assert_eq(failed_remove.error.code, "persist_failed", "failed batch is typed persist_failed")
  assert_eq(database["membership_entity_seq"].payload.next_seq, seq_before_fail, "failed batch does not advance seq")
  assert_eq(#publish_calls, publish_before_fail, "failed batch publishes no frames")
  assert_true(
    database["membership:cccccccc-cccc-4ccc-8ccc-cccccccccccc"] ~= nil,
    "failed batch leaves membership key intact"
  )

  local cas_ws_a = create({ name = "CAS owner A" })
  local cas_ws_b = create({ name = "CAS owner B" })
  local cas_session = "dddddddd-dddd-4ddd-8ddd-dddddddddddd"
  local seq_before_cas = database["membership_entity_seq"].payload.next_seq
  local publish_before_cas = #publish_calls
  batch_conflict_once = true
  local cas_first = add_session({ workspace_id = cas_ws_a.workspace.id, session_id = cas_session })
  assert_eq(cas_first.ok, true, "CAS retry claim eventually succeeds")
  assert_eq(database["membership:" .. cas_session].payload.workspace_id, cas_ws_a.workspace.id, "CAS winner owns session")
  assert_eq(database["membership_entity_seq"].payload.next_seq, seq_before_cas + 1, "CAS winner advances seq once")
  assert_eq(#publish_calls, publish_before_cas + 1, "CAS winner publishes exactly once")
  local cas_loser = add_session({ workspace_id = cas_ws_b.workspace.id, session_id = cas_session })
  assert_eq(cas_loser.error.code, "session_already_owned", "CAS loser is session_already_owned")
  assert_eq(#publish_calls, publish_before_cas + 1, "CAS loser publishes nothing")

  local membership_provider = registered_handler(spec, "membership_entity_provider")
  assert_eq(membership_provider.kind, "entity_provider", "membership entity_provider is registered")
  assert_eq(membership_provider.descriptor_id, "botster-workspaces.membership", "membership provider family is exact")
  assert_eq(membership_provider.descriptor.entity_type, "botster-workspaces.membership", "membership descriptor entity_type matches")
  assert_eq(membership_provider.descriptor.id_field, "id", "membership provider uses id field")
  local seq_before_provider = database["membership_entity_seq"].payload.next_seq
  local provider_snapshot = membership_provider.call({ subscription_id = "test-sub" })
  assert_eq(provider_snapshot.type, "entity_snapshot", "membership provider returns entity_snapshot")
  assert_eq(provider_snapshot.entity_type, "botster-workspaces.membership", "membership snapshot family matches")
  assert_eq(provider_snapshot.snapshot_seq, seq_before_provider + 1, "provider allocates one durable seq")
  assert_eq(database["membership_entity_seq"].payload.next_seq, seq_before_provider + 1, "provider CAS advances next_seq")
  assert_true(#provider_snapshot.items >= 1, "membership snapshot includes durable memberships")
  for _, item in ipairs(provider_snapshot.items) do
    assert_keys(item, { "id", "session_uuid", "workspace_id" }, "membership row shape is exact")
    assert_eq(item.id, item.session_uuid, "membership id equals session_uuid")
    assert_eq(item.lifecycle, nil, "membership snapshot omits Hub lifecycle")
    assert_eq(item.label, nil, "membership snapshot omits Hub label")
    assert_eq(item.spawn_point, nil, "membership snapshot omits Hub spawn_point")
  end

  local durable_seq_after_provider = database["membership_entity_seq"].payload.next_seq
  local reloaded_spec = dofile("plugin.lua")
  local reloaded_add = tool(reloaded_spec, "botster_workspaces.add_session")
  local reloaded_ws = tool(reloaded_spec, "botster_workspaces.create")({ name = "Post reload" })
  local reload_session = "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee"
  local publish_before_reload = #publish_calls
  local reloaded_claim = reloaded_add({
    workspace_id = reloaded_ws.workspace.id,
    session_id = reload_session,
  })
  assert_eq(reloaded_claim.ok, true, "first post-reload claim succeeds")
  assert_eq(
    database["membership_entity_seq"].payload.next_seq,
    durable_seq_after_provider + 1,
    "post-reload claim continues durable sequence"
  )
  assert_eq(#publish_calls, publish_before_reload + 1, "post-reload claim publishes once")
  assert_eq(
    publish_calls[#publish_calls].snapshot_seq,
    durable_seq_after_provider + 1,
    "post-reload publish uses next durable seq without stale/duplicate"
  )
  assert_eq(publish_calls[#publish_calls].id, reload_session, "post-reload publish id matches claim")
end

local function run_review_rework_tests()
  database.workspace_state = {
    schema_version = 1,
    revision = (database.workspace_state and database.workspace_state.revision) or 1,
    payload = {
      next_workspace = 200,
      next_timestamp = 200,
      workspaces = {},
    },
  }

  local fence_ws = create({ name = "Provider fence workspace" })
  assert_eq(fence_ws.ok, true, "provider fence workspace creates")
  local fence_session = "f1111111-1111-4111-8111-111111111111"
  assert_eq(add_session({
    workspace_id = fence_ws.workspace.id,
    session_id = fence_session,
  }).ok, true, "provider fence seed claim")
  local seq_before_fence = database["membership_entity_seq"].payload.next_seq
  local fence_list_hits = 0
  local original_list = botster.capabilities.plugin_db.list
  botster.capabilities.plugin_db.list = function(request)
    if request.prefix == "membership:" then
      fence_list_hits = fence_list_hits + 1
      if fence_list_hits == 1 then
        local current = database["membership_entity_seq"]
        local rev = current and (current.revision or 1) or 0
        local last = current and current.payload and current.payload.next_seq or 0
        apply_set({
          key = "membership_entity_seq",
          schema_version = 1,
          expected_revision = rev,
          payload = { next_seq = last + 1 },
        })
      end
    end
    return original_list(request)
  end
  local fenced_provider = registered_handler(spec, "membership_entity_provider")
  local fenced_snapshot = fenced_provider.call({ subscription_id = "fence-sub" })
  botster.capabilities.plugin_db.list = original_list
  assert_eq(fenced_snapshot.type, "entity_snapshot", "fenced provider returns snapshot after concurrent advance")
  assert_true(fence_list_hits >= 2, "provider retried list after concurrent sequence advance")
  assert_eq(
    fenced_snapshot.snapshot_seq,
    database["membership_entity_seq"].payload.next_seq,
    "fenced provider snapshot_seq matches durable floor after retry"
  )
  assert_true(
    fenced_snapshot.snapshot_seq > seq_before_fence,
    "fenced provider still advances past pre-interleave floor"
  )

  -- Clear membership keys so list_membership_records uses the workspace_state fallback.
  for key in pairs(database) do
    if type(key) == "string" and key:sub(1, #"membership:") == "membership:" then
      database[key] = nil
    end
  end
  local preindex_session = "f2222222-2222-4222-8222-222222222222"
  local preindex_ws = create({ name = "Preindex remove" })
  assert_eq(preindex_ws.ok, true, "preindex workspace creates")
  local state_record = database.workspace_state
  local payload = copy(state_record.payload)
  for _, workspace in ipairs(payload.workspaces) do
    if workspace.id == preindex_ws.workspace.id then
      workspace.session_refs = { preindex_session }
      workspace.updated_at = "plugin-clock-preindex"
    end
  end
  database.workspace_state = {
    schema_version = 1,
    revision = state_record.revision or 1,
    payload = payload,
  }
  assert_eq(database["membership:" .. preindex_session], nil, "preindex fixture has no membership key")
  local preindex_provider = registered_handler(spec, "membership_entity_provider")
  local preindex_snap = preindex_provider.call({ subscription_id = "preindex-sub" })
  local saw_preindex = false
  for _, item in ipairs(preindex_snap.items or {}) do
    if item.session_uuid == preindex_session then
      saw_preindex = true
    end
  end
  assert_true(saw_preindex, "preindex fallback surfaces session_ref in membership snapshot")
  local publish_before_preindex_remove = #publish_calls
  local preindex_remove = remove_session({
    workspace_id = preindex_ws.workspace.id,
    session_id = preindex_session,
  })
  assert_eq(preindex_remove.ok, true, "preindex remove succeeds without membership key")
  assert_eq(#publish_calls, publish_before_preindex_remove + 1, "preindex remove publishes entity_remove")
  assert_eq(publish_calls[#publish_calls].type, "entity_remove", "preindex remove frame type")
  assert_eq(publish_calls[#publish_calls].id, preindex_session, "preindex remove frame id")

  local multi_pre_a = "f3333333-3333-4333-8333-333333333333"
  local multi_pre_b = "f4444444-4444-4444-8444-444444444444"
  local multi_pre_ws = create({ name = "Preindex multi delete" })
  local multi_state = database.workspace_state
  local multi_payload = copy(multi_state.payload)
  for _, workspace in ipairs(multi_payload.workspaces) do
    if workspace.id == multi_pre_ws.workspace.id then
      workspace.session_refs = { multi_pre_b, multi_pre_a }
    end
  end
  database.workspace_state = {
    schema_version = 1,
    revision = multi_state.revision or 1,
    payload = multi_payload,
  }
  local publish_before_multi_pre = #publish_calls
  local multi_pre_delete = delete({ id = multi_pre_ws.workspace.id })
  assert_eq(multi_pre_delete.ok, true, "preindex multi-delete succeeds")
  assert_eq(#publish_calls, publish_before_multi_pre + 2, "preindex multi-delete publishes two removes")
  assert_eq(publish_calls[publish_before_multi_pre + 1].id, multi_pre_a, "preindex multi-delete order first")
  assert_eq(publish_calls[publish_before_multi_pre + 2].id, multi_pre_b, "preindex multi-delete order second")

  local retry_ws = create({ name = "Publish retry" })
  local retry_session = "f5555555-5555-4555-8555-555555555555"
  local original_publish = botster.entity_publish
  local publish_attempts = 0
  botster.entity_publish = function(frame)
    publish_attempts = publish_attempts + 1
    if publish_attempts == 1 then
      return { ok = false, status = "stale_sequence", last_accepted_seq = 0, high_water_seq = 0 }
    end
    return original_publish(frame)
  end
  local retry_claim = add_session({
    workspace_id = retry_ws.workspace.id,
    session_id = retry_session,
  })
  botster.entity_publish = original_publish
  assert_eq(retry_claim.ok, true, "claim succeeds even when first publish is rejected")
  assert_eq(publish_attempts, 2, "rejected publish is retried once")
  assert_eq(retry_claim.membership_delivery, "published", "retry recovers delivery")
  assert_eq(retry_claim.membership_publish[1].status, "accepted", "retry result is accepted")

  local fail_ws = create({ name = "Publish degraded" })
  local fail_session = "f6666666-6666-4666-8666-666666666666"
  publish_attempts = 0
  botster.entity_publish = function(_frame)
    publish_attempts = publish_attempts + 1
    return { ok = false, status = "stale_sequence", last_accepted_seq = 0, high_water_seq = 0 }
  end
  local degraded_claim = add_session({
    workspace_id = fail_ws.workspace.id,
    session_id = fail_session,
  })
  botster.entity_publish = original_publish
  assert_eq(degraded_claim.ok, true, "durable claim still succeeds when publish remains rejected")
  assert_eq(publish_attempts, 2, "degraded path still retries once")
  assert_eq(degraded_claim.membership_delivery, "degraded", "unrecovered publish reports degraded delivery")
  assert_true(database["membership:" .. fail_session] ~= nil, "degraded path keeps membership key committed")
end

run_membership_producer_matrix_tests()
run_review_rework_tests()


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
  local scale_session_refs = {}
  for index = 1, 16 do
    scale_session_refs[#scale_session_refs + 1] = string.format("90000000-0000-4000-8000-%012d", index)
  end
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
  local populated_surface = handler(spec, "workspaces_surface")({})
  database.workspace_state.payload.workspaces = {
    {
      id = "ws_contract_scale",
      name = "Contract scale",
      session_refs = scale_session_refs,
      created_at = "plugin-clock-000003",
      updated_at = "plugin-clock-000003",
    },
  }
  local scale_contract_surface = handler(spec, "workspaces_surface")({})
  local file = assert(io.open(output_path, "w"))
  file:write(json_encode({
    empty_surface,
    populated_surface,
    scale_contract_surface,
  }))
  file:write("\n")
  file:close()
end

assert_eq(registered_handler(spec, "workspaces_surface").kind, "surface_route", "production surface handler is registered")
assert_eq(
  registered_handler(spec, "open_spawn_presentation_action").descriptor_id,
  "botster_workspaces.open_spawn",
  "semantic Spawn opener is registered"
)
assert_eq(registered_handler(spec, "spawn_session_action").kind, "ui_action", "production spawn action is registered")

if os.getenv("BOTSTER_WORKSPACES_INJECT_FAILURE") == "1" then
  error("deliberate harness failure")
end


print("test/plugin_runtime_test.lua: ok")
