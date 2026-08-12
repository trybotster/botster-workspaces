# botster-workspaces

First-party Botster plugin for contextual session grouping.

## Contextual session grouping

A workspace is a user-named grouping of Hub session identities. Its persisted
record is exactly:

```text
{ id, name, session_refs, created_at, updated_at }
```

The package owns names, grouping membership, and the workspace workflow. The
Hub remains authoritative for spawn points, effective session types, managed
Git worktrees, session UUIDs, processes, terminals, and lifecycle.

The public plugin tools are:

- `botster_workspaces.create`
- `botster_workspaces.list`
- `botster_workspaces.show`
- `botster_workspaces.rename`
- `botster_workspaces.delete`
- `botster_workspaces.add_session`
- `botster_workspaces.move_session`
- `botster_workspaces.remove_session`
- `botster_workspaces.spawn`
- `botster_workspaces.entity_snapshot`

One session UUID belongs to at most one workspace, enforced by durable
`membership:<session_uuid>` keys and published through the
`botster-workspaces.membership` entity family after committed claims and
removals. Add rejects an existing owner; move removes the source membership and adds the destination membership
in one `plugin_db` write; remove changes only grouping. Deleting a workspace
removes only that grouping record. It never terminates a session or removes a
worktree, branch, or repository.

## Workspace app

The package declares one app surface and one navigation item, both named
`workspaces`. The stable Hub surface path is
`/packages/botster-workspaces/surfaces/workspaces`.

The initial index contains a contextual **New workspace** action, workspace
rows, and an empty state. Forms are materialized only after an accepted plugin
action sets scoped client-local presentation state. Selecting a row reveals the
detail presentation on the same route and remains stable across rerenders.

Detail preserves every referenced session UUID and exposes:

- Spawn
- rename
- delete
- Add or move an existing session
- remove membership

**Add existing session** authors an Available sessions picker bound to Hub
`/session` through `entity_options`, excluding every UUID present in
`/botster-workspaces.membership`. Option labels prefer Hub `label` when present
and fall back to `session_uuid`; optional `lifecycle`, `lifecycle_class`,
`session_type_id`, and `spawn_point` fields are projected when present and never
copied into `plugin.db`. An always-visible advanced **Historical session UUID**
field remains for sessions absent from current Hub entity state; when both
fields are set, the advanced value wins. Membership claim and remove still
publish live membership entity frames for open pickers.

Detail groups each stored reference as **Current**, **Ended**, or
**Unavailable / uncertain** by binding the stable surface tree directly to the
Hub-owned `/session` entity family. Snapshot, upsert, patch, and remove frames
therefore move rows without polling, an imperative session-list refresh, or a
surface rerender. Ended, indeterminate, and absent UUIDs remain deliberate
workspace history until the user explicitly moves or removes them. The package
does not persist, compute, or guess lifecycle truth.

Spawn is target-first. The package lists enabled Git spawn points, then asks
the Hub for effective session types for the selected target through
`session_types.list`. It submits the fully qualified `session_type_id` the Hub
returned, unchanged, and calls only
`session_types.ensure_worktree_and_spawn`. After success it records exactly
the returned `result.session_id`; a rejection or worker error records nothing.
If the Hub spawn succeeds but the following grouping write fails, the action
reports the returned ungrouped UUID and does not claim membership.

Session-type presentation is Hub-owned. The package renders the label and id it
receives; it does not own the role, interaction, trait, or lifecycle taxonomy,
session-type source precedence, or source editability.

The detail Spawn opener exposes `botster_workspaces.open_spawn` as its stable,
renderer-neutral consumer identity. Clients locate it from realized action
metadata and dispatch the exact action id, node id, and payload they received;
they do not parse the visible `Spawn` copy or synthesize its dynamic node id.

## Clean-start data

This is a cold replacement of the pre-release workspace product. The package
does not normalize or migrate old records. Existing pre-release users must stop
the old Hub and either:

1. start the current Hub with a new empty `--data-dir`; or
2. back up and explicitly discard the old disposable Hub data directory before
   reinstalling.

The package performs no automatic reset or deletion. Encountering an old
record returns the typed `legacy_workspace_schema` error with this clean-start
guidance.

## Local development

Use a fresh Hub data directory, isolated from any pre-release state:

```sh
tmp_data_dir="$(mktemp -d /tmp/botster-workspaces.XXXXXX)"

botster-hub packages install --data-dir "$tmp_data_dir" --path ../botster-workspaces
botster-hub packages enable --data-dir "$tmp_data_dir" botster-workspaces
botster-hub packages show --data-dir "$tmp_data_dir" botster-workspaces
botster-hub packages list --data-dir "$tmp_data_dir"
```

Run the repository checks:

```sh
script/test

BOTSTER_UI_CONTRACT_PATH=/path/to/botster-hub/crates/botster-ui-contract \
  script/validate_ui_node_contract
```

The second command validates the owner-authored tree against the exact Hub
`botster-ui-contract` artifact. There is no Core-backed fallback.

For real package behavior, start a current Hub from a fresh data directory,
install and enable this checkout, then run:

```sh
script/hub_acceptance_smoke /path/to/current-hub.sock
```

That smoke crosses the registered package, plugin worker, atomic managed-Git
spawn, persistence/restart, canonical session-entity lifecycle reconciliation,
surface render, and non-destructive delete paths.

After the repository-documented consumer modes are available, run the
package-specific Web lifecycle smoke from `botster-web` with this checkout:

```sh
BOTSTER_HUB_BIN=/path/to/botster-hub \
BOTSTER_SESSION_WORKER_BIN=/path/to/botster-session-worker \
BOTSTER_WORKSPACES_PACKAGE_PATH="$PWD" \
  npm run smoke:workspaces-lifecycle
```

