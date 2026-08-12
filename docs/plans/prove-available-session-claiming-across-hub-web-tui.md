# Integration: prove available session claiming across Hub, Workspaces, Web, and TUI

## Delivery identity

| Field | Value |
| --- | --- |
| Ticket | `ticket_1786474783_285888` — Integration: prove available session claiming across Hub, Workspaces, Web, and TUI |
| Pipeline run | `run_1786516676_981514` |
| Plan step | `botster_stack_plan` (visit 4 after third `changes_required`) |
| Plan Review | visits 1–3: `review_1786517672_327647`, `review_1786518168_103485`, `review_1786518678_288773` |
| Target repository | `botster-workspaces` (`trybotster/botster-workspaces`) |
| Target ID | `tgt_71266a8d976d4535902ffed09c18a7ba` |
| Resolved path (admitted spawn target) | path from `list_spawn_targets` for `botster-workspaces` |
| Repository charter | [[botster-workspaces-playbook]] |
| Runtime-teardown class | **Does not apply** (`teardown_class_applies: false`) |

Routing proof: `project_pipelines_current_context` supplied `run.target_id` / `ticket.target_id` = `tgt_71266a8d976d4535902ffed09c18a7ba`. `list_spawn_targets` mapped that id to admitted target name `botster-workspaces` / repo `trybotster/botster-workspaces`. Ambient process CWD was not used as ownership authority.

## Plan Review disposition

### Visit 1 findings (`review_1786517672_327647`) — resolved in v2

| Finding | Class | Status |
| --- | --- | --- |
| `finding_1786517672_674450` Race permits package-tool path | product/high | **Resolved v2** — dual browser contexts; optional Web+TUI; package/tool forbidden. |
| `finding_1786517672_735482` Race omits SPA request-state | product/high | **Resolved v2** — dual `request_id` correlation. |
| `finding_1786517672_415822` Metadata/live-update incomplete | product/high | **Resolved v2** — four fields when present; both label **and** lifecycle live updates on Web and TUI. |
| `finding_1786517673_300411` Reconnect/gap underspecified | product/medium | **Partially resolved v2** — reconnect named; **ordered-gap trigger still open in visit 2**. |
| Checklist / gitignore process-infra | process/infra | **Resolved** — one checklist per visit; 12-line `.gitignore` verified. |

### Visit 2 findings (`review_1786518168_103485`) — fixed in v3

| Finding | Class | Plan response |
| --- | --- | --- |
| `finding_1786518168_452307` Ordered-gap proof names no reachable live trigger | product/high | **Fixed** — audited pins: Web `transportControl` only exposes `closeDataChannel`; Hub gap tests use forbidden `mutation_action`. **No reachable live sequence-gap trigger exists on current pins.** Created owner ticket `ticket_1786518263_839128` (Web) and registered blocking dependency `dependency_1786518268_190390`. Ordered-gap proof is **blocked** until that merge supplies a named frame-drop control; reconnect remains independently proveable. |
| `finding_1786518168_873270` Stale-selection permits force interaction | product/high | **Fixed** — remove all force interaction. Stale-selection uses normal rendered controls only; audit is zero force interaction with no qualifier. |
| `finding_1786518168_150568` Idempotent retry not production-bound | product/medium | **Resolved as entrypoint, then corrected in v4** — production UI only; concurrent dual-context path (see visit 3). |
| `finding_1786518168_278107` Review checklist timeout | process/info | Waived by Plan Review. |

### Visit 3 findings (`review_1786518678_288773`) — fixed in v4

| Finding | Class | Plan response |
| --- | --- | --- |
| `finding_1786518678_326702` Open Web prerequisite not formally registered | product/high | **Fixed** — `ticket_1786518263_839128` is a **mandatory formal PP dependency before Implement**. Engine blocks Plan→Plan Review when the dep is open, so formal re-registration is a **hard gate immediately after Plan Review approval and before any Implement step**. No partial Implement, no harness-only work, no “if desired”. Until the dep is re-registered **and closed** with a consumable Web pin, Implement does not start. |
| `finding_1786518678_274506` Same-workspace retry unreachable after exclusion | product/high | **Fixed** — sequential re-open/re-select after claim is impossible once membership excludes the uuid. **C4 uses two browser contexts on the same workspace**: both open Add, both select `S` via entity_options **before either claim reconciles**, both submit normal controls; distinct `request_id`s; one durable membership; one success + one idempotent same-workspace success (or equivalent pair of valid package outcomes without a second membership row). |

## Context loaded

### Role and stack (required order)

1. [[planner-playbook]]
2. [[botster-planner-playbook]]
3. [[botster-workspaces-playbook]] (exact repository ownership charter)
4. Targeted atomic notes (below)
5. [[project-pipelines-playbook]] — **not loaded for product scope**. This ticket does not edit Project Pipelines package/plugin paths; only delivery process tools are used.

Role / architecture overlays from the planner playbook:

