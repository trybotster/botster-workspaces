# botster-workspaces

First-party Botster plugin for contextual session grouping.

## Contextual session grouping

A workspace is a user-named grouping of Hub session identities. Its persisted
record is exactly:

```text
{ id, name, session_refs, created_at, updated_at }
```

The package owns names, grouping membership, and the workspace workflow. The
Hub remains authoritative for spawn points, effective session types, managed
Git worktrees, session IDs, processes, terminals, and lifecycle.

The public plugin tools are:

- `botster_workspaces.create`
- `botster_workspaces.list`
- `botster_workspaces.show`
- `botster_workspaces.rename`
- `botster_workspaces.delete`
- `botster_workspaces.add_session`
- `botster_workspaces.move_session`
- `botster_workspaces.remove_session`
- `botster_workspaces.spawn`
- `botster_workspaces.entity_snapshot`

Agents use three tools with agent-facing argument names. Each one runs the same
code as the matching `botster_workspaces.*` tool:

- `list_workspaces`
- `rename_workspace` (`workspace_id`, `new_name`)
- `move_agent_workspace` (`session_id`, `workspace_id`): moves a grouped
  session, or adds an ungrouped one

A session reference is `{ hub_id, session_id }`. Every tool that takes a
session accepts an optional `hub_id`, which defaults to the local hub. Another
hub is refused with `remote_hub_unsupported` until hub routing exists.

When botster-orchestrator spawns a session with a `workspace_id`, it emits
`botster-orchestrator.session_spawned` `{ hub_id, session_id, workspace_id }`.
This package subscribes and adds the session to that workspace. A failed claim
leaves the session ungrouped and logs a warning.

One session reference belongs to at most one workspace, enforced by durable
`membership:<hub_id>/<session_id>` keys and published through the
`botster-workspaces.membership` entity family after committed claims and
removals. Add rejects an existing owner; move removes the source membership and adds the destination membership
in one `plugin_db` write; remove changes only grouping. Deleting a workspace
removes only that grouping record. It never terminates a session or removes a
worktree, branch, or repository.

## Workspace app

The package declares one app surface and one navigation item, both named
`workspaces`. The stable Hub surface path is
`/packages/botster-workspaces/surfaces/workspaces`.

The host owns the page title and route chrome. The plugin renders one plain
content stack without a second **Workspaces** title or **Workspace actions**
toolbar. The initial index contains a contextual **New workspace** action,
workspace rows, and an empty state. The complete row opens its workspace, so
the list does not add a redundant **Open** button.

Forms are materialized only after an accepted plugin action sets scoped
client-local presentation state. Selecting a row reveals one detail section on
the same route and remains stable across rerenders.

The detail toolbar separates session actions from workspace management:

- **Spawn session** stays visible as the primary session action.
- **Add session** and **Move session** are secondary session actions.
- **Workspace settings** contains rename and delete controls.
- **Remove** removes a session from the workspace grouping.

The selected row renders the workspace name once. The detail starts with the
Sessions section. Compact groups show Current and Unavailable sessions.

**Add existing session** authors an Available sessions picker bound to Hub
`/session` through `entity_options`, excluding every session ID present in
`/botster-workspaces.membership`. Option labels prefer Hub `label` when present
and fall back to the Hub's `session_uuid` field; optional `lifecycle`, `lifecycle_class`,
`session_type_id`, and `spawn_point` fields are projected when present and never
copied into `plugin.db`. An always-visible advanced **Historical session ID**
field remains for sessions absent from current Hub entity state; when both
fields are set, the advanced value wins. Membership claim and remove still
publish live membership entity frames for open pickers.

Detail groups each stored reference as **Current** or **Unavailable** by binding
the stable surface tree directly to the Hub-owned `/session` entity family.
Snapshot, upsert, patch, and remove frames move rows without polling or an
imperative session-list refresh. A confirmed ended lifecycle removes the
workspace reference and membership key. Indeterminate and absent sessions stay
grouped because absence does not prove that a session ended. The package does
not persist or guess lifecycle truth.

Spawn is target-first and stays thin for the common case:

1. Choose a **Spawn point** (any enabled Hub target).
2. Choose a **Session type** (Hub-provided labels such as Agent, Shell, Custom,
   or package types).
