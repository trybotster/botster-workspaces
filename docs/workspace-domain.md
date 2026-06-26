# Workspace Domain Contract

`botster-workspaces` owns workspace records and their read models. The hub owns
package admission, spawn authorization, processes, PTYs, session UUIDs, terminal
transport, and scoped filesystem enforcement.

This contract defines records, operations, fixtures, and tests for the first
runtime CRUD handlers. Runtime behavior must continue to follow this document
unless a later contract change updates docs, fixtures, and tests together.

## Workspace Record

A workspace is a semantic grouping by purpose, not a branch. It can reference a
local repository and hub spawn target, and it can group hub session references,
but it does not own the underlying repository, spawn target, process, PTY, or
terminal state.

Required fields:

- `id`: stable plugin-owned id, such as `ws_product_refactor`.
- `name`: unique among active workspaces.
- `purpose`: the semantic reason the workspace exists.
- `status`: `active`, `archived`, or `deleted`.
- `local_repo_ref`: plugin-owned repository reference metadata.
- `spawn_target_ref`: plugin-owned reference to a hub-owned spawn target.
- `session_group`: plugin-owned grouping of hub session references.
- `default_session_template_id`: optional plugin-owned template reference.
- `settings`: plugin-owned workspace settings.
- `created_at` and `updated_at`: contract timestamps.

`local_repo_ref` contains `id`, `display_name`, `repo_capability_ref`,
`default_branch`, and `relative_worktree_hint`. It must not contain a raw host
absolute path. Repository resolution happens through hub-enforced scoped
filesystem capabilities.

`spawn_target_ref` contains `target_id`, `label`, `kind`, and `capability_ref`.
The hub owns target admission and spawn authorization.

`session_group` contains `workspace_id` and `session_refs`. Each session
reference contains `session_uuid`, `role`, `spawned_from_template_id`, and
`status`. These are references only; deleting a workspace never deletes a hub
session.

`settings` contains `workspace_id`, `default_repo_ref_id`,
`default_spawn_target_id`, `default_session_template_id`, and `archive_policy`.

## Default Session Templates

Default session templates are plugin-owned records used to request hub-owned
spawns. A template contains:

- `id`
- `name`
- `spawn_target_ref`
- `command_profile`
- `initial_prompt_template`
- `environment_policy`
- `enabled`

Templates do not bypass hub spawn policy. They provide default request metadata
for the hub-owned spawn path.

## Operations

### Create

Creating a workspace requires `name`, `purpose`, `local_repo_ref`, and
`spawn_target_ref`. The contract creates an active workspace with a plugin-owned
id, timestamps, an empty `session_group.session_refs` array, and default
settings.

Create rejects missing required fields and duplicate active workspace names.

### List

Listing workspaces returns active workspaces by default, sorted by `name`.
Archived or deleted visibility must be requested explicitly by a future runtime
option. List rows expose read-model fields only: id, name, purpose, status,
repo display label, spawn target label, session count, and entity family.

List rows must not expose raw host filesystem paths.

### Show

Showing a workspace by id returns the full workspace record, local repo
reference metadata, spawn target reference metadata, session group, default
template reference, and settings. Unknown ids return a not-found contract error.

### Update

Updating a workspace may patch plugin-owned fields: `name`, `purpose`,
`local_repo_ref`, `spawn_target_ref`, `default_session_template_id`, settings,
and session reference metadata.

Update rejects duplicate active names and hub-owned fields such as process
state, PTY state, terminal scrollback, package admission state, spawn target
records, and session manifests.

### Delete Or Archive

Delete follows the workspace `archive_policy`. The first contract marks the
workspace `deleted` and excludes it from default list behavior.

Delete does not delete hub sessions, package records, spawn targets, repository
content, or host filesystem content.

## Entity Read Models

The plugin exposes workspace read models through `botster_workspaces.list` and
`botster_workspaces.entity_snapshot`. The read-model family name is
`botster-workspaces.workspace`.

The current hub revision used by this package does not expose a live plugin
entity broadcast capability. Until that primitive exists, app and settings
surface routes render concrete structural UI from plugin-owned `plugin_db` state
instead of emitting bound rows that depend on an unavailable entity producer.

The fixture read model includes:

- `id`
- `name`
- `purpose`
- `status`
- `repo_label`
- `spawn_target_label`
- `session_count`
- `entity_family`

## Persistence Boundary

Runtime workspace records belong in `plugin.db` under the plugin runtime data
namespace. Source files in this repository are documentation, fixtures, tests,
and the package entrypoint; workspace records must not be persisted in source
files.
