# Implement report: prove available session claiming across Hub, Workspaces, Web, and TUI

## Target repository and target_id

| Field | Value |
| --- | --- |
| Target repository | `botster-workspaces` (`trybotster/botster-workspaces`) |
| Target ID | `tgt_71266a8d976d4535902ffed09c18a7ba` |
| Ticket | `ticket_1786474783_285888` |
| Run | `run_1786516676_981514` |
| Branch | `project-pipelines/ticket_1786474783_285888` |
| Approved plan | `docs/plans/prove-available-session-claiming-across-hub-web-tui.md` (v4) |
| Runtime-teardown class | **Does not apply** (`teardown_class_applies: false`) |

Routing proof: `project_pipelines_current_context` and `list_spawn_targets` resolve `tgt_71266a8d976d4535902ffed09c18a7ba` to `botster-workspaces` / `trybotster/botster-workspaces`. Ambient CWD was not used as ownership authority. Worktree synced to Workspaces product tip `7ab4d1334214b3ea3c8b02e9ea665a27e70c0916` before implementation.

## Repository playbook and other playbooks/notes applied

### Role / charter (required order)

1. [[implementer-playbook]]
2. [[botster-implementer-playbook]]
3. [[botster-workspaces-playbook]]
4. Targeted atomic notes below
5. [[project-pipelines-playbook]] — **not loaded for product scope** (no Project Pipelines package/plugin path edits)

### Charter must-load notes

- [[workspaces are semantic groupings by purpose not by branch]]
- [[botster workspace records are plugin owned references not hub authority]]
- [[botster plugin entities are canonical for plugin-owned dynamic state]]
- [[botster package manifests and lockfiles should declare capabilities and provenance]]
- [[botster hub gravity must be watched before it becomes the new monolith]]
- [[acceptance harness region oracles must key on node identity not concatenated text]]
- [[plugin ui action ids are a two site change and hub fails closed on unregistered ids]]
- [[shared hub workspaces acceptance omits package path without skipping its lane]]

### Ticket-specific notes

- [[conformance harnesses gate on deterministic invariants not timing]]
- [[conformance helpers must dispatch the action id read from the rendered node]]
- [[conformance oracles assert action result frames not toast text]]
- [[a page reload is not a reconnect]]
- [[botster entity snapshots are authoritative reconnect baselines]]
- [[closed dependency tickets signal merged source not a consumable release]]
- [[implementation artifacts must match actual git state]]
- [[implement gate must verify committed work and pr link before review]]
- [[implementation steps must persist report artifacts for review]]

### Explicitly not loaded

- [[botster runtime teardown lenses]] — plan records `teardown_class_applies: false`

## Files changed

| Path | Role |
| --- | --- |
| `script/claim_stack_acceptance` | Parent claim campaign: one clean Hub, pin validation, substrate smoke, seed, Web dual-browser driver, membership oracles, supporting consumers, evidence ledger |
| `script/validate_claim_stack_inputs` | Immutable pin/input validation (shared-stack schema) |
| `script/claim_stack_web_driver.mjs` | Production Playwright dual-browser claim lanes C1/C3/C4/C5/C6a/C6b |
| `script/test-hub-flow` | `claim-stack validate-inputs` / `claim-stack run` profiles |
| `script/test` | Static schema/syntax/forbidden-method contract for claim-stack (not live stack) |
| `README.md` | Claim-stack command, pins, forbidden methods, evidence |
| `docs/plans/prove-available-session-claiming-across-hub-web-tui.md` | Approved plan artifact (v4) |
| `docs/reports/prove-available-session-claiming-implement-report.md` | This report |

`plugin.lua`, `botster-package.json`, and domain schema were **not** changed (product claim behavior already on main).

## Ownership boundaries preserved

- **This repository owns:** package orchestration of the multi-client claim campaign, membership/package substrate oracles, documentation, and repository-owned test wrappers.
- **Consumed only (no product edits):**
  - Hub session identity, lifecycle, entity fanout (`botster-hub-playbook`)
  - Web Ionic entity_options + harness controls (`botster-web-playbook`) including `armDropNextInboundEntityFrame` from `ticket_1786518263_839128`
  - TUI keyboard lifecycle consumer (`botster-tui-playbook`)
- No package-specific client code was added to Web or TUI repositories from this run.

## Cross-repo dependencies or separately routed work