- [[botster-architecture]]
- [[cli-patterns]]
- [[spa-patterns]]
- [[project pipeline orchestration belongs in a device-level botster plugin]]
- [[project pipelines needs an operator workbench not more primitives]]
- [[botster orchestration should spawn agents with explicit target ids]]
- [[botster orchestration prompts must bind agents to explicit worktrees]]
- [[plan agents must author vault context as wikilinks not home paths]]
- [[pipeline vault checklists must cite exact resolvable note titles]]
- [[vault example paths are not repository placement conventions]]
- [[plan review must verify a plan artifact exists before trusting gate summaries]]

### Repository-charter must-load notes

- [[workspaces are semantic groupings by purpose not by branch]]
- [[botster workspace records are plugin owned references not hub authority]]
- [[botster plugin entities are canonical for plugin-owned dynamic state]]
- [[botster package manifests and lockfiles should declare capabilities and provenance]]
- [[botster hub gravity must be watched before it becomes the new monolith]]
- [[acceptance harness region oracles must key on node identity not concatenated text]]
- [[plugin ui action ids are a two site change and hub fails closed on unregistered ids]]
- [[shared hub workspaces acceptance omits package path without skipping its lane]]

### Ticket-specific atomic notes

- [[plugin-owned dynamic state uses plugin-namespaced entity frames]]
- [[plugin entity families publish filterable record supersets]]
- [[package entity hydration uses explicit providers not mcp naming]]
- [[botster hub client state sync is entity frame only]]
- [[session UUID is the sole routing key across all layers]]
- [[conformance harnesses gate on deterministic invariants not timing]]
- [[conformance helpers must dispatch the action id read from the rendered node]]
- [[conformance oracles assert action result frames not toast text]]
- [[closed dependency tickets signal merged source not a consumable release]]
- [[the shared hub browser driver is the live packaged protocol harness behind a shim]]
- [[required smoke modes must disable skips and prove execution positively]]
- [[prefer framework and library components over custom solutions]]
- [[a page reload is not a reconnect]]
- [[botster entity snapshots are authoritative reconnect baselines]]
- [[plugin-owned agent creation uses request_id for async correlation]] (request correlation pattern; claim actions use the same request_id discipline on the SPA path)

Not loaded:

- [[botster runtime teardown lenses]] — ticket is entity-options claim integration, not WebRTC/peer lifecycle, SessionIo/ClientWorker teardown, multi-peer ownership, CPU/battery/FD spin, or terminal-state vs live-runtime divergence class.
- Consumer session-type eligibility parent pin ritual — this ticket is not a consumer of Hub session-type *eligibility* work; it consumes merged entity_options + membership fanout + Available sessions picker artifacts.

### Repository and dependency evidence inspected

Workspaces (this target):

- Pipeline worktree on branch `project-pipelines/ticket_1786474783_285888` was created from an older main tip (`3ec366a…`) and is **behind** `origin/main` by the Available sessions + membership publish stack.
- Authoritative product tip: `origin/main` @ `7ab4d1334214b3ea3c8b02e9ea665a27e70c0916` (includes membership publish `c069900…` / `1752dde…` and Available sessions picker `8db4d68…` / `7ab4d13…`).
- `plugin.lua` on that tip authors Available sessions `entity_options` (`source=/session`, `value_field=session_uuid`, exclude `/botster-workspaces.membership`), advanced historical UUID field, membership index keys, post-commit `botster.entity_publish`, same-workspace idempotency, and typed cross-workspace conflict.
- Prior art: `script/shared_stack_acceptance`, `script/validate_shared_stack_inputs`, `script/hub_acceptance_smoke`, `script/test-hub-flow`, `docs/plans/prove-complete-workspace-browser-tui-hub-spawn-flow.md`, `docs/reports/implement-available-sessions-picker.md`, `docs/workspace-domain.md`.
- Hygiene: restored tracked `.gitignore` from HEAD (was empty/pipeline-wiped). Path has no `:` — no `CARGO_TARGET_DIR` override required for this worktree.

Closed formal dependencies on this ticket (all `depends_on_status=closed`):

| Dependency ticket | Title | Owning target |
| --- | --- | --- |
| `ticket_1786474780_590414` | Workspaces: replace manual session ID entry with an available sessions picker | `tgt_71266a8d976d4535902ffed09c18a7ba` workspaces |
| `ticket_1786474780_865627` | Web: render reactive entity-backed select options | `tgt_40abcf71ccf049f4ac0c99953a799869` web |
| `ticket_1786474781_871159` | TUI: render reactive entity-backed select options | `tgt_c3d470bab78549df920a41e8fb0e58d8` tui |
| `ticket_1786494180_266672` | Hub: package entity mutation fanout and empty snapshot array encoding | `tgt_7e208a0c76a44980a83b63af976b1f22` hub |

Supporting closed siblings (consumed via merges, not re-implemented here):

- Web lifecycle harness entity_options select: `ticket_1786494437_647488` @ Web `2a41220…`
- Workspaces membership publish: `ticket_1786507221_760227` / `ticket_1786507472_103115` on Workspaces main
- Hub entity_options contract: `ticket_1786474779_865884`

Immutable consumer/product pins recorded at Plan time (refresh at Implement; reject dirty checkouts):

