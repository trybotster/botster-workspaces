# botster-workspaces

First-party Botster workspace plugin.

This package is intended to own workspace state for local projects, spawn targets,
sessions, and workspace-scoped settings without moving that product policy into
botster-hub.

## Current scope

This repository is an installable scaffold. It declares package metadata, an
empty configuration schema, descriptor-backed app/settings surfaces, and the
minimal Lua entrypoint current local package enable/prepare requires.

It does not implement workspace domain state, plugin database tables, MCP tools,
agent orchestration, session actions, or a runnable app process yet.

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

Then run the local Botster smoke flow above against a real `botster-hub` binary.
