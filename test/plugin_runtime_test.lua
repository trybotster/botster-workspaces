local database = {}
local published_snapshots = {}
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
    entities = {
      snapshot = function(payload)
        published_snapshots[#published_snapshots + 1] = copy(payload)
        return { ok = true }
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

local spec = dofile("plugin.lua")

assert_eq(#registrations, 1, "plugin registers once")
assert_true(tool(spec, "botster_workspaces.create"), "create tool is registered")
assert_true(tool(spec, "botster_workspaces.list"), "list tool is registered")
assert_true(tool(spec, "botster_workspaces.show"), "show tool is registered")
assert_true(tool(spec, "botster_workspaces.update"), "update tool is registered")
assert_true(tool(spec, "botster_workspaces.delete"), "delete tool is registered")
assert_true(tool(spec, "botster_workspaces.entity_snapshot"), "entity snapshot tool is registered")

local create = tool(spec, "botster_workspaces.create")
local list = tool(spec, "botster_workspaces.list")
local show = tool(spec, "botster_workspaces.show")
local update = tool(spec, "botster_workspaces.update")
local delete = tool(spec, "botster_workspaces.delete")
local snapshot = tool(spec, "botster_workspaces.entity_snapshot")

local missing = create({})
assert_eq(missing.ok, false, "create rejects missing required fields")
assert_eq(missing.error.code, "validation_failed", "missing fields returns validation_failed")

local created = create({
  name = "Product refactor",
  purpose = "Coordinate product refactor agents",
  local_repo_ref = repo_ref("repo_main", "Main application repo"),
  spawn_target_ref = spawn_target_ref("target_codex_local", "Codex local"),
  default_session_template_id = "template_codex_implement",
})
assert_eq(created.ok, true, "create succeeds")
assert_eq(created.workspace.status, "active", "create marks active")
assert_eq(created.workspace.session_group.workspace_id, created.workspace.id, "session group is workspace scoped")
assert_eq(#created.workspace.session_group.session_refs, 0, "create starts with no session refs")
assert_eq(created.entity.entity_family, "botster-workspaces.workspace", "entity family is correct")
assert_eq(created.entity.repo_label, "Main application repo", "entity exposes repo label")
assert_eq(created.entity.spawn_target_label, "Codex local", "entity exposes spawn target label")
assert_eq(created.entity.session_count, 0, "entity counts sessions")
assert_eq(#published_snapshots, 1, "create publishes entity snapshot")

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

local entity_rows = snapshot({})
assert_eq(entity_rows.ok, true, "entity snapshot succeeds")
assert_eq(entity_rows.entity_family, "botster-workspaces.workspace", "snapshot family")
assert_eq(#entity_rows.rows, 2, "snapshot includes active rows")

local deleted = delete({ id = created.workspace.id })
assert_eq(deleted.ok, true, "delete succeeds")
assert_eq(deleted.workspace.status, "deleted", "delete marks deleted")
assert_eq(#deleted.workspace.session_group.session_refs, 2, "delete preserves session references")

local active_after_delete = list({})
assert_eq(#active_after_delete.workspaces, 1, "deleted rows are excluded from default list")
assert_eq(active_after_delete.workspaces[1].id, second.workspace.id, "remaining active row is listed")

local recreated = create({
  name = "Product refactor",
  purpose = "Reuse name after deletion",
  local_repo_ref = repo_ref("repo_recreated", "Recreated repo"),
  spawn_target_ref = spawn_target_ref("target_codex_local", "Codex local"),
})
assert_eq(recreated.ok, true, "deleted names do not block new active workspace")

local restart_spec = dofile("plugin.lua")
local restart_list = tool(restart_spec, "botster_workspaces.list")({})
assert_eq(#restart_list.workspaces, 2, "state persists through plugin reload")

local app_surface = handler(spec, "workspaces_surface")({})
assert_eq(app_surface.id, "botster-workspaces-app", "app surface renders")
assert_eq(app_surface.children[1].props.source, "/botster-workspaces.workspace", "app surface binds entity family")
assert_eq(app_surface.children[1].item_template.props.title.path, "@/name", "app surface title is bound")

local settings_surface = handler(spec, "workspaces_settings_surface")({})
assert_eq(settings_surface.id, "botster-workspaces-settings", "settings surface renders")
assert_eq(settings_surface.children[2].props.source, "/botster-workspaces.workspace", "settings surface binds entity family")

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