| Component | Pin / coordinate |
| --- | --- |
| Workspaces package source | `origin/main` ≥ `7ab4d1334214b3ea3c8b02e9ea665a27e70c0916` |
| Hub binary source | `origin/main` ≥ `de6b09982e72fd5efd04a5258f5fc645f611adbc` (includes fanout `35dd7d2…` / `ea92ec7…` and ui-contract entity_options `891cc79…`/`c6539b6…`) |
| Hub protocol / conformance | `botster-hub-daemon-v1` / package protocol 6 / hub-test-support conf **≥ 35** |
| Web consumer | `origin/main` ≥ `2a412208bc9508f24a57688ec5db94a5519d2573` with `@trybotster/ui-contract@0.3.2` |
| TUI consumer | `origin/main` ≥ `abc804e19bc3e01465cd308c11de5f4292331c3d` with Hub-pinned `botster-ui-contract` |

## Product decision ledger

1. **This run is verification/integration, not product feature design.** Product claim behavior is already merged on Workspaces, Hub, Web, and TUI. This ticket proves the complete campaign on one clean Hub with the real package and production client runtimes.
2. **Model A shared Hub.** One long-lived Hub process, one clean `--data-dir`, packages installed/enabled once from immutable pins. Consumers never start/stop/reinstall the Hub or packages. Sequential Web then TUI (or dual browser contexts for race) against the same durable state is allowed; separate clean-Hub runs are diagnostics only.
3. **Production interaction paths only.** Web: rendered Ionic controls + production transport (entity_options `ion-select`, not fill of hidden aux inputs, not direct action payloads). TUI: keyboard focus/dispatch over production frame + hit map. Action ids, node ids, and values come from realized metadata.
4. **Entity frames are the model channel.** Claim exclusion and restoration travel through Hub `/session` + package `botster-workspaces.membership` authoritative snapshots and ordered upsert/patch/remove. No `list_sessions` polling, surface refresh as sync, or copied Hub lifecycle fields into `plugin.db`.
5. **One-workspace invariant is DB/action truth, not picker-only.** Race two claims → exactly one durable owner, typed conflict for the loser, no duplicate membership keys, pickers reconcile without refresh.
6. **Race participants are production UI only.** Both concurrent claims must be realized production interactions (two browser contexts, **or** one browser context + TUI keyboard path). Package/MCP/tool `add_session`, direct action payloads, and force-interaction are **forbidden** race participants (ticket + Plan Review `finding_1786517672_674450`).
7. **SPA request-state correlation is mandatory on Web.** Each claim records the realized `plugin_surface_action` / action `request_id`, workspace id, exact `session_uuid`, and correlated success or typed-conflict result. The losing result must not clear, overwrite, or misattribute the winning pending request state (`finding_1786517672_735482`). Toast text is not the oracle ([[conformance oracles assert action result frames not toast text]]).
8. **Metadata and live updates are complete, not optional subsets.** When Hub supplies label, lifecycle state, session type, and spawn point, **both Web and TUI** must display them. Held-open dialogs prove **both** a label change **and** a lifecycle change update the open picker without reopening (`finding_1786517672_415822`). “Label and/or lifecycle” is not acceptable.
9. **Same-workspace idempotent claim is concurrent dual-context, not sequential re-select.** Two browser contexts on `W1` select `S` before membership exclusion removes the option, then both submit. Sequential re-select after claim is unreachable. Cross-workspace claim remains typed conflict (C3).
10. **Historical recovery uses the advanced field only when the UUID is absent from current Hub entity state.** Normal path never requires typing an ID.
11. **Reconnect and ordered sequence-gap are separate proofs.**
    - **Reconnect (reachable now):** Web `globalThis.__BOTSTER_LIVE_PROTOCOL_HARNESS__.transportControl.closeDataChannel()` on pin ≥ `2a41220` closes the live WebRTC data channel without page reload ([[a page reload is not a reconnect]]); channel reopens on the same route; authoritative entity snapshots rebaseline ([[botster entity snapshots are authoritative reconnect baselines]]); picker reconciles; stale selection cannot submit via normal controls.
    - **Ordered sequence-gap (blocked on current pins):** Production Web client already resubscribes with reason `sequence_gap` when a delta’s `snapshot_seq ≠ current+1` (`webrtcDaemonClient.receiveEntityFrame`). **No live harness control on Web `2a41220` drops a real inbound frame**; Hub `de6b099` gap tests use `mutation_action` (forbidden for this ticket). Blocking dependency `ticket_1786518263_839128` must land a named real-frame-drop control; only then may Implement run the ordered-gap lane.
12. **Defect routing.** Any failure is owned by the repository that owns the broken layer; open a focused dependency ticket on that target. Do not silently patch Hub/Web/TUI/Core inside this Workspaces run unless the defect is clearly package-owned authoring/persistence/publish.
13. **Closed dependency tickets ≠ release ritual.** Consume exact merged SHAs and real binaries/packages; do not treat “ticket closed” as a substitute for pin-matched live proof ([[closed dependency tickets signal merged source not a consumable release]]).
14. **Deterministic invariants, not timing.** Sleeps may bound waits but never define success ([[conformance harnesses gate on deterministic invariants not timing]]).

## Scope

In scope for `botster-workspaces` in this run:

