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
| Functional HEAD | `406935cc164043fe0435271cf8df1c673a60a45f` |
| Report HEAD | (this commit) |

## Review revisit (sequence 19) — open findings map

| Finding | Resolution |
| --- | --- |
| `finding_1786557814_874424` C6a records offline state but does not require it | Driver fails unless `offline_at_peer_claim.channel_still_closed` is true after peer claim. Requires exact `webrtc_data_channel` closed event (no lifecycle heuristic). Parent asserts both. Recovery baseline and exact ready correlation retained. |
| `finding_1786557814_865834` PR still links sequence-15 evidence | PR test plan updated to reviewfix19 evidence and current heads. |

## Prior reviews — resolved

Sequence 17 (offline order, real ready correlation, spawn_point label exclusion), sequence 15, sequence 13, and sequence 10 findings remain resolved.

## Playbooks / notes applied

1. [[implementer-playbook]]
2. [[botster-implementer-playbook]]
3. [[botster-workspaces-playbook]]
4. [[project-pipelines-playbook]] (gate/artifact handoff only)
5. Plan v4 acceptance matrix for C1–C6 and typed conflict

## Files changed (this revisit)

| Path | Role |
| --- | --- |
| `script/claim_stack_web_driver.mjs` | Hard-fail C6a when channel reopens before peer-claim proof; exact `webrtc_data_channel` closed only |
| `script/claim_stack_acceptance` | Assert `offline_at_peer_claim.channel_still_closed` and exact closed kind |
| `docs/reports/...implement-report.md` | This report |

## Ownership boundaries

- Workspaces owns package claim semantics, parent claim-stack harness, and surface projection authoring.
- Web/TUI/Hub product code not edited in this worktree.

## Cross-repo dependencies

| Ticket | Status |
| --- | --- |
| Prior Hub/Web/TUI/Workspaces deps | closed |
| `ticket_1786518263_839128` Web frame-drop | closed |
| `ticket_1786529885_807584` TUI shared-Hub claim | closed at `d40f28f9de2b621e50367c0f014880429eddedde` |

## Deviations

1. Hub `/session` entities still omit dedicated `label` and `spawn_point` on the current Hub pin.
2. Web `hub_frame` entity_snapshot projections omit wire `subscription_id`; correlation uses `webrtc_entity_subscription` ready events.

## Tests and proof

```sh
script/test
# ok

script/claim_stack_acceptance /private/tmp/claim-stack-pins-12563/inputs-reviewfix13.json EVIDENCE_DIR
# script/claim_stack_acceptance: ok
# evidence: /private/tmp/claim-stack-evidence-reviewfix19-1786557883
# status=passed
```

| Lane / check | Result |
| --- | --- |
| C1 live appear + session_type + lifecycle | passed |
| C2 TUI shared-Hub keyboard claim | passed |
| C3/C4/C5 | passed |
| C6a exact closed + channel_still_closed + S2 held + ready pairs + zero stale | passed |
| C6b arm-before-held-claim + ready pairs + zero stale | passed |
| Supporting Web/TUI lifecycle | passed |

## Residual risk

- C6a offline window still depends on prepare-first peer claim completing before recon reconnects; hard fail if channel reopens first (correct fail-closed).

## Missing vault guidance

- Parent multi-client claim campaign pattern
- Web hub_frame entity projections strip wire subscription correlation; harness ready events are the durable parent claim-stack correlation surface