3. For **Git** spawn points only, enter a **Branch** so Hub can create or reuse
   a managed worktree.
4. Optionally open **Optional context** for prompt and ticket.

The package lists every enabled spawn point, then asks the Hub for effective
session types for the selected target through `session_types.list`. It submits
the fully qualified `session_type_id` the Hub returned, unchanged. Non-Git
targets call `session_types.spawn`. Git targets call
`session_types.ensure_worktree_and_spawn` with the branch. After success it
records exactly the returned session ID; a rejection or worker error records
nothing. If the Hub spawn succeeds but the following grouping write fails, the
action reports the returned ungrouped session ID and does not claim membership.

Empty states cover missing spawn points and missing session types without
protocol jargon. Session-type presentation is Hub-owned: the package renders the
label and id it receives and does not own role, interaction, trait, lifecycle
taxonomy, source precedence, or editability.

The detail Spawn opener exposes `botster_workspaces.open_spawn` as its stable,
renderer-neutral consumer identity. Clients locate it from realized action
metadata and dispatch the exact action id, node id, and payload they received;
they do not parse the visible `Spawn` copy or synthesize its dynamic node id.

## Clean-start data

This is a cold replacement of the pre-release workspace product. The package
does not normalize or migrate old records. Existing pre-release users must stop
the old Hub and either:

1. start the current Hub with a new empty `--data-dir`; or
2. back up and explicitly discard the old disposable Hub data directory before
   reinstalling.

The package performs no automatic reset or deletion. Encountering an old
record returns the typed `legacy_workspace_schema` error with this clean-start
guidance.

## Local development

Use a fresh Hub data directory, isolated from any pre-release state:

```sh
tmp_data_dir="$(mktemp -d /tmp/botster-workspaces.XXXXXX)"

botster-hub packages install --data-dir "$tmp_data_dir" --path ../botster-workspaces
botster-hub packages enable --data-dir "$tmp_data_dir" botster-workspaces
botster-hub packages show --data-dir "$tmp_data_dir" botster-workspaces
botster-hub packages list --data-dir "$tmp_data_dir"
```

Run the repository checks:

```sh
script/test

BOTSTER_UI_CONTRACT_PATH=/path/to/botster-hub/crates/botster-ui-contract \
  script/validate_ui_node_contract
```

The second command validates the owner-authored tree against the exact Hub
`botster-ui-contract` artifact. There is no Core-backed fallback.

For real package behavior with a session worker, run the end-to-end specs
against a candidate Hub (see "Testing").

The Web and TUI clients prove their own workspaces flows from their own
repositories with this checkout (`npm run smoke:workspaces-lifecycle` in
`botster-web`, `script/test-live-hub workspaces lifecycle` in `botster-tui`).
This repository keeps no cross-repository acceptance harness.

See [docs/workspace-domain.md](docs/workspace-domain.md) and
[docs/capabilities.md](docs/capabilities.md) for the exact domain and authority
contracts.

## Testing

`script/test` checks the manifest, the contract fixture, and the docs. It then
runs the behaviour specs in `test/*_spec.lua` with the Botster plugin test kit,
which loads this package into a real Hub runtime (no API fakes):

```sh
cargo install --locked --git https://github.com/trybotster/botster-hub --rev 035fc2cd193f698c1a2eeb7025fcc3e2afbcaec7 botster-plugin-test-kit
BOTSTER_PLUGIN_TEST=botster-plugin-test script/test
```

That Hub commit (`botster.hub.identity()` and the kit are on it) is the one these specs were last run against. Raise the pin when a newer Hub commit passes.

The in-process kit starts no session worker. `script/test-e2e` runs
`test/e2e/*_spec.lua` against a real `botster-hub` process with a session
worker (`botster-plugin-test --e2e`), which proves a completed spawn. It needs
the candidate binaries that the Hub's own gate builds:

```sh
BOTSTER_HUB_BIN=... BOTSTER_SESSION_WORKER_BIN=... BOTSTER_CANDIDATE_MANIFEST=... \
  BOTSTER_PLUGIN_TEST=botster-plugin-test script/test-e2e
```
