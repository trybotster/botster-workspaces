-- Shared helpers for the botster-workspaces kit specs.
local M = {}

M.MEMBERSHIP = "botster-workspaces.membership"

-- Calls a tool and returns the plugin's own result table. A Hub refusal of the
-- call itself fails the spec.
function M.call(t, p, name, args)
  local response = p:call_tool(name, args or {})
  t:ok(response.ok, name .. " was admitted by the Hub: " .. tostring(response.error and response.error.message))
  return response.result
end

function M.hub_id(t, p)
  local listed = M.call(t, p, "list_workspaces", {})
  t:ok(type(listed.hub_id) == "string", "list_workspaces returns hub_id")
  return listed.hub_id
end

function M.create(t, p, name)
  local created = M.call(t, p, "botster_workspaces.create", { name = name })
  t:eq(created.ok, true)
  return created.workspace.id
end

function M.ref(hub_id, session_id)
  return { hub_id = hub_id, session_id = session_id }
end

function M.key(hub_id, session_id)
  return "membership:" .. hub_id .. "/" .. session_id
end

-- A JSON array decodes to a table carrying mlua's array metatable; a JSON
-- object decodes to a plain table. Empty lists must cross as arrays.
function M.json_array(t, value, what)
  t:ok(type(value) == "table" and getmetatable(value) ~= nil, what .. " is a JSON array")
end

function M.workspace(t, p, id)
  local shown = M.call(t, p, "botster_workspaces.show", { id = id })
  t:eq(shown.ok, true)
  return shown.workspace
end

-- A fresh directory; a git target gets an initialized repository with one commit.
local function root_for(kind)
  local root = io.popen("mktemp -d"):read("*l")
  if kind == "git" then
    assert(os.execute("git -C '" .. root .. "' init --quiet && git -C '" .. root
      .. "' -c user.name=kit -c user.email=kit@localhost commit --quiet --allow-empty -m init"))
  end
  return root
end

-- Admits a spawn target through the Hub's own request.
function M.admit_target(t, id, label, kind)
  local response = t:request({
    type = "create_spawn_target",
    target_id = id,
    label = label,
    root = root_for(kind),
    enabled = true,
    kind = kind,
  })
  t:eq(response.ok, true)
end

return M
