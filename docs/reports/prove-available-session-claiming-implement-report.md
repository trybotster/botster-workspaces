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

## Review revisit (sequence 11) — open findings map

| Finding | Resolution |
| --- | --- |
| `finding_1786529668_628714` Browser claims bypass normal interaction | Ionic option select via control click + overlay option click; submit via Playwright `locator.click` only. Removed value assignment, synthetic ionChange, and `evaluate(node.click())`. |
| `finding_1786529668_405039` Parent omits TUI claim | Routed owner ticket `ticket_1786529885_807584` (TUI target) and formal dependency `dependency_1786529892_674521`. No public shared-Hub TUI claim keyboard seam exists on pin `abc804e1` (lifecycle seeds via MCP). |
| `finding_1786529668_291049` Race/retry oracles weak | Parent asserts C3 one accept + one typed conflict (`session_already_owned`/rejected), C4 two valid outcomes with uniqueness of membership row, picker reconciliation on both contexts. |
| `finding_1786529668_423711` C1 omits live picker behavior | Open dialog first; spawn session after; assert live appear; lifecycle live update via shutdown while held open; claim; exclude; remove membership while open; restore option. |
| `finding_1786529668_607826` Reconnect weak | Document sentinel, pre-close counters, require post-close subscribe + snapshot generation, same-document proof, picker reconcile. |
| `finding_1786529668_806414` Sequence-gap string match | Require drop state, sequence_gap tail evidence, resubscribe count increase, replacement snapshot increase, stale-held A outbound check. |
| `finding_1786529668_491758` Pins not enforced | `git merge-base --is-ancestor MINIMUM ACTUAL` on each validated source checkout. |
| `finding_1786529668_641456` Historical removal fails open | Fail-closed remove path + authoritative `list_sessions` absence before C5. |
| `finding_1786529668_709447` Whitespace | Stripped trailing spaces on plan/report; `git diff --check` clean. |

## Playbooks / notes applied

1. [[implementer-playbook]]
2. [[botster-implementer-playbook]]
3. [[botster-workspaces-playbook]]
4. Charter and ticket notes from plan v4 (entity frames, conformance oracles, no force interaction, node-identity, shared-hub acceptance)

## Files changed (this revisit)

| Path | Role |
| --- | --- |
| `script/claim_stack_web_driver.mjs` | Normal Ionic interaction; C1 live matrix; C3 picker reconcile; C6a/C6b generation oracles |
| `script/claim_stack_acceptance` | Pin ancestry, historical fail-closed, typed C3/C4 membership uniqueness oracles, C1 spawn ownership |
| `script/test` | Guards against synthetic force paths; pin ancestry + typed conflict tokens |
| `docs/reports/...implement-report.md` | This report |
| `docs/plans/...` | Whitespace hygiene |

## Ownership boundaries

- Workspaces owns parent claim campaign orchestration only.
- Web/TUI/Hub product code not edited.
- TUI shared-Hub keyboard claim is a separately routed owner ticket on `tgt_c3d470bab78549df920a41e8fb0e58d8`.

## Cross-repo dependencies

| Ticket | Status |
| --- | --- |
| Prior closed Hub/Web/TUI/Workspaces deps | closed |
| `ticket_1786518263_839128` Web frame-drop | closed (`dependency_1786518942_244198`) |
| **`ticket_1786529885_807584` TUI shared-Hub claim** | **open** (`dependency_1786529892_674521`) |

## Deviations

1. Full parent TUI keyboard claim on the shared Hub waits on `ticket_1786529885_807584` (routed, not waived).
2. Bare Hub spawn sessions may omit dedicated `label`/`session_type`/`spawn_point` fields; C1 records which fields Hub supplies and proves lifecycle (+ derived label text) live update via `shutdown_session`.

## Tests and proof

```sh
script/test
# ok

script/test-hub-flow claim-stack run MANIFEST EVIDENCE_DIR
# script/claim_stack_acceptance: ok
# evidence: /private/tmp/claim-stack-evidence-reviewfix3-1786530294
```

| Lane / check | Result |
| --- | --- |
| C1 live appear + lifecycle update + restore | true |
| C3 accept + typed conflict | accepted + `session already belongs to workspace` |
| C4 accept + idempotent | accepted + accepted/idempotent |
| C5/C6a/C6b | completed |
| Supporting Web lifecycle | passed |
| Supporting TUI lifecycle | passed (not shared-Hub keyboard claim) |

Head `370862b…` on PR #18.

## Production entry point

Workspaces surface → Add existing session → Available sessions entity_options (real Ionic select) → realized `botster_workspaces.add_session` → membership publish → generic clients reconcile open pickers; reconnect via `closeDataChannel`; ordered gap via `armDropNextInboundEntityFrame`.

## Residual risk

- TUI same-Hub claim blocked on new dependency.
- Live re-run of tightened oracles must be green before Review re-approval.

## Missing vault guidance

- Parent multi-client claim campaign pattern
- Web lifecycle forbids caller-owned data dir; claim parents need dedicated drivers
- Per-SPA `ui-action-N` request ids are not globally unique across browser contexts
