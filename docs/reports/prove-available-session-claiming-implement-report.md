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
| Workspaces HEAD | `99af334627214a196ac3586d34b253ddf6bf9af6` (+ report commit) |
| TUI pin | **merged main** `f2bc11fc8c0b14b57ebcf9b6ace4f1d80565720f` |
| TUI ticket | `ticket_1786559993_989665` closed; PR https://github.com/trybotster/botster-tui/pull/52 |

## Review sequence 22 findings

| Finding | Resolution |
| --- | --- |
| `finding_1786560016_120690` unmerged TUI `96823e0` | Owning TUI ticket `ticket_1786559993_989665` + PR #52 **squash-merged to main** as `f2bc11f`. Parent dependency closed. Claim-stack re-run on **merged** pin only. |
| `finding_1786560016_885276` no surface_render_delta assert | Parent `parse_tui_claim_evidence!` requires `surface_render_delta == 0` and ordered `option_present` < `lifecycle_live_update` < `add_session`. |
| `finding_1786560016_963541` missing Implement report artifact | This report + `project_pipelines_add_artifact` for sequence 23. |

## Playbooks / notes applied

1. [[implementer-playbook]]
2. [[botster-implementer-playbook]]
3. [[botster-workspaces-playbook]]
4. [[project-pipelines-playbook]]
5. Plan v4 product decision 8 (held-open Web and TUI lifecycle)

## Files changed (this visit)

| Path | Role |
| --- | --- |
| `script/claim_stack_acceptance` | C2.5: require `surface_render_delta=0` + ordered option/lifecycle/add |
| `docs/reports/...implement-report.md` | This report |

## Ownership boundaries

- Workspaces owns parent claim-stack oracles only.
- TUI product claim-driver stage owned by closed TUI ticket / merged main `f2bc11f`.

## Cross-repo routing

| Dependency | Status |
| --- | --- |
| Prior Hub/Web/TUI deps | closed |
| `ticket_1786559993_989665` TUI held-open lifecycle | **closed**, merge `f2bc11f` |

## Tests and proof

```sh
script/test  # ok

git merge-tree --write-tree origin/main HEAD  # clean

script/claim_stack_acceptance … EVIDENCE
# ok evidence=/private/tmp/claim-stack-evidence-seq23-1786560318
# status=passed
# TUI pin=f2bc11fc8c0b14b57ebcf9b6ace4f1d80565720f (merged main)
```

| Check | Result |
| --- | --- |
| C2.5 lifecycle_live_update on merged TUI | passed |
| surface_render_delta == 0 | enforced + live green |
| option_present < lifecycle < add_session | enforced + live green |
| C1–C6b remaining lanes | passed |

## Residual risk

- Hub still omits dedicated session `label` / `spawn_point` on claim-stack Hub pin; label_live_update stays false when absent.

## Missing vault guidance

- Parent multi-client claim campaign pattern
- TUI claim-driver held-open lifecycle stage for Available sessions
