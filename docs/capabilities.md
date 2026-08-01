# Workspace capabilities

## Declared Capabilities

The package requests:

- `mcp`
- `plugin_db` scoped to `botster-workspaces`
- `surfaces`
- `session_actions` scoped to `session_template_managed_git_spawn`

It requests no filesystem, shell, raw process, terminal, or lifecycle
authority.

## Plugin-Owned State

The plugin owns exact workspace records, unique names, single-owner session
membership, grouping CRUD, entity read models, and owner-authored workspace
UiNode actions.

## Hub-Owned Authority

The Hub owns admitted spawn points, target-filtered effective session types,
repositories, branches, managed worktrees, locks, rollback, canonical session
UUIDs, process and PTY lifecycle, terminals, and lifecycle truth.

The plugin may read `spawn_targets.list` and target-filtered
`session_templates.list`. The only privileged mutation it invokes is
`session_templates.ensure_worktree_and_spawn`.

## Failure Atomicity

Membership changes use one complete `plugin_db` write. Hub spawn rejection or
worker failure records nothing. Successful spawn records only the returned
canonical UUID, after success. A later persistence failure reports that UUID as
ungrouped and never claims a durable membership or attempts session cleanup.

Workspace deletion and membership removal do not call Hub lifecycle or Git
cleanup operations.

## UI Contract

The owner-authored surface is validated against the exact Hub
`botster-ui-contract` crate. Accepted action results alone carry presentation
and replacement effects. The client owns scoped presentation storage and
generic rendering; this package owns the actions and trees.

The tree binds referenced UUIDs to the Hub-owned `/session` family. The
ordinary `surfaces` capability admits this read-model dependency; the package
does not request a lifecycle capability or publish a duplicate session entity.
Exact lifecycle filters author Current, Ended, and Unavailable / uncertain
presentation while Hub entity frames remain the only reconciliation channel.
