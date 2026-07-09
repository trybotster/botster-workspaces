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
- `default_session_template_id`: compatibility pointer to the first default
  template reference.
- `default_session_template_refs`: one or more plugin-owned references to
  hub-owned session templates.
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
`default_spawn_target_id`, `default_session_template_id`,
`default_session_template_refs`, and `archive_policy`.

## Default Session Templates

Default session templates are hub-owned package manifest records exposed through
the daemon `session_templates` contract. Workspaces store references and cached
diagnostics only. A reference contains:

- `template_id`
- `label`
- `role`
- `group`
- `accessory`
- `selected`
- `validation_status`
- `diagnostic`
- `last_checked`

Existing singular `default_session_template_id` records normalize to a one-item
`default_session_template_refs` array when read. Invalid or missing template ids
remain in workspace state with an `invalid` diagnostic so operators can repair
the reference without losing intent.

Template diagnostics are refreshed through the hub-owned
`resolve_session_template` API and cached in plugin state. App and settings
surface renderers read the cached diagnostics; they do not synchronously resolve
hub templates during render.

Spawning from a workspace default goes through the hub-owned
`spawn_session_template` API. The workspace request supplies selected
`template_id`, `session_id`, and trusted context such as `workspace_id`, prompt,
ticket id, and branch name. The plugin never constructs raw process, PTY, spawn
target, command, or filesystem requests.

## Operations

### Create

Creating a workspace requires `name`, `purpose`, `local_repo_ref`, and
`spawn_target_ref`. The contract creates an active workspace with a plugin-owned
id, timestamps, an empty `session_group.session_refs` array, and default
settings.

Create rejects missing required fields and duplicate active workspace names.
Callers may pass `default_session_template_refs` for one or more template
references, or the compatibility `default_session_template_id` field for older
singular records.

### List

Listing workspaces returns active workspaces by default, sorted by `name`.
Archived or deleted visibility must be requested explicitly by a future runtime
option. List rows expose read-model fields only: id, name, purpose, status,
repo display label, spawn target label, session count, template reference
counts/labels/diagnostic counts, and entity family.

List rows must not expose raw host filesystem paths.

### Show

Showing a workspace by id returns the full workspace record, local repo
reference metadata, spawn target reference metadata, session group, default
template references, cached diagnostics, and settings. Unknown ids return a
not-found contract error.

### Update

Updating a workspace may patch plugin-owned fields: `name`, `purpose`,
`local_repo_ref`, `spawn_target_ref`, `default_session_template_id`,
`default_session_template_refs`, settings, and session reference metadata.
Clients select the default template through this update path by submitting
`default_session_template_refs` with exactly one reference marked `selected`.
The app and settings surfaces display the resulting selected/cached read model;
this package does not register a separate UI action descriptor for template
selection in this milestone.

Update rejects duplicate active names and hub-owned fields such as process
state, raw process/spawn requests, PTY state, terminal scrollback, package
admission state, spawn target records, and session manifests.

### Refresh Template Diagnostics

Refreshing diagnostics resolves each stored template id through the hub
`resolve_session_template` API when that capability is available to the plugin
worker. The plugin persists only the cached reference label, validation status,
diagnostic text, and last checked marker. Missing capabilities or missing
templates do not delete references.

### Spawn Default Session

Spawning a workspace default session selects the requested template id or the
selected/default reference and requests `spawn_session_template` from the hub.
The request includes workspace context limited to the proven `workspace_id`,
`prompt`, `ticket_id`, and `branch_name` fields. It does not contain raw target
ids, cwd/env overrides, executable, argument, metadata context, PTY, or host path
authority. Cwd/env setup remains hub-approved template data resolved by the
daemon, not workspace-plugin request construction.

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

The app surface renders that concrete state as a structural UINode application
surface: `panel` and `section` regions, a `metric_grid` summary, `toolbar`
presentation, a `list`/`list_item` workspace index, `status_badge` status
markers, and an `empty_state` when no active workspaces exist. Rows must expose
only read-model fields: workspace name and purpose, repo and spawn target
labels, status, session count, default template summary, and cached diagnostics.
They must not claim activation or selection behavior until shipped clients
consume the corresponding core interaction props.

The settings surface renders the effective archive policy, package/workspace
defaults, spawn target references, and cached template diagnostics with the same
primitive vocabulary. Supported affordances are UINode action contracts wired to
the registered create and spawn form submit handlers. Surfaces must not use
iframe/custom HTML for the basic index, private node kinds, `action_bar`,
payload-bearing row actions, toolbar dispatch buttons without required data, or
renderer-specific props.

The fixture read model includes:

- `id`
- `name`
- `purpose`
- `status`
- `repo_label`
- `spawn_target_label`
- `session_count`
- `default_session_template_count`
- `default_session_template_labels`
- `template_diagnostic_count`
- `invalid_template_count`
- `entity_family`

## Persistence Boundary

Runtime workspace records belong in `plugin.db` under the plugin runtime data
namespace. Source files in this repository are documentation, fixtures, tests,
and the package entrypoint; workspace records must not be persisted in source
files.
