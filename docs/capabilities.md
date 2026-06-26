# Workspace Capability Contract

`botster-workspaces` declares the capabilities needed to define workspace state
without taking hub authority.

## Declared Capabilities

- `plugin_db`: persist workspace records, local repo reference metadata, spawn
  target reference metadata, session groups, default session templates, and
  settings in plugin runtime data.
- `entities`: publish workspace read models as plugin-owned entity frames.
- `surfaces`: expose the package app and settings descriptors.
- `spawn_targets:read`: list or validate references to hub-owned spawn targets.
- `sessions:read`: resolve hub-owned session references for grouping.
- `process:spawn`: request a hub-owned process/session from a default template.
- `filesystem:scoped_repo`: resolve approved repository references without
  direct host filesystem traversal.

These names are the manifest strings currently used by this package. If the hub
compiled manifest schema later renames any capability, the manifest and this
document must change together.

## Plugin-Owned State

- Workspace records.
- Local repo reference metadata.
- Spawn target reference metadata.
- Session group records.
- Default session templates.
- Workspace settings.
- Workspace entity read models.

## Hub-Owned Authority

- Package install, provenance, lock metadata, and enablement.
- Admitted spawn target records and spawn authorization.
- Process and PTY lifecycle.
- Session UUIDs, terminal transport, scrollback, and recovery.
- Scoped filesystem enforcement.

Plugin state may reference hub-owned ids. It must not rewrite hub-owned records
or read arbitrary host filesystem paths.

## Contract Assertions

- Manifest capabilities must include every capability listed here.
- Contract fixtures must not require a capability missing from the manifest.
- Docs and fixtures must remain path-neutral and free of operator-specific
  identifiers.
- Project Pipelines behavior is outside this package contract.