Run the corresponding documented Workspaces lifecycle mode from `botster-tui`
with the same Hub, worker, and package provenance. These modes must exercise
the real owner-authored tree through each generic renderer; repository-local
source or fixture inspection is not a substitute.

### Shared-stack acceptance

The final browser/TUI profile uses one parent-owned Hub process and one fresh
data directory. It installs and enables Web, TUI, Workspaces, and the
repository-owned session-type fixture once, then drives both installed
clients against the same durable Hub state. Supply an explicit immutable input
manifest and a new absolute evidence directory:

```sh
script/test-hub-flow shared-stack validate-inputs /absolute/path/to/inputs.json
script/test-hub-flow shared-stack run /absolute/path/to/inputs.json /absolute/path/to/new-evidence
```

`script/test-hub-flow` fails closed with usage for any unrecognized argument
shape. The runtime profile prefers the short `/private/tmp` root when present
because the Hub uses a Unix-domain socket; it validates the resolved socket
path against a conservative platform limit before starting Hub and reports a
clear error if the fallback temporary root is too long.

The version 1 manifest contains exactly `schema_version` and `artifacts`.
`hub_binary`, `session_worker_binary`, and `tui_binary` name executable files
with SHA-256 digests, full source revisions, and clean absolute
source-checkout paths. Each executable entry contains exactly `kind`, `path`,
`sha256`, `source_checkout`, and `revision`. The checkout entries contain
exactly `kind`, `path`, and `revision` and name clean absolute Git roots:
`core_source`, `web_package`, `tui_package`, `tui_kit_source`,
`workspaces_package`, `ui_contract_source`, `web_driver_source`, and
`tui_driver_source`. Repeating a checkout for its package and driver is
intentional: the manifest states both roles explicitly and the validator
requires one exact revision for each.

The run writes raw Hub, Web, and TUI logs, the assigned TUI scenario and JSONL
ledger, owner-boundary output, and `summary.json`. The summary records the
exact clean shared-stack harness revision alongside every supplied artifact.
It proves browser
create/select/Spawn through the production renderer and transport, keyboard
Spawn through the production TUI frame and hit map, the missing-branch,
existing-branch, and exact-worktree states, pushed lifecycle reconciliation,
typed non-destructive collisions, one-workspace ownership, grouping-only
deletion, terminal teardown with zero surviving sessions, and Hub-owned
UI-contract provenance. The expensive cross-repository
profile is deliberately opt-in and is not part of `script/test`.

The validator never infers sibling paths, accepts dirty checkouts, or treats a
mutable branch name as a revision. The supplied Hub revision must be the exact
contract source pinned by both client graphs; it need not be the newest Hub
commit. A failure in a Hub, Web, TUI, Core, TUI-kit, or UI-contract input must
be repaired in that owning repository rather than patched by this package.

### Claim-stack acceptance

The available-session claim integration profile proves the complete claim flow
on one parent-owned clean Hub with the real `botster-workspaces` package and
production Web dual-browser interaction. It is opt-in and uses the same
immutable pin manifest shape as shared-stack:

```sh
script/test-hub-flow claim-stack validate-inputs /absolute/path/to/inputs.json
script/test-hub-flow claim-stack run /absolute/path/to/inputs.json /absolute/path/to/new-evidence
```

Minimum consumer pins (refresh at run time; dirty checkouts fail closed):

| Component | Minimum revision / control |
| --- | --- |
| Workspaces package | `7ab4d1334214b3ea3c8b02e9ea665a27e70c0916` |
| Hub binary source | `de6b09982e72fd5efd04a5258f5fc645f611adbc` |
| Web package + driver | `102d39ea6c8ae7b927006dfba109171191c7b775` (includes `armDropNextInboundEntityFrame`) |
| TUI package + driver | `d40f28f9de2b621e50367c0f014880429eddedde` (shared-Hub claim-driver) |

Parent campaign lanes (one shared `--data-dir`):

- Package/Hub substrate via `script/hub_acceptance_smoke` (empty membership
  `items == []`, entity_options authoring, membership publish, concurrent claim
  uniqueness).
- Production Web dual-browser claim campaign (`script/claim_stack_web_driver.mjs`):
  entity_options select without typing an ID, SPA `request_id` correlation,
  dual-workspace race (one owner + typed conflict), same-workspace concurrent
  idempotent claim, historical advanced UUID recovery, in-page
  `transportControl.closeDataChannel` reconnect, and ordered
  `sequence_gap` via `transportControl.armDropNextInboundEntityFrame` (Web
  ticket `ticket_1786518263_839128`).
- Production TUI keyboard claim on the **same** Hub via
  `botster.tui.workspaces-claim-driver/v1` (`apps open botster-tui` with
  `BOTSTER_TUI_ACCEPTANCE_SCENARIO` / evidence, strict build receipt from
  `script/write-claim-build-receipt`). Proves realized
  `botster_workspaces.add_session`, membership join, and option exclusion
  (TUI ticket `ticket_1786529885_807584`).
- Supporting pin-matched consumer re-checks (separate clean Hubs by consumer
  design): Web `npm run smoke:workspaces-lifecycle` and TUI
  `script/test-live-hub workspaces lifecycle`.

Forbidden: `list_sessions` as picker source, force interaction, direct action
payloads as race/claim participants, package-tool claim as a UI substitute,
page-reload-as-reconnect, client-store injection as a gap trigger, and
timing-only pass criteria.

Evidence lands in the supplied directory as raw logs plus `summary.json` with
pins, membership oracles, SPA request-state, forbidden-methods audit, and the
production entry-point statement.

See [docs/workspace-domain.md](docs/workspace-domain.md) and
[docs/capabilities.md](docs/capabilities.md) for the exact domain and authority
contracts.
