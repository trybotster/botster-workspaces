# botster-workspaces

First-party Botster workspace plugin.

This package is intended to own workspace state for local projects, spawn targets,
sessions, and workspace-scoped settings without moving that product policy into
botster-hub.

## Current scope

This repository is an installable workspace plugin. It declares package
metadata, package-level workspace defaults, descriptor-backed app/settings surfaces,
explicit workspace contract capabilities, and a Lua entrypoint with plugin-owned
runtime operations.

The first workspace domain contract is defined in:

- `docs/workspace-domain.md`
- `docs/capabilities.md`
- `test/fixtures/workspaces/contract.json`

The contract defines create/list/show/update/delete workspace behavior,
plugin-owned workspace records, local repo reference metadata, spawn target
references, session grouping, default session template references, workspace
settings, and workspace entity read models.

Runtime workspace records persist through `plugin_db`. The public operation path
is exposed through Botster plugin tools:

- `botster_workspaces.create`
- `botster_workspaces.list`
- `botster_workspaces.show`
- `botster_workspaces.update`
- `botster_workspaces.delete`
- `botster_workspaces.refresh_template_diagnostics`
- `botster_workspaces.spawn_default_session`
- `botster_workspaces.entity_snapshot`

The operations create/list/show/update/delete workspace records, attach sanitized
repo and spawn-target references, group hub session UUID references with
plugin-owned role/template/status metadata, cache diagnostics for referenced hub
session templates, and return read models identified as
`botster-workspaces.workspace`. A workspace can request a selected default
template through the hub-owned `spawn_session_template` API with workspace
context limited to the proven workspace id, prompt, ticket id, and branch name
fields. Cwd/env materialization remains hub template data, not plugin-authored
spawn payload. The plugin does not construct raw process, PTY, spawn target,
command, cwd/env override, metadata, or filesystem requests. Delete marks a
workspace deleted and does not delete hub sessions, package records, spawn
targets, repository content, or host filesystem content.

Default template selection is currently tool-driven. Clients select a workspace
default by calling `botster_workspaces.update` with
`default_session_template_refs` and exactly one `selected` reference; app and
settings surfaces render the selected/cached read model, while
`botster_workspaces.spawn_default_session` consumes that selected reference for
the hub-owned template spawn request. This package does not register a separate
UI action descriptor for template selection in this milestone.

This package does not implement agent orchestration, session actions, or a
runnable app process yet. Runtime paths use plugin-owned persistence and hub
capability references rather than direct host filesystem access or hub storage
rewrites.

## Authority boundary

Plugin-owned state:

- workspace records
- local repo reference metadata
- spawn target reference metadata
- session group references
- default session template references and cached diagnostics
- workspace settings
- workspace entity read models

Hub-owned authority:

- package install, provenance, lock metadata, and enablement
- spawn target admission and spawn authorization
- session-template registry, resolution, context injection, and spawn
  materialization
- process and PTY lifecycle
- session UUIDs, terminal transport, scrollback, and recovery
- scoped filesystem enforcement

## Local development

Use an isolated Botster data directory when proving package install and
enablement:

```sh
tmp_data_dir="$(mktemp -d /tmp/botster-workspaces.XXXXXX)"

botster-hub packages install --data-dir "$tmp_data_dir" --path ../botster-workspaces
botster-hub packages show --data-dir "$tmp_data_dir" botster-workspaces
botster-hub packages enable --data-dir "$tmp_data_dir" botster-workspaces
botster-hub packages show --data-dir "$tmp_data_dir" botster-workspaces
botster-hub packages list --data-dir "$tmp_data_dir"
botster-hub packages config --data-dir "$tmp_data_dir" botster-workspaces
botster-hub packages config set --data-dir "$tmp_data_dir" botster-workspaces '{"archive_policy":{"type":"select","value":"archive"}}'
botster-hub packages reload --data-dir "$tmp_data_dir" botster-workspaces
```

The second `packages show` should report the package as enabled and expose the
`configuration` schema with the `archive_policy` field. The package has no
required configuration values, so enablement should not report missing
configuration diagnostics. A valid `packages config set` persists the selected
package-global default through the hub package configuration path; an unsupported
select value or unknown field should fail through the same path with a package
configuration diagnostic. Reload the package after changing configuration so the
plugin worker receives the refreshed effective values before creating new
workspace records.

For app/settings discovery, verify that the package row exposes explicit
package navigation entries and descriptor surfaces. Navigation entries declare
that existing plugin surfaces are discoverable by host clients; they do not
declare global ordering, priority, pinning, hiding, sidebar placement, route
layout, padding, or local navigation. Browser and TUI clients own presentation
placement over the stable navigation and route ids. Surface root `UiNode`s own
only the page content rendered through the plugin surface contract.
The daemon production path is `list_package_navigation`, which returns
`package_navigation` rows admitted by the hub.

- app surface: `workspaces`, icon `rectangle-group`
- settings surface: `workspaces-settings`, label `Workspaces Settings`, icon
  `cog-6-tooth`

Hub route descriptors are derived from the package surface descriptors and
configuration schema. Clients should use these stable ids and paths:

- app navigation item id: `workspaces`
- settings navigation item id: `workspaces-settings`
- app route id: `surface:workspaces`
- app route path: `/packages/botster-workspaces/surfaces/workspaces`
- settings surface route id: `surface:workspaces-settings`
- settings surface route path: `/packages/botster-workspaces/surfaces/workspaces-settings`
- package settings route id: `settings`
- package settings route path: `/packages/botster-workspaces/settings`

Both surfaces render structural UI from plugin-owned workspace state through the
same hub plugin surface contract consumed by browser and TUI clients. The package
intentionally does not declare a `runnable_entrypoints` item because there is no
workspace process to launch yet.

## Verification

Run the scaffold checks:

```sh
script/test
```

The harness validates the manifest, docs, fixtures, create/list/show/update/delete
contract examples, template diagnostics, selected-template spawn request shape,
registered plugin operations, plugin.db-backed runtime semantics, entity read
models, surface bindings, capability coverage, and leak scans for docs,
fixtures, and runtime tests.

Then run the local Botster smoke flow above against a real `botster-hub` binary.