- Rebase/reset the pipeline worktree onto authoritative Workspaces `origin/main` (≥ Available sessions + membership publish tip) before any proof.
- Add an **opt-in claim integration profile** (preferred: sibling of `script/shared_stack_acceptance`, e.g. `script/claim_stack_acceptance` + input validation, wired from `script/test-hub-flow` or documented standalone entry) that:
  - accepts explicit immutable Hub/Web/TUI/Workspaces/worker paths and revisions;
  - creates one clean Hub data directory;
  - installs/enables the real `botster-workspaces` package (and required client packages/entrypoints as the shared-stack prior art does);
  - creates an **unclaimed running** Hub session outside any workspace;
  - orchestrates the ticket’s Web and TUI claim campaign with durable structured evidence;
  - collates provenance, failure routing, and cleanup while retaining failure evidence.
- Prove the acceptance matrix below with machine-readable ledgers (JSON evidence dir pattern from shared-stack).
- Document the command, required pins, and failure routing in `README.md` (and a short domain cross-ref only if needed).
- Write `docs/reports/prove-available-session-claiming-implement-report.md` with exact pins, commands, ledgers, and residual risks.
- Static/profile contract checks in `script/test` for required inputs/schema of the new profile **without** making the expensive live stack part of the default fast suite.

## Non-scope

- Redesigning Available sessions, membership schema, entity_options contract, Hub fanout ABI, or client entity stores.
- Adding package-specific client code in Web or TUI from this repository.
- `list_sessions` polling, force interaction, direct action payload injection, surface refresh as the reactivity path, or timing-only success.
- Copying Hub session label/lifecycle/session_type/spawn_point into `plugin.db`.
- Broad refactors of existing spawn shared-stack or unrelated package cleanup.
- Project Pipelines package edits, npm publication, or multi-repo monorepo framework invention.
- Runtime-teardown class work.

## Repository ownership boundaries and cross-repo dependencies

### This repository owns

- Workspace membership records, one-workspace invariant, membership entity family publish after commit, owner-authored Available sessions surface, claim/remove actions, package tests, and **the parent orchestration of the multi-client claim campaign**.

### This repository does not own (consume only)

| Layer | Owner charter | Consumed for |
| --- | --- | --- |
| Session identity, lifecycle, `/session` entity frames, package entity fanout, empty `items==[]` encoding | [[botster-hub-playbook]] | Source options, live entity push, empty membership snapshot |
| `entity_options` projection semantics + fixtures | Hub `botster-ui-contract` | Option label/metadata, exclusion, invalidation |
| Browser Ionic render + held-open entity_options demand + lifecycle harness select path | [[botster-web-playbook]] | Real browser claim without typing ID |
| TUI keyboard entity_options select + lifecycle live package path | [[botster-tui-playbook]] / kit | Keyboard claim without package-specific client code |

### Formal ticket dependencies

| Dependency | Title | Target | Status |
| --- | --- | --- | --- |
| `ticket_1786474780_590414` | Workspaces available sessions picker | workspaces | **closed** |
| `ticket_1786474780_865627` | Web entity-backed select | web | **closed** |
| `ticket_1786474781_871159` | TUI entity-backed select | tui | **closed** |
| `ticket_1786494180_266672` | Hub package entity fanout + empty items | hub | **closed** |
| `ticket_1786518263_839128` | Web: live harness drop real entity frames for `sequence_gap` | web `tgt_40abcf71ccf049f4ac0c99953a799869` | **open — mandatory formal dep before Implement** |

Closed deps: Implement re-verifies pins live.

### Formal dependency lifecycle for `ticket_1786518263_839128` (locked)

| Phase | Formal PP edge | Allowed work |
| --- | --- | --- |
| Plan / Plan Review (now) | **Not held open** — engine refuses Plan→Plan Review advance while any ticket dep is open (proved: `request_step_advance` → `ticket_dependencies` on `dependency_1786518268_190390`) | Plan only. No Implement. |
| **Immediately after Plan Review approves** | **Mandatory first action:** `project_pipelines_add_ticket_dependency` this ticket → `ticket_1786518263_839128`. Record new `dependency_id` in Implement gate evidence. | Still no Implement product work. |
| While Web ticket open | Formal edge **present and blocking** | **Zero** claim-stack coding, harness skeleton, non-gap lanes, or “prep” commits. |
| After Web ticket **closed** | Formal edge satisfied; consume Web merge pin + documented frame-drop control name | Full Implement including C6b. |

This is **not** optional. Removing the formal edge after Plan Review approval is a plan violation. Partial Implement before the Web artifact exists is a plan violation.

If other live proof fails:

1. Classify owner (Hub / Workspaces / Web / TUI / pin mismatch).
2. File or re-open a ticket on that repository’s `target_id`.
3. Register it as a blocking dependency on **this** ticket.
4. Do not broaden this run into a silent multi-repo product fix.

#### Live sequence-gap pin audit (Plan visit 3 evidence)

