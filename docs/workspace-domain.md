# Workspace domain

## Exact Record

A workspace record contains only:

```text
id
name
session_refs
created_at
updated_at
```

`name` is trimmed, non-empty, and unique across records that exist.
`session_refs` is an ordered, duplicate-free array of canonical Hub session
UUIDs. Old or additional record fields fail closed with
`legacy_workspace_schema`; there is no compatibility reader.

## Membership Invariant

A session UUID belongs to at most one workspace. Add rejects an existing owner
and identifies it. Move computes the complete source and destination state and
persists it once. Remove deletes only the reference. Missing, unavailable, or
ended sessions remain deliberate history until the user explicitly moves or
removes them.

The `botster-workspaces.workspace` entity read model publishes the grouping
fields plus a derived session count. It references Hub identities without
becoming their authority.

## Rename and Delete

Rename changes the trimmed unique name while preserving id, membership, and
creation time.

Delete physically removes the grouping record and releases its name and
memberships. It never terminates sessions or removes worktrees, branches, or
repositories.

## Atomic Spawn

The workflow projects enabled Git spawn points from the Hub. Once the user
selects a target, effective session types come only from
`session_templates.list({ target_id = ... })`.

The package calls only:

```text
session_templates.ensure_worktree_and_spawn
```

The request carries semantic target, branch, session type, and safe workspace
context. It never supplies a session id, cwd, repository path, worktree path,
base fact, or Git command. Only an `ok=true` response may append the canonical
`result.session_id`, and it is appended exactly once. Rejection or worker error
leaves membership unchanged.

A successful Hub spawn followed by a failed `plugin_db` write is reported as a
typed persistence error containing the ungrouped returned UUID. The package
does not attempt forbidden session rollback.

## Contextual Surface

The package has one stable `workspaces` app route. Its initial index contains
New workspace, rows, and an empty state with no visible form.

Accepted action results author scoped presentation operations:

- `selected-workspace` selects detail on the stable route.
- `workspace-dialog` reveals contextual create, rename, delete, membership, and
  target-first Spawn dialogs.

Rejected forms retain values and errors without presentation or replacement
effects. Accepted mutations clear their dialog and provide an owner-authored
replacement tree. Shared clients apply these generic contracts without
workspace-specific code.

Detail preserves referenced UUIDs and exposes Spawn, rename, delete,
Add/Move existing session, and remove membership.

## Lifecycle Projection

The detail tree projects each stored UUID against the canonical Hub `/session`
entity family with exact `session_uuid` and `lifecycle_class` filters:

- `current` renders under Current.
- `ended` renders under Ended.
- `indeterminate`, or an absent canonical row, renders under Unavailable /
  uncertain.

The structural tree is rendered once. Authoritative entity snapshots and
ordered upsert, patch, and remove frames reconcile membership presentation in
generic clients without polling, `list_sessions`, or a surface refresh. The
workspace record remains the exact five-field reference record; lifecycle
classes and availability are never copied into `plugin.db` or the plugin-owned
workspace entity family. Every reference remains until an explicit move or
remove, including ended and absent sessions.

## Persistence

Absent state is a valid empty install. Existing pre-release state fails closed
and requires an operator-selected fresh Hub data directory or explicit disposal
of backed-up disposable data. The package never deletes old data automatically.
