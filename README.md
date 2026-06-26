# botster-workspaces

First-party Botster workspace plugin.

This package is intended to own workspace state for local projects, spawn targets,
sessions, and workspace-scoped settings without moving that product policy into
botster-hub.

## Current scope

This repository is an installable scaffold. It declares package metadata, an
empty configuration schema, descriptor-backed app/settings surfaces, explicit
workspace contract capabilities, and the minimal Lua entrypoint current local
package enable/prepare requires.

The first workspace domain contract is defined in:

- `docs/workspace-domain.md`
- `docs/capabilities.md`
- `test/fixtures/workspaces/contract.json`

The contract defines create/list/show/update/delete workspace behavior,
plugin-owned workspace records, local repo reference metadata, spawn target
references, session grouping, default session templates, workspace settings, and
workspace entity read models.

It does not implement runtime workspace CRUD handlers, plugin database tables,
MCP tools, agent orchestration, session actions, or a runnable app process yet.
Those runtime paths must use plugin-owned persistence and hub capabilities rather
than direct host filesystem access or hub storage rewrites.

## Authority boundary

Plugin-owned state:

- workspace records
- local repo reference metadata
- spawn target reference metadata
- session group references
- default session templates
- workspace settings
- workspace entity read models

Hub-owned authority:

- package install, provenance, lock metadata, and enablement
- spawn target admission and spawn authorization
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
```

The second `packages show` should report the package as enabled and expose the
`configuration` schema with empty `groups` and `fields` arrays. The package has
no required configuration values, so enablement should not report missing
configuration diagnostics.

For app/settings discovery, verify that the package row exposes the descriptor
surfaces:

- app surface: `workspaces`
- settings surface: `workspaces-settings`

The scaffold intentionally does not declare a `runnable_entrypoints` item because
there is no workspace process to launch yet.

## Verification

Run the scaffold checks:

```sh
script/test
```

The harness validates the manifest, docs, fixtures, create/list/show/update/delete
contract examples, capability coverage, and leak scans for docs and fixtures.

Then run the local Botster smoke flow above against a real `botster-hub` binary.
