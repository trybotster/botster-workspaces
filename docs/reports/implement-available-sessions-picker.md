# Implement report: Available sessions picker (rebased on producer main)

## Target repository and target_id

- **Target repository:** `botster-workspaces` (`trybotster/botster-workspaces`)
- **target_id:** `tgt_71266a8d976d4535902ffed09c18a7ba`
- **Base:** `origin/main` at producer merge `c069900` (membership publish after committed mutations)
- **Branch:** `project-pipelines/ticket_1786474780_590414` / PR 16
- **teardown_class_applies:** false

## Context refresh (instruction from producer merge)

1. Authoritative producer ticket closed at `c069900` — membership `entity_publish` after claims/removes is on main.
2. This branch was **reset onto `origin/main`** and re-applied **picker-only** product changes (no duplicate producer publish stack).
3. Remaining formal blocker: Web harness `ticket_1786494437_647488` (still open). Do not bypass.
4. Hub empty-array + fanout dep `ticket_1786494180_266672` is closed.

## Playbooks applied

- [[implementer-playbook]]
- [[botster-implementer-playbook]]
- [[botster-workspaces-playbook]]
- Membership publish already owned by closed sibling `ticket_1786507221_760227` on main — not reimplemented here.

## Files changed (picker delta on top of main)

| Path | Change |
| --- | --- |
| `plugin.lua` | entity_options Available sessions select + advanced historical UUID; form precedence for `add_session_action` |
| `script/hub_acceptance_smoke` | Assert entity_options descriptor; advanced historical claim path; keep main held-open membership publish proofs |
| `test/plugin_runtime_test.lua` | Picker authoring + advanced precedence matrix |
| `test/fixtures/workspaces/contract.json` | Picker contract fields |
| `README.md` / `docs/workspace-domain.md` | Picker UX docs |
| `docs/plans/...` / `docs/reports/...` | Plan + this report |

## Ownership

- Picker is package UI authoring only; consumers stay generic.
- Membership publish remains main's producer implementation (`botster.entity_publish`).
- No Hub/Web/TUI repo edits in this worktree.

## Cross-repo

| Dep | Status |
| --- | --- |
| Hub entity_options | closed |
| Web entity_options render | closed |
| TUI entity_options render | closed |
| Hub package fanout + empty array (`ticket_1786494180_266672`) | **closed** |
| Workspaces membership publish producer (`ticket_1786507221_760227`) | **closed** (merged `c069900`) |
| Web lifecycle harness entity_options Add (`ticket_1786494437_647488`) | **open** — sole formal advance blocker |

## Deviations

- Branch rewritten onto main to drop duplicate producer code; PR 16 history may require force-push.
- Web Workspaces lifecycle package mode still blocked on open harness ticket (IonSelect fill). TUI lifecycle previously green against picker package; re-verify after Web closes if needed.

## Tests

```sh
script/test
# ok

BOTSTER_HUB_BIN=<hub-debug> BOTSTER_SESSION_WORKER_BIN=<worker-debug> script/test-hub-flow
# re-run after commit
```

## Residual risk

- Web lifecycle harness still text-input shaped until `ticket_1786494437_647488` closes.
- Ready to re-run Web lifecycle and request Review advance immediately when that dep closes.