| Surface | Pin | Reachable live trigger? | Notes |
| --- | --- | --- | --- |
| Web harness `transportControl` | `2a41220…` | **Reconnect only** | Only `closeDataChannel()` is exposed (`webrtcDaemonClient` harness install). |
| Web production client | same | Handler exists, no inducer | `receiveEntityFrame` → `resubscribeEntity(..., "sequence_gap")` when seq ≠ current+1. |
| Hub package entity gap tests | `de6b099…` | **Forbidden for this ticket** | `daemon_package_entity_publish_gap_*` uses `mutation_action` fixtures. |
| Client-store `applyEntityFrame` | harness | **Forbidden** | Direct store mutation; not a transport frame drop. |

**Conclusion:** ordered-gap requires Web ticket `ticket_1786518263_839128` (frame-drop control that drops a real inbound WebRTC entity frame, then lets the next real frame drive production `sequence_gap`).

### Sibling consumer harness entrypoints (merged; not reimplemented)

- Web: `npm run smoke:workspaces-lifecycle` and membership-reactive path inside `scripts/live-packaged-protocol-harness.mjs` (`entity_options_select` + advanced historical path; dual-client held-open). Shared-hub driver mode remains caller-owned ([[shared hub workspaces acceptance omits package path without skipping its lane]]).
- TUI: `script/test-live-hub workspaces lifecycle` against real package path.
- Package Hub smoke: `script/test-hub-flow` / `script/hub_acceptance_smoke` (empty membership items, held-open membership publish, concurrent claims).

Supporting consumer proofs already green on closed pins are **necessary but not sufficient**. This ticket still requires one parent-owned clean-Hub campaign that ties Web + TUI + race + historical fallback + reconnect/gap under a single data directory and pin ledger.

## Assumptions and unknowns

### Assumptions

- Workspaces `origin/main` ≥ `7ab4d13…` remains the product tip for Available sessions + membership publish.
- Hub `origin/main` continues to include package entity fanout and empty-items coercion.
- Web `2a41220…` remains the minimal consumer pin for entity_options Add session + membership-reactive dual-client proof.
- TUI `abc804e1…` remains the minimal consumer pin for entity-backed select + workspaces lifecycle.
- Creating an unclaimed running session is possible via Hub spawn/session APIs without assigning workspace membership (existing spawn shared-stack and Hub smoke patterns). Seeding via Hub `spawn` for an **unclaimed** session is allowed; claiming still must go through production UI.
- Race proof uses two workspaces + two **production UI** claim paths only (two browser contexts, or Web + TUI). No package-tool race participant.
- Web harness already correlates action results by `request_id` on other Workspaces paths; claim-stack reuses that discipline for concurrent claim success/conflict.
- Web live harness can close the production WebRTC data channel for reconnect without page reload (`transportControl.closeDataChannel` only).
- Ordered sequence-gap live trigger is **not** available until `ticket_1786518263_839128` merges and is formally depended upon (see Formal dependency lifecycle).
- Same-workspace idempotent proof **cannot** re-select an already-claimed uuid from Available sessions after membership exclusion; concurrent dual-context select-before-reconcile is the production path.

### Unknowns to resolve only if they block Implement

- Exact parent harness shape: new `script/claim_stack_acceptance` vs profile flag on `shared_stack_acceptance`. Prefer a **dedicated claim profile**; reuse shared Hub lifecycle helpers where cheap. **Only after** Web dep is closed.
- Whether TUI live lifecycle already exercises claim-via-entity_options keyboard path for an *unclaimed external* session — ablate after Web dep closes.
- Display metadata presence: Hub may omit `label` / `spawn_point`; assert four fields when present.
- Exact frame-drop control name from `ticket_1786518263_839128` implement report.

If Implement discovers product code needed in Web/TUI/Hub beyond orchestration (except consuming the registered gap-trigger dependency), stop and register the correct dependency rather than guessing.

## Affected surfaces / files (expected)

| Path | Expected role |
| --- | --- |
| `docs/plans/prove-available-session-claiming-across-hub-web-tui.md` | This Plan artifact |
| `script/claim_stack_acceptance` (or equivalent name) | Parent claim campaign harness |
| `script/validate_claim_stack_inputs` (optional) | Immutable pin/input validation |
| `script/test-hub-flow` / `script/test` | Wire opt-in profile + static schema checks |
| `README.md` | Document claim integration command and pins |
| `docs/reports/prove-available-session-claiming-implement-report.md` | Implement evidence |
| `docs/workspace-domain.md` | Touch only for a verification cross-ref if useful |
| `plugin.lua`, `botster-package.json`, domain schema | **Expected unchanged** unless proof isolates a package-owned defect |

## Risks

