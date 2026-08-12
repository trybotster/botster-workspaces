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

## Review revisit (sequence 15) — open findings map

| Finding | Resolution |
| --- | --- |
| `finding_1786556015_658761` C6a package-tool before disconnect | Close data channel first; peer claims S2 via second production browser while offline; recon subscription/snapshot pairs remove S2. |
| `finding_1786556015_455384` C6b invalidates before drop | Warm membership; arm drop; peer-claim held A (dropped); gap-trigger C; gap recovery clears A. |
| `finding_1786556015_140462` Snapshots not sub-correlated | Export subscribe_id → later family-matched entity_snapshot pairs; parent asserts pairs. |
| `finding_1786556015_304715` C1 joined text as label | Dedicated producer label tracking; `label=false` / `label_live_update=false` when Hub omits label. |
| `finding_1786556015_646464` TUI negative control tautology | `assert_sha256_match!` fails closed on fabricated digest. |

## Prior reviews — resolved

Sequence 13 (typed conflict, TUI bind, etc.) and sequence 10 (normal Ionic, race oracles, pins) findings remain resolved.

## Playbooks / notes applied

1. [[implementer-playbook]]
2. [[botster-implementer-playbook]]
3. [[botster-workspaces-playbook]]
4. [[project-pipelines-playbook]] (gate/artifact handoff only)
5. Plan v4 acceptance matrix for C1–C6 and typed conflict

## Files changed (this revisit)

| Path | Role |
| --- | --- |
| `script/claim_stack_web_driver.mjs` | C6a disconnect-first peer claim; C6b arm-before-held-claim; sub/snapshot pairs; C1 producer-label |
| `script/claim_stack_acceptance` | Pair asserts; TUI digest checker negative control |
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
# evidence: /private/tmp/claim-stack-evidence-reviewfix15e-1786556751
# status=passed
```

| Lane / check | Result |
| --- | --- |
| C1 live appear + session_type + lifecycle live update + restore | passed (`label=false` without producer label) |
| C2 TUI shared-Hub keyboard claim (validated binary) | passed (`membership_join` + `option_excluded`) |
| C3 accept + exact `session_already_owned` + dual picker reconcile | passed |
| C4 accept + idempotent | passed |
| C5 historical | passed |
| C6a disconnect-first production peer claim + sub/snapshot pairs + zero stale | passed |
| C6b arm-before-held-claim + gap recovery + sub/snapshot pairs + zero stale | passed |
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