| Dependency | Status | Consumption |
| --- | --- | --- |
| `ticket_1786474780_590414` Workspaces available sessions | closed | package tip `7ab4d13` |
| `ticket_1786474780_865627` Web entity-backed select | closed | Web pin |
| `ticket_1786474781_871159` TUI entity-backed select | closed | TUI pin |
| `ticket_1786494180_266672` Hub package entity fanout | closed | Hub pin `de6b099` |
| `ticket_1786518263_839128` Web frame-drop sequence_gap | **closed** (`dependency_1786518942_244198`) | Web ≥ `102d39e`; control `transportControl.armDropNextInboundEntityFrame` |

## Deviations from plan

1. **TUI C2 keyboard claim on the shared parent Hub** is not driven by a parent-owned TUI scenario schema (only spawn-driver schema exists). Parent proves TUI via pin-matched supporting `script/test-live-hub workspaces lifecycle` (consumer-owned Hub, required section D). Residual risk recorded below; a shared-Hub TUI claim driver would be a separately routed TUI ticket if Review requires same-data-dir TUI keyboard participation beyond supporting proof.
2. **Web lifecycle mode rejects `BOTSTER_LIVE_DATA_DIR`** by design. Parent therefore owns a dedicated Playwright claim driver against the shared Hub rather than reusing `smoke:workspaces-lifecycle` for parent C lanes. Supporting lifecycle remains section D.
3. **C1 remove→restore option reappearance** is asserted as membership DB removal on the parent Hub after the Web claim lane; a second held-open option restore UI pass is optional when the driver form remains open (membership exclusion/restore is covered by substrate + Web supporting lifecycle membership-reactive stage).

## Tests and downstream proof run

### Static / package-local

```sh
script/test
# script/test: ok
# includes claim-stack Ruby syntax, input validator negatives, driver contract tokens, README tokens
```

### Live claim-stack (opt-in)

```sh
script/test-hub-flow claim-stack validate-inputs /absolute/path/to/inputs.json
script/test-hub-flow claim-stack run /absolute/path/to/inputs.json /absolute/path/to/new-evidence
```

Pin floors enforced in harness + README:

| Component | Minimum |
| --- | --- |
| Workspaces | `7ab4d1334214b3ea3c8b02e9ea665a27e70c0916` |
| Hub | `de6b09982e72fd5efd04a5258f5fc645f611adbc` |
| Web | `102d39ea6c8ae7b927006dfba109171191c7b775` (`armDropNextInboundEntityFrame`) |
| TUI | `abc804e19bc3e01465cd308c11de5f4292331c3d` |

Frame-drop control name (from Web implement report):  
`globalThis.__BOTSTER_LIVE_PROTOCOL_HARNESS__.transportControl.armDropNextInboundEntityFrame({ entity_type: "botster-workspaces.membership" })`  
Chronology: warmup A → drop B → gap C.

Reconnect control: `transportControl.closeDataChannel` (not page reload).

### Production entry-point statement

Workspaces app surface → Add existing session → Available sessions `entity_options` (or advanced historical when absent) → realized `botster_workspaces.add_session` with correlated `request_id` → membership batch + `entity_publish` → generic Web entity stores update open pickers; reconnect baselines replace entity stores from authoritative snapshots; ordered gap drops a real inbound membership delta before `receiveEntityFrame` and hits production `sequence_gap` resubscribe.

## Unverified behavior or residual risk

1. Full end-to-end live claim-stack evidence directory may be incomplete if pin worktree builds or supporting consumer smokes fail in this environment; static contract coverage always runs in `script/test`.
2. Dual-browser SPA request-state oracles depend on Web harness event emission of `plugin_surface_action` / action results; pin mismatch without frame-drop control fails closed at source scan.
3. TUI same-Hub keyboard claim is supporting-only (see deviations).
4. Historical C5 requires the parent to end/remove the seed session before the advanced path; Hub remove API variance is tolerated with fallbacks.

## Missing vault guidance discovered

1. Parent-owned multi-client claim campaign (Available sessions + dual-browser race + historical + reconnect/gap) is new relative to spawn shared-stack — worth a vault note after capture.
2. Web lifecycle mode intentionally forbids caller-owned `BOTSTER_LIVE_DATA_DIR`; claim parents need a dedicated driver or a Web shared-hub claim mode.
3. Dual-subscriber package-entity floor + warmup claim for sequence_gap (from Web ticket report) should be cross-linked for future claim campaigns.

## Convention conflicts

None.
