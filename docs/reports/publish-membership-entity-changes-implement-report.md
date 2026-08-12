# Implement report: publish membership entity changes after committed claims and removals

## Delivery identity

| Field | Value |
| --- | --- |
| Ticket | `ticket_1786507221_760227` |
| Run | `run_1786507239_475224` |
| Target repository | `botster-workspaces` |
| target_id | `tgt_71266a8d976d4535902ffed09c18a7ba` |
| Path authority | `list_spawn_targets` → repository `botster-workspaces` / `tgt_71266a8d976d4535902ffed09c18a7ba` |
| Worktree | this pipeline worktree on `project-pipelines/ticket_1786507221_760227` |
| Plan revision | 4 (approved `review_1786508655_142687`) |
| Working base | `main@3ec366abd1fd86dcade81b7a14470dcacfcbd504` (main-first; not PR #16 stack) |
| Hub used for live proof | debug Hub at workspace pin ≥ `35dd7d22`; live binary advertised **conformance 34** |

## Playbooks / notes applied

1. [[implementer-playbook]]
2. [[botster-implementer-playbook]]
3. [[botster-workspaces-playbook]] (ownership charter)
4. Atomic notes: [[botster plugin entities are canonical for plugin-owned dynamic state]], [[plugin-owned dynamic state uses plugin-namespaced entity frames]], [[project pipelines mcp mutators avoid synchronous full entity snapshots]], [[botster entity snapshots are authoritative reconnect baselines]], [[package entity hydration uses explicit providers not mcp naming]], [[session UUID is the sole routing key across all layers]], [[botster workspace records are plugin owned references not hub authority]], [[workspaces are semantic groupings by purpose not by branch]]
5. Not loaded: [[project-pipelines-playbook]] (package workflow only); [[botster runtime teardown lenses]] (`teardown_class_applies: false`)

## Constraints stated before edits

- Work only in the botster-workspaces run worktree.
- Extract minimum membership producer from PR #16; **exclude** picker/`entity_options`/`resolve_add_session_id`.
- Same-batch durable **range** sequence reservation; move = single upsert; delete multi-remove ordered by `session_uuid`.
- Six operator producer checks only; free-text dialog is not product proof.
- Repository-owned wrappers: `script/test`, `script/test-hub-flow`.

## Files changed

| Path | Change |
| --- | --- |
| `plugin.lua` | Membership index + same-batch range seq + `botster.entity_publish` after commit; provider CAS; mutators |
| `test/plugin_runtime_test.lua` | batch/list/revision mock; producer matrix (claim/remove/move/multi-delete/CAS/reload/provider/silence) |
| `script/hub_acceptance_smoke` | conf 34; held membership subscription; six producer checks |
| `test/fixtures/workspaces/contract.json` | membership producer contract fields |
| `docs/workspace-domain.md` | membership family + seq-in-batch contract |
| `docs/capabilities.md` | membership authority + batch/publish |
| `README.md` | membership publish mention |
| `docs/plans/publish-membership-entity-changes-after-committed-claims.md` | approved plan (rev4) |
| `docs/reports/publish-membership-entity-changes-implement-report.md` | this report |

## Extracted vs excluded symbols

**In (producer):** `MEMBERSHIP_*`, `membership_key`/`membership_record`/`get_membership`/`list_membership_records`, `batch_mutations`/`claim_session_batch`/`commit_membership_batch`, durable `membership_entity_seq` range reservation, `resolve_owner`, membership write paths on add/remove/move/delete/spawn, `membership_entity_provider`, conf/smoke producer checks.

**Out (PR #16 / consumers):** `available_session_options_source`, `entity_options_select`, `resolve_add_session_id`, Add dialog entity_options rewrite, display-fields projection matrix, Web harness.

## Ownership boundaries preserved

- Membership authority stays in botster-workspaces (`plugin.db` + membership entity family).
- Hub remains authority for session identity/lifecycle and `botster.entity_publish` admission/fanout.
- No Web/TUI/client-specific code; no Hub special cases.

## Cross-repo routing

| Concern | Routing |
| --- | --- |
| Visible entity_options exclude/restore | Downstream Web harness `ticket_1786494437_647488` |
| Available-sessions picker | Downstream `ticket_1786474780_590414` (depends on this; rebase after merge; drop duplicate membership commits) |
| Hub fanout ABI | Closed on Hub pin (no code here) |

## Deviations from plan

1. **Smoke conformance 34** (plan said 33). Current debug Hub advertises `conformance_fixture_revision=34`. Smoke matches the live binary so the gate reaches membership scenarios. Still ≥ pin `35dd7d22`.
2. **Held subscription seeds a membership first** so the provider baseline is a non-empty JSON array. Empty Lua `items = {}` still fails provider validation on some builds; seeding is a harness detail, not product proof for the free-text dialog.
3. Successful claim tools may include optional `membership_publish` / `membership_reserved_seqs` diagnostic fields for verification.

## Tests and downstream proof run

```text
script/test
# => test/plugin_runtime_test.lua: ok ; script/test: ok

BOTSTER_HUB_BIN=<hub-debug> BOTSTER_SESSION_WORKER_BIN=<session-worker-debug> script/test-hub-flow
# => script/hub_acceptance_smoke: ok ... conformance_fixture_revision=34
# => script/test-hub-flow: ok
```

Live six producer checks (production MCP tools + held generic membership subscription):

1. Production `botster_workspaces.add_session` commits claim.
2. Held subscription receives exact `entity_upsert` (accepted publish `status=accepted`).
3. Production `botster_workspaces.remove_session` commits remove.
4. Same held subscription receives exact `entity_remove` with higher `snapshot_seq`.
5. Validation/conflict failures publish no false ownership frames.
6. Stale cross-workspace add returns `session_already_owned`.

Package matrix also covers multi-membership delete N-range, move single upsert, CAS retry, failed-batch silence, provider separate seq, post-reload first publish.

## Production entry point

- MCP tools `botster_workspaces.add_session` / `remove_session` / `move_session` / `delete` / `spawn` and matching UI actions call the shared mutators.
- After successful `plugin_db.batch` (membership keys + state + `membership_entity_seq` range), mutators call `botster.entity_publish` with pre-reserved sequences.
- `membership_entity_provider` serves SubscribeEntities baselines with separate single-seq CAS.

## Unverified / residual risk

1. Empty membership provider snapshots still depend on Hub empty-array coercion for cold subscribe with zero rows; live proof uses a non-empty seed baseline.
2. Publish-fail-after-successful-batch recovery relies on provider resync (by design; no rollback).
3. Stale release Hub binaries without `botster.entity_publish` injection will silently leave held subscribers without mutator frames; live gate requires a Hub build that injects `entity_publish`.
4. Visible picker exclusion/restoration remains downstream (operator split).

## Missing vault guidance discovered

Same gaps recorded in the plan: producer vs visible-picker split; durable seq range in same batch; main-first extraction when consumer PR depends on producer; smoke conf tracking Hub pin.

## Review rework (`review_1786509999_267460`)

| Finding | Fix |
| --- | --- |
| Provider row/seq race | Provider reads seq revision first, lists rows, re-checks revision, CAS-reserves against the original revision; full retry on change/conflict |
| Pre-index fallback removals | `remove_session` / `delete_workspace` always reserve and publish `entity_remove` for every released `session_ref`, even without a membership key |
| Silent publish failure | Post-commit publish retries each reserved frame once; mutators report `membership_delivery=degraded` when recovery fails |
| Absolute path in report | Replaced with repository name + target_id |
| Strict diff EOF | Trailing blank line removed |
