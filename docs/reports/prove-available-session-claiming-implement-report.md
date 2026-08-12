# Implement report: prove available session claiming across Hub, Workspaces, Web, and TUI

## Target repository and target_id

| Field | Value |
| --- | --- |
| Target repository | `botster-workspaces` (`trybotster/botster-workspaces`) |
| Target ID | `tgt_71266a8d976d4535902ffed09c18a7ba` |
| Ticket | `ticket_1786474783_285888` |
| Run | `run_1786516676_981514` |
| Branch | `project-pipelines/ticket_1786474783_285888` |
| PR | https://github.com/trybotster/botster-workspaces/pull/18 |
| Approved plan | `docs/plans/prove-available-session-claiming-across-hub-web-tui.md` (v4) |
| Runtime-teardown class | **Does not apply** |

## Review revisit (sequence 13) — open findings map

| Finding | Resolution |
| --- | --- |
| `finding_1786554647_435150` C3 typed conflict | `action_error` preserves structured `{code,message}`; parent requires exact `session_already_owned` (no generic rejected/error fallback); C3 picker reconcile fails closed on both contexts. |
| `finding_1786554647_382628` C6a/C6b stale record-only | Make held value unavailable (claim elsewhere / peer claim); driver + parent require `stale_outbound_*=0`. |
| `finding_1786554647_908614` Generation not family-correlated | C6a/C6b counters keyed by daemon `entity_type` for `session` and `botster-workspaces.membership`. |
| `finding_1786554647_379849` Metadata incomplete | C1 uses `spawn_session_type` so `session_type_id` projects; require lifecycle attribute live-update independently; do not double-count lifecycle text as label_live_update. |
| `finding_1786554647_848417` Unvalidated TUI binary | Bind validated `tui_binary` SHA-256 into package `target/debug/botster-tui` before `apps open`; binding receipt + pre-open recheck. |
| `finding_1786554647_723357` Stale report/PR | This report + PR body updated for C2 and closed TUI pin. |

## Prior review (sequence 10) — already resolved

Nine findings from `review_1786529668_558495` remain resolved (normal Ionic interaction, TUI dependency, race oracles, C1 live path, reconnect/gap strength, pin ancestry, historical fail-closed, whitespace).

## Playbooks / notes applied

1. [[implementer-playbook]]
2. [[botster-implementer-playbook]]
3. [[botster-workspaces-playbook]]
4. [[project-pipelines-playbook]] (gate/artifact handoff only)
5. Plan v4 acceptance matrix for C1–C6 and typed conflict

## Files changed (this revisit)

| Path | Role |
| --- | --- |
| `plugin.lua` | `action_error` keeps structured `error.code` / `error.message` |
| `script/claim_stack_web_driver.mjs` | C1 session-type spawn + independent lifecycle; C3 fail-closed picker; C6a/C6b family counters + zero stale outbound |
| `script/claim_stack_acceptance` | Typed C3 code; mandatory picker/C6 asserts; TUI executable binding |
| `test/plugin_runtime_test.lua` | UI action path preserves `session_already_owned` code |
| `docs/reports/...implement-report.md` | This report |

## Ownership boundaries

- Workspaces owns package claim semantics, parent claim-stack harness, and surface projection authoring.
- Web/TUI/Hub product code not edited in this worktree.
- TUI claim keyboard seam consumed from closed `ticket_1786529885_807584` at `d40f28f…`.

## Cross-repo dependencies

| Ticket | Status |
| --- | --- |
| Prior Hub/Web/TUI/Workspaces deps | closed |
| `ticket_1786518263_839128` Web frame-drop | closed |
| `ticket_1786529885_807584` TUI shared-Hub claim | closed at `d40f28f9de2b621e50367c0f014880429eddedde` |

## Deviations

1. Hub `/session` entities still omit dedicated `label` and `spawn_point` fields on the current Hub pin. C1 requires `lifecycle` and `session_type_id` (via `spawn_session_type`) and proves independent lifecycle attribute updates. Independent producer-label live-update is asserted only when Hub supplies a distinct label field.

## Tests and proof

```sh
script/test
# ok

script/test-hub-flow claim-stack run MANIFEST EVIDENCE_DIR
# script/claim_stack_acceptance: ok
# evidence: /private/tmp/claim-stack-evidence-reviewfix13e-1786555551
# status=passed
```

| Lane / check | Result |
| --- | --- |
| C1 live appear + session_type + lifecycle live update + restore | passed |
| C2 TUI shared-Hub keyboard claim (validated binary) | passed (`membership_join` + `option_excluded`) |
| C3 accept + exact `session_already_owned` + dual picker reconcile | passed |
| C4 accept + idempotent | passed |
| C5 historical | passed |
| C6a reconnect family generation + zero stale outbound | passed |
| C6b sequence_gap membership family + zero held-A outbound | passed |
| Supporting Web/TUI lifecycle | passed |

TUI pin floor: `d40f28f9de2b621e50367c0f014880429eddedde` (`botster.tui.workspaces-claim-driver/v1`).

## Production entry point

Workspaces surface → Add existing session → Available sessions entity_options (real Ionic select) → realized `botster_workspaces.add_session` (structured error codes on conflict) → membership publish → generic clients reconcile open pickers; C2 TUI keyboard claim on same Hub via package entrypoint bound to validated `tui_binary`; reconnect via `closeDataChannel`; ordered gap via `armDropNextInboundEntityFrame`.

## Residual risk

- Hub still does not project a dedicated session `label` or `spawn_point` on bare or session-type entities in the claim-stack pin set; metadata matrix is limited to fields Hub actually supplies.
- Family-correlated counters depend on harness ledger `entity_type` tagging for `subscribe_entities` / `entity_snapshot` frames.

## Missing vault guidance

- Parent multi-client claim campaign pattern
- UI action_error must preserve structured error codes for SPA/harness typed conflict proof
- Package `apps open` entrypoint bytes must bind to the validated consumer binary, not only pin ancestry
