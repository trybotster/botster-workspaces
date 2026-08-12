# Workspaces: publish membership entity changes after committed claims and removals

## Plan revision

| Field | Value |
| --- | --- |
| Revision | **4** — Plan Review rework |
| Addresses | `review_1786508473_283320` finding `finding_1786508473_202475`; preserves rev2–rev3 locks |
| Operator answers | `question_1786507822_112625` (main-first); `question_1786507734_845414` (authoritative); `question_1786508223_721040` (split acceptance) |

### Finding disposition

| Finding | Class | Status |
| --- | --- | --- |
| Circular PR #16 base | product/high | **Fixed rev2** — main-first extraction |
| Free-text dialog as product proof | product/high | **Fixed rev3** — six operator producer checks only |
| Sequence after membership commit | product/high | **Fixed rev3** — seq reserved in same batch as membership |
| Multi-frame / multi-row seq | product/medium (rev3→rev4) | **Fixed rev4** — atomic **range** reservation of N consecutive seqs for N frames; publish in deterministic order; move = single upsert |
| Reload-safe sequence source | product/high | **Fixed rev2–4** |
| Conf 31 vs 33 | product/medium | **Fixed rev2** — bump to 33 |
| `.gitignore` | infra/info | Keep restored HEAD; not product |

## Delivery identity

| Field | Value |
| --- | --- |
| Ticket | `ticket_1786507221_760227` |
| Authority | Authoritative producer (operator). Duplicate closed. |
| Target repository | `botster-workspaces` |
| target_id | `tgt_71266a8d976d4535902ffed09c18a7ba` |
| Path authority | `list_spawn_targets` (not ambient cwd alone) |
| Run | `run_1786507239_475224` |
| Plan visit | `run_step_1786508487_108754` (sequence 7) |
| Charter | [[botster-workspaces-playbook]] |
| **Working base** | **`main` only** @ `3ec366abd1fd86dcade81b7a14470dcacfcbd504` |
| Hub pin | ≥ `35dd7d222d491b4203bc5251d44ca9b5ec6c5e42` (conf **33**) |
| Downstream dependents | Available-sessions `ticket_1786474780_590414`; Web harness `ticket_1786494437_647488` (both depend on this) |

## Repository playbook loaded

- [[botster-workspaces-playbook]]

## Other role/surface playbooks and atomic notes loaded

1. [[planner-playbook]]
2. [[botster-planner-playbook]]
3. [[botster-workspaces-playbook]]
4. Charter notes: [[workspaces are semantic groupings by purpose not by branch]], [[botster workspace records are plugin owned references not hub authority]], [[botster plugin entities are canonical for plugin-owned dynamic state]], [[package entity hydration uses explicit providers not mcp naming]], [[plugin-owned dynamic state uses plugin-namespaced entity frames]], [[project pipelines mcp mutators avoid synchronous full entity snapshots]], [[botster entity snapshots are authoritative reconnect baselines]], [[acceptance readiness requires the exact expected entity not any authoritative snapshot]], [[session UUID is the sole routing key across all layers]]
5. Process: [[plan agents must author vault context as wikilinks not home paths]], [[pipeline vault checklists must cite exact resolvable note titles]], [[vault example paths are not repository placement conventions]]

**Not loaded:** [[project-pipelines-playbook]]; [[botster runtime teardown lenses]] (`teardown_class_applies: false`)

## Context loaded

