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
| HEAD | `a416b5876c86d6b24b8199a74432de3793166e0d` (+ report commit) |

## Review revisit (sequence 17) — open findings map

| Finding | Resolution |
| --- | --- |
| `finding_1786557124_364819` C6a offline peer-claim order | Prepare peer browser before `closeDataChannel`; require closed `webrtc_data_channel` event; prove S2 still on disconnected picker after peer claim; set recovery baseline only after that offline proof; then require post-baseline subscribe+ready pairs that remove S2. Chronology recorded in evidence. |
| `finding_1786557124_897243` Snapshot correlation fabricates subscription id | Pair `subscribe_entities` with later `webrtc_entity_subscription` `state=ready` that carries real wire `subscription_id`, `generation`, and `snapshot_seq`. Do not copy the request id into missing hub_frame snapshot fields (projections strip those fields). Parent asserts `subscription_id_exact=true` and generation/snapshot_seq present. |
| `finding_1786557124_483911` spawn_point as producer label | Exclude `metadata.spawn_point` from dedicated producer-label candidates. |

## Prior reviews — resolved

Sequence 15 (disconnect-first, arm-before-held-claim, producer-label honesty, TUI digest negative control), sequence 13 (typed conflict, TUI bind), and sequence 10 findings remain resolved.

## Playbooks / notes applied

1. [[implementer-playbook]]
2. [[botster-implementer-playbook]]
3. [[botster-workspaces-playbook]]
4. [[project-pipelines-playbook]] (gate/artifact handoff only)
5. Plan v4 acceptance matrix for C1–C6 and typed conflict

## Files changed (this revisit)

| Path | Role |
| --- | --- |
| `script/claim_stack_web_driver.mjs` | C6a offline order + closed/peer/recovery chronology; real ready correlation for C6a/C6b; spawn_point excluded from producer label |
| `script/claim_stack_acceptance` | Offline chronology asserts; `subscription_id_exact` + generation/snapshot_seq required |
| `docs/reports/...implement-report.md` | This report |

## Ownership boundaries

- Workspaces owns package claim semantics, parent claim-stack harness, and surface projection authoring.
- Web/TUI/Hub product code not edited in this worktree.
- Correlation uses Web harness events already present on the pin (`webrtc_entity_subscription` ready) without fabricating missing hub_frame fields.
- TUI claim keyboard seam consumed from closed `ticket_1786529885_807584` at `d40f28f…`.

## Cross-repo dependencies

| Ticket | Status |
| --- | --- |
| Prior Hub/Web/TUI/Workspaces deps | closed |
| `ticket_1786518263_839128` Web frame-drop | closed |
| `ticket_1786529885_807584` TUI shared-Hub claim | closed at `d40f28f9de2b621e50367c0f014880429eddedde` |

## Deviations

1. Hub `/session` entities still omit dedicated `label` and `spawn_point` fields on the current Hub pin. C1 requires `lifecycle` and `session_type_id` (via `spawn_session_type`) and proves independent lifecycle attribute updates. Independent producer-label live-update is asserted only when Hub supplies a distinct label field.
2. Web `hub_frame` entity_snapshot projections intentionally omit wire `subscription_id` / rename `snapshot_seq` → `sequence`. Correlation uses `webrtc_entity_subscription` ready events (same harness ledger) rather than inventing snapshot fields or routing a new Web ticket.

## Tests and proof

```sh
script/test
# ok

script/claim_stack_acceptance /private/tmp/claim-stack-pins-12563/inputs-reviewfix13.json EVIDENCE_DIR
# script/claim_stack_acceptance: ok
# evidence: /private/tmp/claim-stack-evidence-reviewfix17-1786557486
# status=passed
```

| Lane / check | Result |
| --- | --- |
| C1 live appear + session_type + lifecycle live update + restore | passed (`label=false` without producer label; spawn_point excluded from label candidates) |
| C2 TUI shared-Hub keyboard claim (validated binary) | passed |
| C3 accept + exact `session_already_owned` + dual picker reconcile | passed |
| C4 accept + idempotent | passed |
| C5 historical | passed |
| C6a peer-prepared offline claim + closed event + S2 held + post-baseline ready pairs + zero stale | passed (`subscription_id_exact=true`, real generation/snapshot_seq) |
| C6b arm-before-held-claim + gap recovery + ready pairs + zero stale | passed (`subscription_id_exact=true`, real generation/snapshot_seq) |
| Supporting Web/TUI lifecycle | passed |

TUI pin floor: `d40f28f9de2b621e50367c0f014880429eddedde` (`botster.tui.workspaces-claim-driver/v1`).

Live C6a chronology (reviewfix17 evidence): closed event_index=70 → S2 still present after peer claim → recovery_baseline event_count=74 → session/membership ready pairs with exact subscription ids and generation=2.

## Production entry point

Workspaces surface → Add existing session → Available sessions entity_options (real Ionic select) → realized `botster_workspaces.add_session` (structured error codes on conflict) → membership publish → generic clients reconcile open pickers; C2 TUI keyboard claim on same Hub via package entrypoint bound to validated `tui_binary`; reconnect via `closeDataChannel`; ordered gap via `armDropNextInboundEntityFrame`.

## Residual risk

- Hub still does not project a dedicated session `label` or `spawn_point` on bare or session-type entities in the claim-stack pin set; metadata matrix is limited to fields Hub actually supplies.
- C6a offline window depends on peer being prepared before disconnect; a very slow peer claim could still race a fast reconnect (mitigated by prepare-first; oracle is S2 still on picker after peer claim).

## Missing vault guidance

- Parent multi-client claim campaign pattern
- UI action_error must preserve structured error codes for SPA/harness typed conflict proof
- Package `apps open` entrypoint bytes must bind to the validated consumer binary, not only pin ancestry
- Web hub_frame entity projections strip wire subscription correlation; harness ready events are the durable correlation surface for parent claim-stack
