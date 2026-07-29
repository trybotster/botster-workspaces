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

Current-versus-ended lifecycle grouping is intentionally deferred until the Hub
provides the canonical projection. This package does not persist, poll, or
guess lifecycle truth.

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
spawn, persistence/restart, surface render, and non-destructive delete paths.

The package-specific Web render/route smoke is:

```sh
BOTSTER_HUB_BIN=/path/to/botster-hub \
BOTSTER_SESSION_WORKER_BIN=/path/to/botster-session-worker \
BOTSTER_WORKSPACES_PACKAGE_PATH="$PWD" \
  npm run smoke:live-packaged-protocol
```

Run it from the current `botster-web` repository. Final Workspaces-specific
browser and TUI click-through is tracked by the coordinated integration ticket.

See [docs/workspace-domain.md](docs/workspace-domain.md) and
[docs/capabilities.md](docs/capabilities.md) for the exact domain and authority
contracts.