- Ticket: publish `botster-workspaces.membership` after committed claims/removals via `botster.entity_publish`.
- Operator main-first extraction (no PR #16 stack; no full picker absorption).
- Operator **split acceptance** (`question_1786508223_721040`): free-text dialog is **not** product proof; six producer checks here; Web harness owns visible entity_options exclude/restore.
- Baseline: `script/test` pass on main; hub-flow fails conf 31 vs Hub 33 until smoke bump.
- Hub fanout closed; PR #16 has membership without publish.

## Product decision ledger (locked)

### 1. Integration base

- Branch **`main` only**. Forbidden: stack on PR #16.

### 2. Minimum extraction from PR #16 (producer only)

**In:** `MEMBERSHIP_*` constants; `membership_key` / `membership_record` / `get_membership` / `list_membership_records`; `batch_mutations` / `claim_session_batch`; revision-aware `load_state` / `persist_state`; `resolve_owner`; `add_session` / `remove_session` write paths; minimum membership-key maintenance on `move_session` / `delete_workspace` / successful `spawn_session` (one write implementation); `membership_entity_provider` registration; conf 33 smoke + producer tests; surgical docs.

**Out (PR #16 / consumers):** `available_session_options_source`, `entity_options_select`, `resolve_add_session_id` / advanced UUID field, Add dialog entity_options rewrite, display-fields projection matrix, Web harness fill.

**Stop condition:** If extraction requires any Out symbol → stop and report; no silent stack.

### 3. Entity family

- `botster-workspaces.membership`; record `{ id, session_uuid, workspace_id }` with `id = session_uuid`
- Hot path: `entity_upsert` / `entity_remove` via `botster.entity_publish` after successful batch
- No full-family snapshot on mutator hot path; no Hub session fields in membership rows

### 4. Durable sequence — **same transaction as membership** (rev3) + **range for multi-frame** (rev4)

| Rule | Decision |
| --- | --- |
| Counter key | Durable `plugin.db` key e.g. `membership_entity_seq` payload `{ next_seq: <uint> }` where `next_seq` is the **last committed** sequence (high water of reserved values). |
| Frames per mutator | Compute the ordered list of frames the mutation will emit **before** the batch (see §4a). Let `N = #frames` (`N ≥ 1` for real membership changes; `N = 0` for pure no-ops → no seq advance, no publish). |
| **Atomic range reservation** | **Before** batch: `get` counter → `revision` + `last = next_seq`. Reserve range `(last+1) … (last+N)`. Include **in the same `plugin_db.batch`** as all membership key writes (+ workspace_state): single `set membership_entity_seq` with `expected_revision` and payload `{ next_seq = last+N }`. One CAS advances the floor by **N**, not by 1. |
| After batch **success only** | Emit exactly those N frames with `snapshot_seq = last+1, last+2, …, last+N` in the **precomputed frame order**. Never allocate extra seqs after commit. Never re-number. |
| Batch failure | Zero membership change, zero seq change, **zero publish**. |
| CAS | On `revision_conflict`, retry whole attempt (reload membership + state + seq, recompute frame list and range). |
| Forbidden | (a) Membership commit then separate seq write; (b) reserve only 1 seq when N>1 frames; (c) allocate additional seqs after commit for remaining removes. |
| Provider snapshots | **Separate** path: allocate **one** new durable seq via own CAS (`last+1`) for the whole-family snapshot baseline. Never invent a seq ≤ durable `next_seq`. Concurrent provider vs mutator CAS tested. |
| Reload | Hub reload keeps family floor. Durable counter survives worker reload. First post-reload mutator range admits without `stale_sequence` / `duplicate_sequence`. |
| Publish fail after batch | Membership + reserved range committed. Do not roll back. May retry **same** reserved seqs once; do not re-allocate. Provider resync recovers held clients. |

#### 4a. Frame sets by mutator (locked)

| Mutator | Frames emitted (N) | Order | Notes |
| --- | --- | --- | --- |
| **add_session** (new claim) | 1 × `entity_upsert` for claimed `session_uuid` | — | Same-workspace pure idempotent with no durable write: **N=0**. Repair path that actually batches: N=1 upsert. |
| **remove_session** | 1 × `entity_remove` for removed `session_uuid` | — | |
| **move_session** | **N=1** × `entity_upsert` with destination `workspace_id` (id = session_uuid). **Not** remove+upsert. | — | Avoids transient free flash between remove and upsert; exclude family still shows session claimed. |
| **delete_workspace** | **N = count of released membership keys** × `entity_remove` | **Ascending `session_uuid` string order** (deterministic) | Range-reserve N in same batch as all membership deletes + workspace delete. Multi-membership delete test required. |
| **spawn_session** success | 1 × `entity_upsert` after membership batch commits (same rules as claim) | — | Only if membership write succeeds. |

Move rationale (explicit): membership entity id is `session_uuid` (1:1). Changing owner is an **upsert of the same id** with new `workspace_id`, not a remove. That matches the exclude family’s “claimed vs free” semantics and needs only one reserved seq.

### 5. Split acceptance boundary (`question_1786508223_721040`) — **six producer checks**

**This producer ticket must prove (live Hub / package path):**

1. A real **claim** commits through the **production** Workspaces action (`botster_workspaces.add_session` tool and/or registered UI action `botster_workspaces.add_session` — production handlers, not a test-only shim).
2. A **held generic** membership subscription receives the **exact** `entity_upsert` without reconnect or resubscribe.
3. A real **removal** commits through the **production** Workspaces action (`botster_workspaces.remove_session` tool and/or UI action).
4. The **same** held subscription receives the **exact** `entity_remove` **or** truthful empty state (last membership → remove + later provider empty `items == []`).
5. Failed and conflicting writes publish **no false state** (zero publish on batch fail, conflict loser, validation fail).
6. A **stale add** attempt is rejected by the **server invariant** (`session_already_owned` / equivalent) after concurrent claim — request-state proof without claiming UI option lists.

**Explicitly not product proof for this ticket:**

- Opening main’s free-text Add dialog
- Describing held subscription frames as “visible exclusion” or “visible restoration” of picker options
- Requiring PR #16 entity_options code in this run

**Downstream (already depend on this ticket; no reverse edge):**

| Ticket | Must prove after this merges |
| --- | --- |
| Web harness `ticket_1786494437_647488` | Actual **entity_options** picker **visibly** excludes and restores session while held open |
| Available-sessions `ticket_1786474780_590414` | Consumes producer merge before final verification; picker workflow only after rebase |

## Scope

### In scope

1. Main-based minimum membership producer extraction (tables above).
2. Same-batch durable **range** seq reservation (N frames → advance counter by N) + post-success publish of those reserved seqs in order.
3. Locked frame sets for add / remove / **move (single upsert)** / **delete multi-remove** / spawn.
4. entity_provider with separate single-seq allocation rules.
5. Conf 33 smoke compatibility.
6. Package + live Hub proofs for the **six operator producer checks** + post-reload first publish + concurrent CAS + **multi-membership delete range** + move single-upsert.
7. Surgical docs for membership producer + publish contract.
8. Delivery note: merge this first; rebase PR #16; drop duplicate membership commits.

### Non-scope

- Free-text dialog as product proof; entity_options picker UX; PR #16 stack; Web harness implementation; Hub fanout ABI; full-family snapshots on mutators; client-specific code; dual membership write implementations.

## Repository ownership boundaries and cross-repo dependencies

| Concern | Owner |
| --- | --- |
| Membership index, family, same-batch seq, entity_publish after commit | **This package / ticket** |
| entity_options visible exclude/restore | Web harness + available-sessions (depend on this) |
| `botster.entity_publish` admission/fanout | Hub (closed pin) |

No reverse depends-on Web/picker (cycle). No new cross-repo code here.

## Assumptions and unknowns

### Assumptions

1. MCP/UI production actions for add/remove are sufficient for checks 1 and 3 without dialog UI.
2. Membership write path separable from picker symbols.
3. Hub reload retains `last_accepted_seq`; durable seq required.
4. `plugin_db.batch` admits multi-key CAS including the seq key in one atomic batch (capability already used for membership+state on PR #16).

### Unknowns (resolve in Implement with tests)

1. Exact payload field name for seq key — pick one (`next_seq` as last committed), document, test.
2. Provider snapshot concurrent with multi-frame mutator — require monotonic admission green.

## Affected surfaces/files

| Path | Change |
| --- | --- |
| `plugin.lua` | Membership producer extract; same-batch **range** seq reservation; multi-frame publish order; move single upsert; delete multi-remove; provider separate seq CAS |
| `test/plugin_runtime_test.lua` | Six producer checks + batch fail silence + conflict silence + concurrent CAS + post-reload + **multi-membership delete N removes with consecutive seqs** + move N=1 upsert |
| `script/hub_acceptance_smoke` | conf 33; six live producer checks; held generic membership sub; multi-delete if practical on live path |
| `script/test-hub-flow` | inherits |
| `test/fixtures/workspaces/contract.json` | producer contract fields |
| `docs/workspace-domain.md`, `README.md`, `docs/capabilities.md` | membership + publish + seq-in-batch |
| `docs/plans/publish-membership-entity-changes-after-committed-claims.md` | this plan |

## Risks

| Risk | Mitigation |
| --- | --- |
| Treating free-text dialog as picker proof | Operator split; six checks only |
| Seq write after membership (stale held sub) | Seq range in same batch |
| Multi-remove with one seq / post-commit alloc | Range reserve N; publish last+1…last+N only |
| Move remove+upsert flash | Locked single upsert |
| Dual membership writes after PR #16 rebase | Single path here; PR #16 drops dupes |
| Extraction pulls picker | Stop condition |
| Publish fail after successful batch | Reserved range durable; resync; no rollback |
| Conf mismatch | conf 33 first |

## Acceptance checks/tests

### Baseline

```sh
script/test
BOTSTER_HUB_BIN=… BOTSTER_SESSION_WORKER_BIN=… script/test-hub-flow
# Hub ≥ 35dd7d22; smoke CONFORMANCE_FIXTURE_REVISION = 33; must reach membership scenarios
```

### Package-local

| Case | Assert |
| --- | --- |
| Claim batch includes seq | Successful add batch writes membership + counter `next_seq=last+1`; one upsert with that seq |
| Remove batch includes seq | Same for single remove |
| **Multi-membership delete** | Workspace with ≥2 memberships deleted: one batch advances counter by **N**; N `entity_remove` publishes with consecutive seqs in ascending `session_uuid` order; no post-commit seq alloc |
| **Move single upsert** | Move emits exactly one upsert (new workspace_id); counter +1; no remove frame; no transient free |
| Final empty | Last remove → remove frame; provider empty `items` |
| Failed batch silence | No membership change, no seq advance, no publish |
| Conflict loser silence | `session_already_owned`; no publish from loser |
| Idempotent same-workspace | No net write → N=0, no publish |
| Concurrent CAS | Parallel claims: one winner; seq monotonic; loser silent |
| Seq-after-commit forbidden | Design forbids separate seq write / post-commit range fill |
| Post-reload first publish | After package reload: next claim/remove admits without stale/duplicate; held sub converges |
| Provider vs mutator | Provider snapshot seq allocation separate, still monotonic |

### Live Hub — **six operator producer checks** (production path)

```text
P1: SubscribeEntities botster-workspaces.membership (held open; generic subscription)
P2: production add_session action/tool claims S  → batch(membership + seq) → entity_publish upsert
P1: receives exact entity_upsert for S without reconnect/resubscribe          # checks 1–2
P1: production add_session(S) → server rejects session_already_owned         # check 6
P2: production remove_session action/tool removes S → batch → entity_publish remove
P1: receives exact entity_remove (or empty truth after last) without resubscribe  # checks 3–4
Additionally: forced batch/conflict failures → zero false publish             # check 5
```

**Do not** claim free-text Add dialog open as exclusion/restoration proof.

### Downstream (not this gate)

- Web harness: visible entity_options exclude/restore while picker held open.
- Available-sessions: consume this merge before final verification.

## Implementation steps

1. Base `main`; keep restored `.gitignore`.
2. Conf 33 smoke bump; prove hello against Hub pin.
3. Extract minimum membership producer (exclude picker table).
4. Implement same-batch **range** seq reservation + ordered multi-frame publish; move single upsert; delete multi-remove; provider separate CAS.
5. Package tests (matrix above), including multi-membership delete and move.
6. Live smoke: six producer checks + post-reload + conf 33 (+ multi-delete if harness allows).
7. Surgical docs; implement report lists extracted vs excluded symbols and SHAs.
8. After merge: PR #16 rebases and drops duplicate membership commits.

## Vault gaps

1. Split producer vs visible picker proof boundaries.
2. Durable entity seq reserved in same batch as mutation (not after).
3. Multi-frame mutations reserve a consecutive range of size N in that batch.
4. Main-first extraction when consumer PR depends on producer.
5. Smoke conf must track Hub pin.

## Completion evidence

| Field | Value |
| --- | --- |
| plan_uri | `docs/plans/publish-membership-entity-changes-after-committed-claims.md` |
| target_id | `tgt_71266a8d976d4535902ffed09c18a7ba` |
| target_repository | `botster-workspaces` |
| repository_playbook | [[botster-workspaces-playbook]] |
| teardown_class_applies | false |
| plan_revision | 4 |
| checklist | reuse run vault checklist (no duplicate) |
| artifact_id | this visit’s `project_pipelines_add_artifact` |
