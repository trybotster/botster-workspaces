# Workspace capabilities

## Declared Capabilities

The package requests:

- `mcp`
- `plugin_db` scoped to `botster-workspaces`
- `surfaces`
- `session_actions` scoped to `session_type_managed_git_spawn`

It requests no filesystem, shell, raw process, terminal, or lifecycle
authority.

## Plugin-Owned State

The plugin owns exact workspace records, unique names, single-owner session
membership (including the durable `membership:<session_uuid>` index and the
`botster-workspaces.membership` entity family), grouping CRUD, entity read
models, and owner-authored workspace UiNode actions.

Membership mutations commit membership keys, `workspace_state`, and a durable
range reservation of `membership_entity_seq` in one `plugin_db.batch`, then
publish only the reserved frames through `botster.entity_publish`. The package
never publishes false state for failed or conflicting writes.

## Hub-Owned Authority

The Hub owns admitted spawn points, target-filtered effective session types,
their package/device/repo source precedence and editability, their role,
interaction, trait, and lifecycle taxonomy, the fully qualified
`session_type_id`, repositories, branches, managed worktrees, locks, rollback,
canonical session UUIDs, process and PTY lifecycle, terminals, and lifecycle
truth.

The plugin may read `spawn_targets.list` and target-filtered
`session_types.list`. The only privileged mutation it invokes is
`session_types.ensure_worktree_and_spawn`, keyed by the `session_type_id` the
Hub returned. The plugin displays Hub-provided session-type presentation and
never derives or overrides that semantic truth.

## Failure Atomicity

Membership changes use one complete `plugin_db.batch` for membership keys,
workspace state, and sequence reservation. Hub spawn rejection or worker failure
records nothing. Successful spawn records only the returned canonical UUID,
after success, through the same claim batch path. A later persistence failure
reports that UUID as ungrouped and never claims a durable membership or attempts
session cleanup.

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
