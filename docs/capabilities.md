# Workspace Capability Contract

`botster-workspaces` declares the capabilities needed to define workspace state
without taking hub authority.

## Declared Capabilities

The runtime contract uses the logical capability names below. The current
hub-compiled manifest schema serializes admitted package capabilities as
`{ "surface": "...", "scope": "..." }` objects, so `botster-package.json`
declares the current admission shape:

- `{ "surface": "mcp" }`: expose CRUD operations as plugin tools.
- `{ "surface": "plugin_db", "scope": "botster-workspaces" }`: persist
  workspace runtime state under this plugin's namespace.
- `{ "surface": "surfaces" }`: expose descriptor-backed app/settings surfaces.
- `{ "surface": "filesystem", "scope": "workspace" }`: resolve approved
  workspace-scoped repository references without raw host traversal.

The logical workspace contract remains:

- `plugin_db`: persist workspace records, local repo reference metadata, spawn
  target reference metadata, session groups, default session templates, and
  settings in plugin runtime data.
- `mcp`: expose create/list/show/update/delete and entity snapshot operations
  through Botster plugin tools.
- `surfaces`: expose the package app and settings descriptors.
- `spawn_targets:read`: list or validate references to hub-owned spawn targets.
- `sessions:read`: resolve hub-owned session references for grouping.
- `process:spawn`: request a hub-owned process/session only through the hub
  `spawn_session_template` API.
- `filesystem:scoped_repo`: resolve approved repository references without
  direct host filesystem traversal.

The landed hub session-template daemon contract exposes
`list_session_templates`, `show_session_template`, `resolve_session_template`,
and `spawn_session_template`. Workspace runtime code may cache references and
diagnostics from those APIs, but it must not duplicate the template registry or
materialize raw core spawn requests.

If the hub compiled manifest schema adds narrower first-class surfaces for
plugin entity broadcast, spawn-target reads, session reads, session-template
resolution, or template spawn requests, the manifest and this document must
change together.

## Plugin-Owned State

- Workspace records.
- Local repo reference metadata.
- Spawn target reference metadata.
- Session group records.
- Default session template references, labels, roles, grouping/accessory
  metadata, selected state, and cached diagnostics.
- Workspace settings.
- Workspace read models.

## Hub-Owned Authority

- Package install, provenance, lock metadata, and enablement.
- Admitted spawn target records and spawn authorization.
- Session-template registry, resolution, context injection, and spawn request
  materialization.
- Process and PTY lifecycle.
- Session UUIDs, terminal transport, scrollback, and recovery.
- Scoped filesystem enforcement.

Plugin state may reference hub-owned ids. It must not rewrite hub-owned records
or read arbitrary host filesystem paths.

## Contract Assertions

- Manifest capabilities must include every capability listed here.
- Contract fixtures must not require a capability missing from the manifest.
- Template spawn requests must use `spawn_session_template`, not raw process,
  command, PTY, spawn target, or filesystem fields.
- Workspace spawn requests may pass only the proven context fields
  `workspace_id`, `prompt`, `ticket_id`, and `branch_name`; cwd/env setup stays
  in hub-approved template data, and plugin requests must not add target,
  metadata, executable, argument, PTY, or filesystem overrides.
- Docs and fixtures must remain path-neutral and free of operator-specific
  identifiers.
- Project Pipelines behavior is outside this package contract.