| Risk | Mitigation |
| --- | --- |
| Worktree base predates Available sessions | First Implement step: hard sync to Workspaces `origin/main` ≥ `7ab4d13…` |
| Piecemeal green consumer smokes but no single shared-Hub story | Parent harness owns one data-dir and full matrix |
| Timing-only or list_sessions false green | Forbidden methods list; assert request counts / frame kinds / membership keys |
| Race flakiness | Two production-UI claim launches; DB membership key uniqueness; typed conflict; SPA request_id correlation; not sleeps-as-success |
| Package tool used as second race path | Explicitly forbidden; dual browser contexts or Web+TUI only |
| SPA request miscorrelation | Per-request_id success/conflict oracles; loser must not clear winner |
| Mis-owned fixes | Explicit routing table; no silent Web/TUI patches in this repo |
| Shared-hub “package path omitted” log mistaken for skip | Require positive mode markers and completion ledger ([[shared hub workspaces acceptance omits package path without skipping its lane]], [[required smoke modes must disable skips and prove execution positively]]) |
| Advanced fallback becomes the normal path | Assert primary claim uses entity_options select; advanced only for intentionally absent Hub state |
| Stale selection after claim / after gap | Held-open picker becomes invalid/cleared; **normal** submit control cannot emit outbound claim; zero force interaction |
| Page-reload treated as reconnect | Forbidden; only `transportControl.closeDataChannel` for reconnect on current Web pin |
| Ordered-gap claimed without frame-drop control | Blocked on `ticket_1786518263_839128`; do not substitute store mutation, package action, or reconnect alone |

## Acceptance checks / tests

### A. Preconditions

1. Worktree product tree = Workspaces pin ≥ `7ab4d13…` (or newer main that contains that ancestry).
2. `.gitignore` has HEAD content (12 lines at Plan visit 2; no dirty diff). Re-restore with `git checkout HEAD -- .gitignore` if wiped again.
3. Explicit path/revision inputs for Hub, session-worker, Web, TUI, Workspaces package; dirty/mismatched revisions fail closed.
4. Fresh Hub `--data-dir`; install + enable real `botster-workspaces` package; `packages show` proves provenance.

### B. Package / Hub substrate (may reuse existing smokes as supporting lanes)

1. `script/test` green on package tree.
2. `script/test-hub-flow` / hub smoke green: empty membership `items == []`, membership publish on claim/remove, concurrent claim uniqueness, entity_options descriptor present on Add form.
3. Supporting only: package/MCP tool `add_session` may seed diagnostics or prove package invariant in isolation, but **never** counts as browser/TUI interaction proof and **never** participates in the dual-claim race.

### C. Parent claim campaign (required product path)

One clean Hub. Create unclaimed running session `S` outside any workspace (Hub spawn seed is OK). Create workspaces `W1` and `W2`. Optionally seed a second unclaimed session `S2` when sequencing needs an independent claim target after `S` is owned.

#### C1. Web path (production browser, held-open)

1. Open Workspaces surface and W1 Add dialog; hold it open.
2. Observe `S` appear in Available sessions through `/session` entity snapshot/upsert **without** surface refresh or typing an ID.
3. **Metadata present matrix:** when Hub supplies them, assert the option projects **all four**: primary label, lifecycle state, session type, and spawn point (uuid fallback only when label is absent). Record which fields were present in Hub entity data.
4. Select `S` via entity_options control; submit through realized `botster_workspaces.add_session` with exact `session_uuid`.
5. Record action evidence: realized action id, node id, workspace id, exact `session_uuid`, and action `request_id` correlated to the accepted result.
6. Prove `S` joins **exactly** `W1`; membership key exists once; option disappears from held-open pickers via membership entity change without `plugin_surface_render` used as sync.
7. **Live updates (both required, not and/or):** while the Add dialog (or membership-visible surface) remains open without reopening:
   - patch Hub **label** for `S` → option/label display updates from entity frames;
   - patch Hub **lifecycle** for `S` → lifecycle display updates from entity frames.
8. Remove membership from `W1`; prove `S` reappears on Available sessions without refresh.
9. **Stale-selection (no force interaction):** after exclusion, the held draft selection clears or marks invalid through production UI state. Use only the **normal** rendered submit control (enabled or disabled as production presents it). Prove **no successful outbound** `plugin_surface_action` / claim request carries the excluded `session_uuid`. Do **not** use Playwright `force: true`, synthetic clicks on disabled controls, direct action payloads, or store injection.

#### C2. TUI path (production keyboard, held-open)

1. Against the same Hub, open the owner-authored Workspaces surface; open Add for a workspace that does not own the target session (after Web removal of `S`, or using `S2`).
2. **Metadata present matrix (parity with Web):** when Hub supplies label, lifecycle state, session type, and spawn point, the compact TUI option display shows all four; when a field is absent, record absence rather than inventing it.
3. Keyboard-select Available sessions option; dispatch the **realized** action id / node id from the hit map; prove exact `session_uuid` submission (no synthesized id).
4. Prove membership join, exclusion, and remove→restore through entity frames without `list_sessions` polling.
5. **Live updates (both required):** with the Add form/dialog still open (no reopen), prove **both** label and lifecycle entity patches update the TUI option presentation without a surface refresh used as synchronization.

#### C3. Race (production UI only + SPA request-state)

**Participants (locked):**

- **Required primary race:** two concurrent claims for the same unclaimed session from `W1` and `W2` through **two production browser contexts** (P1 and P2), each submitting via realized Ionic entity_options + `botster_workspaces.add_session`.
- **Optional additional race:** Web context vs TUI keyboard claim for the same unclaimed session (still both production UI). Useful for cross-client coverage; does not replace the dual-browser SPA request-state race when Web holds two pending claims.
- **Forbidden race participants:** package/MCP/tool `add_session`, direct action payload injection, force-interaction that bypasses rendered controls, list_sessions-driven claim.

