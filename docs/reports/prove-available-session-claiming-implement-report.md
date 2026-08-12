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
| Workspaces HEAD | (this report commit) |
| TUI claim pin | **merged** `f2bc11fc8c0b14b57ebcf9b6ace4f1d80565720f` on `botster-tui` main (PR #52) |
| TUI ticket | `ticket_1786559993_989665` (closed, merge confirmed) |

## Merge-block revisit (post-Verify)

Verify approved at `32d34a1`, then direct merge blocked. This Implement pass addresses both blockers.

| Blocker | Resolution |
| --- | --- |
| `git merge-tree` conflict in `test/plugin_runtime_test.lua` vs main `7db06a6` | Merged `origin/main`; kept structured `session_already_owned` action-error coverage; wrapped late fixtures for Lua 200-local limit; aligned smoke with main’s non-UUID session-id validation and `Historical session ID` label. |
| Plan C2.5 TUI held-open lifecycle | Routed as owning TUI ticket `ticket_1786559993_989665` + [PR #52](https://github.com/trybotster/botster-tui/pull/52), **squash-merged to main** at `f2bc11f`. Parent re-ran claim-stack on the merged pin (not a branch-only artifact). |

## Playbooks / notes applied

1. [[implementer-playbook]]
2. [[botster-implementer-playbook]]
3. [[botster-workspaces-playbook]]
4. [[project-pipelines-playbook]] (gate/artifact handoff)
5. Plan v4 product decision 8 (held-open label + lifecycle on Web and TUI)

## Files changed (this revisit)

| Path | Role |
| --- | --- |
| `test/plugin_runtime_test.lua` | Merge resolution; typed conflict action-error tests; local-limit wrap |
| `script/claim_stack_acceptance` | Require TUI `lifecycle_live_update` (C2.5) |
| `script/hub_acceptance_smoke` | Align with main advanced label + blank-id validation |
| `docs/reports/...implement-report.md` | This report |
| **TUI** `96823e0` (separate repo branch) | Claim driver held-open lifecycle proof + process-wide session projection |

## Ownership boundaries

- Workspaces owns package semantics, parent claim-stack, and merge resolution.
- TUI claim-driver lifecycle stage is a TUI consumer seam (`project-pipelines/claim-held-open-lifecycle` @ `96823e0`); consumed via pin, not edited inside Workspaces product code.

## Cross-repo routing

| Item | Status |
| --- | --- |
| Prior Hub/Web/TUI deps | closed |
| TUI claim driver held-open lifecycle | **closed** `ticket_1786559993_989665` / merged `f2bc11f` via [PR #52](https://github.com/trybotster/botster-tui/pull/52) |

## Tests and proof

```sh
script/test
# ok

git merge-tree --write-tree origin/main HEAD
# clean

script/claim_stack_acceptance … EVIDENCE_DIR
# ok evidence=/private/tmp/claim-stack-evidence-merged-tui-1786560081
# status=passed
# TUI pin = merged main f2bc11f (not a branch tip)
```

| Check | Result |
| --- | --- |
| C1 Web held-open lifecycle | passed |
| C2 TUI keyboard claim + **C2.5 lifecycle_live_update** on **merged** TUI main | passed |
| C3–C6b | passed |
| merge-tree vs main | clean |

## Residual risk

- Hub still omits dedicated session `label` / `spawn_point` on the claim-stack Hub pin; label_live_update stays false when absent.

## Missing vault guidance

- Parent multi-client claim campaign pattern
- TUI claim-driver held-open lifecycle stage for Available sessions
