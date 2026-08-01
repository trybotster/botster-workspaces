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
Git worktrees, session UUIDs, processes, terminals, and lifecycle.

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

One session UUID belongs to at most one workspace. Add rejects an existing
owner; move removes the source membership and adds the destination membership
in one `plugin_db` write; remove changes only grouping. Deleting a workspace
removes only that grouping record. It never terminates a session or removes a
worktree, branch, or repository.

## Workspace app

The package declares one app surface and one navigation item, both named
`workspaces`. The stable Hub surface path is
`/packages/botster-workspaces/surfaces/workspaces`.

The initial index contains a contextual **New workspace** action, workspace
rows, and an empty state. Forms are materialized only after an accepted plugin
action sets scoped client-local presentation state. Selecting a row reveals the
detail presentation on the same route and remains stable across rerenders.

Detail preserves every referenced session UUID and exposes:

- Spawn
- rename
- delete
- Add or move an existing session
- remove membership

Detail groups each stored reference as **Current**, **Ended**, or
**Unavailable / uncertain** by binding the stable surface tree directly to the
Hub-owned `/session` entity family. Snapshot, upsert, patch, and remove frames
therefore move rows without polling, an imperative session-list refresh, or a
surface rerender. Ended, indeterminate, and absent UUIDs remain deliberate
workspace history until the user explicitly moves or removes them. The package
does not persist, compute, or guess lifecycle truth.

Spawn is target-first. The package lists enabled Git spawn points, then asks
the Hub for effective session types for the selected target. It calls only
`session_templates.ensure_worktree_and_spawn`. After success it records exactly
the returned `result.session_id`; a rejection or worker error records nothing.
If the Hub spawn succeeds but the following grouping write fails, the action
reports the returned ungrouped UUID and does not claim membership.

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

For real package behavior, start a current Hub from a fresh data directory,
install and enable this checkout, then run:

```sh
script/hub_acceptance_smoke /path/to/current-hub.sock
```

That smoke crosses the registered package, plugin worker, atomic managed-Git
spawn, persistence/restart, canonical session-entity lifecycle reconciliation,
surface render, and non-destructive delete paths.

After the repository-documented consumer modes are available, run the
package-specific Web lifecycle smoke from `botster-web` with this checkout:

```sh
BOTSTER_HUB_BIN=/path/to/botster-hub \
BOTSTER_SESSION_WORKER_BIN=/path/to/botster-session-worker \
BOTSTER_WORKSPACES_PACKAGE_PATH="$PWD" \
  npm run smoke:workspaces-lifecycle
```

Run the corresponding documented Workspaces lifecycle mode from `botster-tui`
with the same Hub, worker, and package provenance. These modes must exercise
the real owner-authored tree through each generic renderer; repository-local
source or fixture inspection is not a substitute.

### Shared-stack acceptance inputs

The final browser/TUI acceptance profile uses one parent-owned Hub and one
fresh data directory. Before either consumer is launched, validate an explicit
input manifest:

```sh
script/test-hub-flow shared-stack validate-inputs /absolute/path/to/inputs.json
```

The version 1 manifest contains exactly `schema_version` and `artifacts`.
`hub_binary` and `session_worker_binary` name executable files with SHA-256
digests, full source revisions, and clean absolute source-checkout paths; each
entry contains exactly `kind`, `path`, `sha256`, `source_checkout`, and
`revision`, with `kind` set to `executable`. The remaining artifacts contain
exactly `kind`, `path`, and `revision`, set `kind` to `git_checkout`, and name
clean absolute Git checkout roots at full revisions:
`core_source`, `web_package`, `tui_package`, `workspaces_package`,
`ui_contract_source`, `web_driver_source`, and `tui_driver_source`.

This command is currently a provenance-only skeleton. It deliberately does not
launch clients or count as browser/TUI acceptance until the separately routed
Web and TUI drivers have merged and their repository-documented invocation and
structured evidence contracts are integrated. It never infers sibling paths,
accepts dirty checkouts, or treats a mutable branch name as a revision. A
failure in a Hub, Web, TUI, Core, or UI-contract input must be repaired in that
owning repository rather than patched by this package.

See [docs/workspace-domain.md](docs/workspace-domain.md) and
[docs/capabilities.md](docs/capabilities.md) for the exact domain and authority
contracts.