**Database / membership oracles:**

- Exactly one durable owner workspace; one typed conflict for the loser; no duplicate `membership:<session_uuid>` keys; both pickers reconcile without surface refresh.

**Web SPA request-state oracles (required):**

- Capture each browser’s outbound claim `request_id` (or equivalent correlated action request identity) at submit time with `{ workspace_id, session_uuid, request_id }`.
- Prove exactly one correlated **success** result and one correlated **typed conflict** result, each bound to the correct `request_id`.
- Prove the losing result does **not** clear, overwrite, or misattribute the winning request’s pending/accepted state (no cross-talk between the two pending requests).
- Structured action-result frames are the oracle; toast/copy is not ([[conformance oracles assert action result frames not toast text]]).

#### C4. Idempotent same-workspace retry (production UI — concurrent dual context)

**Why sequential retry is invalid:** After a successful claim, `S` is excluded from Available sessions via `botster-workspaces.membership`. A later re-open of Add **cannot** entity_options-select `S` again. Sequential “claim then claim again from the picker” is **unreachable** and must not appear as a success path.

**Entrypoint (locked):** two production **browser contexts** on the **same** workspace `W1` (not two workspaces — that is the C3 race).

1. Create unclaimed running session `S`. Create workspace `W1`.
2. Context A: open W1 Add dialog; wait for entity_options option `S`; select `S` via normal Ionic control. **Do not wait for membership exclusion yet.**
3. Context B: open W1 Add dialog (same workspace); wait for option `S`; select `S` via normal control. Both selections complete **before either claim’s membership exclusion has removed `S` from both pickers** (select-before-reconcile window, same pattern as dual-client membership-reactive holds).
4. Submit both forms through **normal** rendered submit controls (near-concurrent; no force, no package tool, no direct action payload).
5. Oracles:
   - distinct correlated `request_id` R1 and R2;
   - same `workspace_id` = `W1` and same exact `session_uuid` = `S` on both requests;
   - package outcomes are **two valid results** covering success + same-workspace idempotent success (typed success twice, or success + idempotent no-op success — whatever the package returns for same-workspace reclaim), **not** a cross-workspace conflict;
   - exactly one durable `membership:<S>` key owned by `W1`;
   - no second membership row; pickers eventually exclude `S` on both contexts via entity frames.
6. Forbidden: re-selecting `S` after it has already disappeared from options; package/MCP second claim; force interaction.

**Contrast with C3 race:** C3 uses two workspaces `W1`/`W2` → one owner + typed conflict. C4 uses one workspace twice → one owner + idempotent second success.

#### C5. Historical advanced fallback

End and remove a session from current Hub entity state so it is absent from `/session` options. Recover membership only through the advanced historical UUID field with the exact uuid, using **normal** field fill + normal submit. Prove validation of the exact session_uuid. Prove this is not the normal Available sessions path.

#### C6. Reconnect (reachable now) and ordered change-gap (blocked until Web dependency)

**Clients under test:** at minimum **Web** production client with held-open Available sessions / membership demand.

##### C6a. Web reconnect — named, reachable on pin ≥ `2a41220`

1. Establish entity_options demand (subscribe `/session` + `botster-workspaces.membership`).
2. Hold a draft selection of a live option without page reload.
3. Call the **only** exposed harness transport control on this pin:
   ```js
   globalThis.__BOTSTER_LIVE_PROTOCOL_HARNESS__.transportControl.closeDataChannel()
   ```
   Source: `src/botster/webrtcDaemonClient.ts` harness install (`closeDataChannel` → `closeDataChannelForLiveHarness`). **Not** a page reload ([[a page reload is not a reconnect]]).
4. Wait for the data channel to reopen on the same Workspaces route (in-page reconnect).
5. Require evidence of:
   - resync / generation signal (fresh subscription id / reconnect generation);
   - **authoritative replacement entity_snapshot** for required families ([[botster entity snapshots are authoritative reconnect baselines]]);
   - reconciled Available sessions option set;
   - stale selection invalid/cleared so **normal** submit cannot send a successful claim for a dead value (zero force interaction).

##### C6b. Ordered sequence-gap — blocked until `ticket_1786518263_839128`

**Pin audit result (Plan visit 3):** no reachable live sequence-gap inducer exists on Web `2a41220` or Hub `de6b099` without forbidden seams.

**Production path that must be hit after the dependency merges:**

1. Web client already implements: if delta `snapshot_seq !== currentSequence + 1`, call `resubscribeEntity(..., "sequence_gap")` (`webrtcDaemonClient.receiveEntityFrame`).
2. Dependency must add a harness control that **drops one real inbound Hub entity frame** on the WebRTC path before production apply, then allows the next real frame so the production `sequence_gap` branch runs.
3. After merge, Implement records the **exact control name** from that ticket’s implement report and uses only that control.

**Ordered-gap oracles (when unblocked):**

1. Pre-gap last sequence for the demanded family; control drops one real frame; next frame arrives.
2. Harness/client evidence: discard with reason `sequence_gap` + resubscribe.
3. Authoritative replacement snapshot; reconciled picker; normal-control stale-selection rejection (no force).

