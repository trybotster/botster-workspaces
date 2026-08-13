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
`session_refs` is an ordered, duplicate-free array of non-empty Hub session
IDs. Session IDs are opaque and do not require UUID syntax. Old or additional
record fields fail closed with `legacy_workspace_schema`. There is no
compatibility reader.

## Membership Invariant

A session ID belongs to at most one workspace. Membership is enforced through
create-only `membership:<session_id>` keys in `plugin.db` alongside
`workspace_state.session_refs`. Add rejects an existing owner and identifies it.
Same-workspace reclaims are idempotent pure no-ops when the membership key
already exists. Move computes the complete source and destination state and
persists it once as an ownership upsert (not remove+upsert). Remove deletes only
the reference and membership key. Delete of a workspace range-releases every
membership key it owned. A confirmed ended session releases its membership
automatically. Missing, unavailable, and indeterminate sessions remain grouped
until the user removes them or the Hub confirms their terminal state.

The `botster-workspaces.workspace` entity read model publishes the grouping
fields plus a derived session count. It references Hub identities without
becoming their authority.

## Membership Entity Family

Claimed sessions also publish through the plugin-owned
`botster-workspaces.membership` family with exact rows:

```text
{ id, session_uuid, workspace_id }
```

where `id = session_uuid`. Rows carry no Hub lifecycle, label, or spawn fields.

After a successful membership mutation batch, the package publishes ordered
`entity_upsert` / `entity_remove` frames via `botster.entity_publish`. Sequence
values are package-owned and durable under `membership_entity_seq` (`next_seq`
is the last committed sequence). Multi-frame mutations (for example deleting a
workspace that released N memberships) reserve N consecutive sequences in the
same `plugin_db.batch` as the membership writes, then publish
`last+1 … last+N` in deterministic order. Failed batches advance neither the
counter nor the stream. Provider reconnect snapshots allocate one durable
sequence value on their own CAS path and never invent a sequence at or below the
committed floor.

## Available sessions picker

Add existing session authors one `ui.select` with
`props.options_source.$kind = "entity_options"`:

- `source = "/session"`
- `value_field = "session_uuid"`
- `display_fields = label, session_uuid, lifecycle, lifecycle_class,
  session_type_id, spawn_point`
- `exclude.source = "/botster-workspaces.membership"`

There are no static `select_option` children on that control. An always-visible
advanced historical session ID field (`session_id_advanced`) sits below the picker
for sessions absent from current Hub entity state. Action extraction prefers a
non-empty advanced value, then the picker value, and validates a non-empty Hub session ID.

## Rename and Delete

Rename changes the trimmed unique name while preserving id, membership, and
creation time.

Delete physically removes the grouping record and releases its name and
memberships. It never terminates sessions or removes worktrees, branches, or
repositories. A confirmed ended session releases its membership automatically.

## Atomic Spawn

The workflow projects every enabled Hub spawn point. Workspaces group sessions;
they do not own Git. Once the user selects a target, effective session types
come only from `session_types.list({ target_id = ... })`. Each row is consumed
through its fully qualified `session_type_id`; the package neither reconstructs
that identity from source and id nor accepts a row without it.

Spawn path follows Hub target kind:

```text
# non-Git (typical directory spawn points)
session_types.spawn({ session_type_id, target_id, context })

# Git targets with a branch (managed worktree + spawn)
session_types.ensure_worktree_and_spawn({
  target_id, branch, session_type_id, context
})
```

Requests carry semantic target, `session_type_id`, optional safe workspace
context, and branch only when the Hub target is Git. The package never supplies
a session id, cwd, repository path, worktree path, base fact, or Git command.
Only a successful Hub response may append the returned canonical session id,
exactly once. Rejection or worker error leaves membership unchanged.

A successful Hub spawn followed by a failed `plugin_db` write is reported as a
typed persistence error containing the ungrouped returned session ID. The package
does not attempt forbidden session rollback.

## Contextual Surface

The package has one stable `workspaces` app route. The host owns the route title
and page chrome. The plugin root is one vertical content stack. Its initial
index contains New workspace, activating rows, and an empty state with no
visible form. Rows do not add a separate Open action.

Accepted action results author scoped presentation operations:

- `selected-workspace` selects detail on the stable route.
- `workspace-dialog` reveals contextual create, workspace settings,
  membership, and target-first Spawn dialogs.

Rejected forms retain values and errors without presentation or replacement
effects. Accepted mutations clear their dialog and provide an owner-authored
replacement tree. Shared clients apply these generic contracts without
workspace-specific code.

Detail preserves referenced session IDs. One toolbar exposes Spawn, Add, and
Move as session actions. A separate Workspace settings command contains rename
and delete controls. The selected row authors the workspace name once. The
detail uses compact lifecycle groups instead of nested page sections.

## Lifecycle Projection

The detail tree projects each stored session ID against the canonical Hub `/session`
entity family with exact `session_uuid` and `lifecycle_class` filters:

- `current` renders under Current.
- `indeterminate`, or an absent canonical row, renders under Unavailable.

The structural tree is rendered once. Authoritative entity snapshots and
ordered upsert, patch, and remove frames reconcile membership presentation in
generic clients without polling, `list_sessions`, or a surface refresh. The
Current and Unavailable headings therefore remain present
for every non-empty workspace even when a group currently realizes no rows;
an empty group is expected structural presentation rather than a refresh fault.
The workspace record remains the exact five-field reference record; lifecycle
classes and availability are never copied into `plugin.db` or the plugin-owned
workspace entity family. A Hub lifecycle event atomically removes a confirmed
ended reference and its membership key. An indeterminate or absent reference
stays until the Hub confirms its terminal state or the user removes it.

## Persistence

Absent state is a valid empty install. Existing pre-release state fails closed
and requires an operator-selected fresh Hub data directory or explicit disposal
of backed-up disposable data. The package never deletes old data automatically.