**Forbidden gap substitutes (never green):**

- `applyEntityFrame` / client-store injection;
- Hub/test `mutation_action` package fixture as the claim-stack gap trigger;
- counting `closeDataChannel` reconnect alone as sequence-gap proof;
- direct package/MCP action payloads.

**TUI (when exercised):** production reconnect that is not cold-start-only; ordered-gap only if a named TUI-or-shared transport drop seam exists after the Web dependency (do not invent a second owner without a ticket).

#### C7. Forbidden methods audit

Evidence ledger shows **all** of:

- zero `list_sessions` used as picker source;
- **zero force interaction** (no qualifier, no “unless sole path”);
- zero surface-refresh-as-sync for claim exclusion/restore;
- zero package-specific client branches;
- zero package-tool / MCP / direct-action participants in claim, race, retry, or gap lanes;
- zero timing-only pass criteria;
- zero page-reload-as-reconnect;
- zero client-store injection as gap or stale-selection proof.

#### C8. Node-identity oracles

Region/control location uses realized `data-ui-node-id` / TUI node ids, not concatenated heading text ([[acceptance harness region oracles must key on node identity not concatenated text]]). Action ids come from realized nodes ([[conformance helpers must dispatch the action id read from the rendered node]]).

### D. Downstream consumer re-check (pin-matched)

Re-run closed consumer proofs against the same Workspaces pin as supporting evidence and record SHAs:

- Web: `BOTSTER_WORKSPACES_PACKAGE_PATH=<pin> npm run smoke:workspaces-lifecycle` on Web ≥ `2a41220…` (includes membership-reactive dual-client + stale-submit — supporting, not a substitute for C3 dual-browser race request-state oracles).
- TUI: `BOTSTER_WORKSPACES_PACKAGE_PATH=<pin> script/test-live-hub workspaces lifecycle` on TUI ≥ `abc804e1…`

Parent campaign failure beats supporting green.

### E. Production entry-point statement (required in implement report)

Document: Workspaces app surface → Add existing session → Available sessions entity_options (or advanced historical when absent) → realized `botster_workspaces.add_session` with correlated `request_id` → membership batch + `entity_publish` → generic Web/TUI entity stores update open pickers; reconnect baselines replace entity stores from authoritative snapshots. Code existence alone is insufficient.

## Implementation sequence

1. **Plan Review approves this plan.** No Implement agent work before step 2–3 complete.
2. **Mandatory formal dependency re-registration (first post-approval action):**  
   `project_pipelines_add_ticket_dependency(ticket_1786474783_285888 → ticket_1786518263_839128)`.  
   Record `dependency_id` in run evidence. If re-registration fails, stop and escalate — do not Implement without the formal edge.
3. **Wait until `ticket_1786518263_839128` is closed** and a consumable Web pin exists with the documented real-frame-drop control. **No claim-stack code, harness skeleton, non-gap lanes, docs-only “prep”, or partial Implement while open.**
4. Sync worktree to Workspaces `origin/main` (≥ Available sessions tip). Re-read product pins including the Web frame-drop pin.
5. Record full immutable pin ledger (Hub/Web/TUI/Workspaces/worker/ui-contract + frame-drop control name).
6. Implement the full claim-stack campaign (C1–C8 including C4 dual-context idempotent path and C6a/C6b) as one Implement effort — not a pre-gap skeleton then later C6b.
7. Wire documentation and static schema checks; keep expensive live profile opt-in.
8. Run package tests, hub flow, parent claim campaign, supporting consumer smokes.
9. On failure, route defect tickets by ownership; do not waive live proof.
10. Write implement report with pins, commands, ledgers, formal `dependency_id`, gap-control name, forbidden-methods audit, and residual risks.

## Vault gaps worth capturing

1. **Multi-client claim campaign pattern** — parent-owned clean Hub proving Available sessions across Web + TUI + dual-browser race + historical fallback (spawn shared-stack is prior art; claim matrix is new).
2. **Membership exclude family + entity_options product pattern** — first production pairing of `/session` source with plugin membership exclude.
3. **Advanced historical field vs normal entity_options path** — when each is valid proof vs product anti-pattern.
4. **Closed dependency vs pin-matched live integration** — “all deps closed” never substitutes for one shared data-dir proof.
5. **Dual-browser claim race + SPA request_id correlation** — concurrent `add_session` requests must keep pending request state distinct (success vs typed conflict).
6. **In-page WebRTC data-channel reconnect vs page reload** for entity_options pickers holding draft selection across authoritative snapshot resync.

## Plan completion hygiene

- Exactly one vault checklist for **this** Plan visit (visit 4). Prior checklists stay historical.
- Gate evidence must include `plan_uri`, `artifact_id`, `checklist_id`, `target_id`, `target_repository` together.
- `.gitignore` verified: 12 lines; clean.
- `teardown_class_applies: false`.
- Product findings from `review_1786518678_288773` addressed in v4.
- Formal PP dep on `ticket_1786518263_839128` is **not** held during this Plan→Plan Review hop (engine limitation). **Mandatory re-add after Plan Review approval** is part of the product plan, not optional process hygiene.
