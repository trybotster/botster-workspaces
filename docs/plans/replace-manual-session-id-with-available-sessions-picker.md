# Workspaces: available sessions picker

## Delivery identity

- Ticket: `ticket_1786474780_590414` — Workspaces: replace manual session ID entry with an available sessions picker
- Target repository: `botster-workspaces` (`trybotster/botster-workspaces`)
- Target ID: `tgt_71266a8d976d4535902ffed09c18a7ba`
- Repository charter: [[botster-workspaces-playbook]]
- Pipeline run: `run_1786480494_395040`
- Plan visits: `run_step_1786480496_733711` (initial), `run_step_1786481300_183135` (v2), `run_step_1786492304_665924` (v3 — closed consumer pins + lifecycle field)
- Sibling integration (multi-client campaign after this package + closed consumers): `ticket_1786474783_285888`

### Formal closed dependencies (required; all closed)

| Edge | Depends on | Target | Status | Consumed artifact pin |
| --- | --- | --- | --- | --- |
| `dependency_1786474790_793511` | `ticket_1786474779_865884` Hub entity-backed select | `tgt_7e208a0c76a44980a83b63af976b1f22` botster-hub | **closed** | Hub `origin/main` includes `891cc796faeab51ee4bee1a0e8494562b233036e` (`entity_options` contract + admission) |
| `dependency_1786482179_811581` | `ticket_1786474780_865627` Web entity-backed select | `tgt_40abcf71ccf049f4ac0c99953a799869` botster-web | **closed** | Web `origin/main` at `6048e0bede71c0f90899aac7e61cdf55575f4119`; direct npm pin `@trybotster/ui-contract@0.3.2` (entity_options projector/types) |
| `dependency_1786482183_479858` | `ticket_1786474781_871159` TUI entity-backed select | `tgt_c3d470bab78549df920a41e8fb0e58d8` botster-tui | **closed** | TUI `origin/main` at `abc804e19bc3e01465cd308c11de5f4292331c3d`; `botster-ui-contract` / `botster-hub-client` / `botster-hub-test-support` git-pinned to Hub `891cc796faeab51ee4bee1a0e8494562b233036e` |

Obsolete policy removed: no “named-only / optional Web-TUI prerequisites” wording. Formal edges stay registered. Generic consumer proof uses these merged pins.

The target was resolved from Project Pipelines `ticket.target_id` / `run.target_id` through `list_spawn_targets`, not from the ambient worktree path.

## Plan Review disposition (v3)

| Finding | Class | Status / plan response |
| --- | --- | --- |
| Entity option fields / conditional display | product/high | **Resolved v2** — label first + optional fields |
| Picker omits available lifecycle state field | product/high **open → fixed v3** | Add `lifecycle` to `display_fields` and present/absent matrix (keep `lifecycle_class`) |
| Live updates + generic consumer proof deferred | product/charter/high | **Resolved** — full reactive matrix; Web/TUI consumers merged |
| DB uniqueness / live concurrency undecided | product/high | **Resolved v2** — membership index + live concurrent proof |
| Advanced fallback undefined | product/medium | **Resolved v2** |
| Provider reload replay missing | product/medium | **Resolved v2** |
| Dependency status and artifact pins stale | product/process/medium **open → fixed v3** | Record closed edges, commits, targets, and pins above |
| Required Web/TUI deps open | product/charter/blocker | **Resolved** — both formal edges closed |
| Vault checklist / gitignore hygiene | process/infra | **Resolved** — one visit checklist; `.gitignore` from HEAD |

## Context loaded

Loaded in required order:

1. [[planner-playbook]]
2. [[botster-planner-playbook]]
3. [[botster-workspaces-playbook]]
4. Targeted atomic notes below

Role / surface guidance:

- [[botster-architecture]]
- [[cli-patterns]]
- [[spa-patterns]]
- [[project pipeline orchestration belongs in a device-level botster plugin]]
- [[project pipelines needs an operator workbench not more primitives]]
- [[botster orchestration should spawn agents with explicit target ids]]
- [[botster orchestration prompts must bind agents to explicit worktrees]]
- [[plan agents must author vault context as wikilinks not home paths]]
- [[pipeline vault checklists must cite exact resolvable note titles]]
- [[vault example paths are not repository placement conventions]]
- [[plan review must verify a plan artifact exists before trusting gate summaries]]

Repository-charter notes:

- [[workspaces are semantic groupings by purpose not by branch]]
- [[botster workspace records are plugin owned references not hub authority]]
- [[botster plugin entities are canonical for plugin-owned dynamic state]]
- [[botster package manifests and lockfiles should declare capabilities and provenance]]
- [[botster hub gravity must be watched before it becomes the new monolith]]
- [[acceptance harness region oracles must key on node identity not concatenated text]]
- [[plugin ui action ids are a two site change and hub fails closed on unregistered ids]]
- [[shared hub workspaces acceptance omits package path without skipping its lane]]

Ticket-specific notes:

- [[plugin-owned dynamic state uses plugin-namespaced entity frames]]
- [[plugin entity families publish filterable record supersets]]
- [[package entity hydration uses explicit providers not mcp naming]]
- [[botster plugin entity hydration has full id and scoped contracts]]
- [[botster plugin entity providers must replay after entity broadcast reload]]
- [[plugin query providers match snapshot read model shape]]
- [[plugin dynamic ui lists bind to plugin-owned entities]]
- [[session UUID is the sole routing key across all layers]]
- [[prefer framework and library components over custom solutions]]
- [[cold turkey migrations eliminate dual code paths and version suffixes]]

Not loaded:

- [[project-pipelines-playbook]] — delivery only; no Project Pipelines package paths in scope
- [[botster runtime teardown lenses]] — not runtime-teardown class

Repository evidence:

- `plugin.lua` add dialog still uses required Session UUID `text_input`; `add_session` returns `session_already_owned` even for same workspace; single `plugin_db` key `workspace_state`; no `entity_provider`
- Package tests, `script/hub_acceptance_smoke`, README/domain docs
- Hub `entity_options` on `botster-hub` `main` ≥ `891cc796faeab51ee4bee1a0e8494562b233036e`; projector skips missing display fields; first present string is option label
- Current `DaemonSessionEntity` provides **both** `lifecycle` (specific state: running/exited/…) and `lifecycle_class` (current/ended/indeterminate). Ticket requires lifecycle state when present → author both fields. `label` and `spawn_point` are not produced today but remain valid authored names for when present
- Web consumer merged: `6048e0bede71c0f90899aac7e61cdf55575f4119` with `@trybotster/ui-contract@0.3.2`
- TUI consumer merged: `abc804e19bc3e01465cd308c11de5f4292331c3d` with Hub contract pin `891cc79…`
- Hygiene: `git checkout HEAD -- .gitignore` (12 lines); package baseline remains green from prior visit

## Product decision ledger (locked)

### 1. Normal claim path

Add existing session authors one `ui.select` with `props.options_source.$kind = "entity_options"`. No static `select_option` children on that control.

### 2. Source and value

- `source = "/session"`
- `value_field = "session_uuid"` (exact Hub string)
- Form control `name = "session_id"` so `botster_workspaces.add_session` stays stable

### 3. Pinned options_source descriptor

```lua
options_source = {
  ["$kind"] = "entity_options",
  source = "/session",
  value_field = "session_uuid",
  -- First present string becomes the option label (contract rule).
  -- label first: when Hub later projects label, it wins over UUID.
  -- session_uuid second: always-present fallback label today.
  display_fields = {
    "label",
    "session_uuid",
    "lifecycle",           -- specific process state when present (ticket: lifecycle state)
    "lifecycle_class",     -- current/ended/indeterminate grouping when present
    "session_type_id",
    "spawn_point",
  },
  order = {
    "label",
    "lifecycle_class",
    "lifecycle",
    "session_type_id",
    "session_uuid",
  },
  exclude = {
    source = "/botster-workspaces.membership",
    value_field = "session_uuid",
  },
}
```

Rules:

- Do **not** filter with `where.lifecycle_class` on the normal picker. Available means present in `/session` and not membership-excluded.
- Use exact session-type field name `session_type_id` (not `session_type`).
- Author **both** `lifecycle` and `lifecycle_class`. Ticket requires lifecycle state when present; `lifecycle_class` remains useful grouping metadata already on the wire.
- Missing display fields are skipped by the shared projector; presence later updates options without package changes.
- Package-local projection tests must cover: all listed fields present; only `session_uuid` present; and present/absent for each of `label`, `lifecycle`, `lifecycle_class`, `session_type_id`, `spawn_point`.
- Never copy label, lifecycle, session type, or spawn point into `plugin_db`.

### 4. Membership exclusion family

- Entity type: `botster-workspaces.membership` (path `/botster-workspaces.membership`)
- Record shape only: `{ id, session_uuid, workspace_id }` with `id = session_uuid` (1:1 membership)
- Explicit `entity_provider` with `id_field = "id"`
- Provider returns authoritative whole-family snapshots on subscribe and reconnect
- Mutations emit membership upsert/remove frames so open pickers update without surface refresh

### 5. Database uniqueness model (single chosen design)

**Canonical workspace document** remains one key:

- Key: `workspace_state`
- Payload: `{ next_workspace, next_timestamp, workspaces[] }` with each workspace `{ id, name, session_refs, created_at, updated_at }`

**Uniqueness index** (database key uniqueness):

- Key: `membership:<session_uuid>` (exact prefix `membership:`)
- Payload: `{ session_uuid, workspace_id }`
- Creating a new claim uses `plugin_db.batch` with:
  1. `set` membership key with `expected_revision = 0` (create-only; second concurrent create gets `revision_conflict`)
  2. `set`/`patch` `workspace_state` with the loaded `expected_revision`
- Batch is atomic: failure changes no record
- On `revision_conflict`: reload both keys, re-evaluate ownership, return idempotent success or typed conflict
- Same-workspace retry: membership key already points at this workspace → **ok**, no second `session_refs` append
- Cross-workspace claim: membership key points at other workspace → `session_already_owned` with `owner_workspace_id`
- remove/move/delete/spawn-record keep membership keys and `session_refs` consistent in one batch
- `validate_state` still rejects duplicate `session_refs` inside the workspace document as a defense in depth

This is the uniqueness guarantee: **one membership key per session_uuid in the plugin store namespace**, created only at revision 0, mutated only through atomic batches that also update the workspace document.

### 6. `add_session` semantics

```text
resolve session_id from form (see advanced precedence)
validate UUID
load workspace_state (revision R) and membership:<session_id>
if membership.workspace_id == workspace_id -> ok (idempotent)
if membership.workspace_id is other -> session_already_owned
else batch:
  set membership:<session_id> expected_revision=0
  set workspace_state expected_revision=R with session_id appended
on revision_conflict -> reload and re-evaluate
emit membership entity upsert on durable success
```

### 7. Advanced fallback (pinned UX)

Always-visible advanced block **below** the Available sessions picker (not a presentation toggle).

| Element | Value |
| --- | --- |
| Select id | `botster-workspaces-add-session-id` |
| Select name | `session_id` |
| Select label | `Available sessions` |
| Advanced text id | `botster-workspaces-add-session-id-advanced` |
| Advanced text name | `session_id_advanced` |
| Advanced label | `Historical session UUID` |
| Helper copy | `Use only when the session is absent from current Hub session state.` |
| Select required | `false` (validation is action-side) |
| Advanced required | `false` |

**Value precedence (locked):**

1. If `session_id_advanced` trims to non-empty → use it as `session_id` (historical path).
2. Else if picker `session_id` trims to non-empty → use picker value.
3. Else → `validation_failed` requiring a selection or historical UUID.
4. If both set → advanced wins (historical override); do not error.
5. Invalid UUID on the chosen value → `validation_failed`.

Action extraction maps both form values into the same `add_session({ workspace_id, session_id })` core.

Required case matrix in tests:

- picker-only valid
- advanced-only valid (historical recovery)
- both set → advanced value claimed
- both empty → validation_failed
- invalid advanced / invalid picker
- ended or absent-from-entity historical UUID still groups after advanced claim

### 8. Clients stay generic

No Web/TUI package-specific logic. Package authors the surface. Generic consumers render `entity_options`. Web and TUI renderer adoption is already merged (closed formal deps above); this ticket requires production-mode proof through those consumers on the recorded pins.

### 9. Move dialog

Out of scope unless a free consistency change; ticket is Add existing session.

### 10. Runtime-teardown class

Does not apply.

## Scope

### In scope

1. Entity-backed Available sessions picker on Add dialog with pinned descriptor.
2. Membership entity family + provider + mutation frames.
3. Membership-index uniqueness + workspace_state batch CAS.
4. Idempotent same-workspace claim; typed cross-workspace conflict; live concurrent claim proof.
5. Pinned advanced historical UUID fallback and case matrix.
6. Package tests + real Hub smoke extensions + Web/TUI package lifecycle modes for the new path.
7. Docs updates.

### Out of scope

- Implementing Hub `entity_options` (closed dependency).
- Implementing Web/TUI select rendering (dependency tickets; do not broaden this repo).
- Owning the multi-client integration campaign ticket (sibling; may reuse this package proof).
- Move-dialog redesign, spawn redesign, copying Hub session fields into plugin_db.
- `list_sessions` polling or list-refresh fallbacks.
- Project Pipelines package changes.

## Repository ownership and cross-repo dependencies

| Concern | Owner | This run |
| --- | --- | --- |
| Workspace records, membership index, surfaces, actions | botster-workspaces | **Yes** |
| `/session` entity truth | botster-hub | Consume |
| `entity_options` admission + projector | botster-hub / ui-contract | **Closed** dep |
| Generic entity-backed select rendering | botster-web, botster-tui | **Closed formal deps** — consume merged pins; do not implement here |
| Multi-client claim campaign | integration ticket | Sibling |

Hard-registered ticket dependencies (all **closed**):

| Id | Ticket | Repo target | Merged pin |
| --- | --- | --- | --- |
| `dependency_1786474790_793511` | Hub entity_options | `tgt_7e208a0c76a44980a83b63af976b1f22` | Hub ≥ `891cc796faeab51ee4bee1a0e8494562b233036e` |
| `dependency_1786482179_811581` | Web entity-backed select | `tgt_40abcf71ccf049f4ac0c99953a799869` | Web `6048e0bede71c0f90899aac7e61cdf55575f4119` + `@trybotster/ui-contract@0.3.2` |
| `dependency_1786482183_479858` | TUI entity-backed select | `tgt_c3d470bab78549df920a41e8fb0e58d8` | TUI `abc804e19bc3e01465cd308c11de5f4292331c3d` + Hub git pin `891cc79…` |

Live proof Hub pin: ≥ `891cc796faeab51ee4bee1a0e8494562b233036e`. Validate package UI with that Hub’s `botster-ui-contract`.

## Assumptions and unknowns

### Assumptions (explicit)

1. Form name `session_id` remains the action’s session argument after precedence resolution.
2. Membership id equals `session_uuid`.
3. UUID validation remains the package’s existing `valid_session_id` (RFC UUID). Non-RFC agent id shapes share that pre-existing constraint and are not expanded here unless spawn-returned ids force it.
4. Dialog close after accept is fine; open-dialog reactivity uses entity frames, not surface replacement.
5. Closed Web/TUI dependency tickets deliver generic `entity_options` rendering on the pins above; this package does not ship renderer workarounds.

### Unknowns (non-blocking; implement verifies)

1. Exact frame emission helper available to Lua packages for membership upsert/remove after mutations (follow Project Pipelines / Hub package entity patterns already on device).
2. Whether an additional `entity_provider` for `botster-workspaces.workspace` is required for other bindings already in tree (membership is required; workspace only if admission or existing binds demand it).

No human question: Plan Review findings have closed the previous product forks.

## Affected surfaces / files

- `plugin.lua` — primary
- `test/plugin_runtime_test.lua`
- `test/fixtures/workspaces/contract.json` (if families/UI contract enumerated)
- `script/hub_acceptance_smoke` — membership, concurrent claim, entity_options admission, provider replay
- `script/test-hub-flow` / shared-stack only if already covering add-session
- README, `docs/workspace-domain.md`, `docs/capabilities.md`
- Web package lifecycle smoke inputs from `botster-web` docs (caller-owned; this package supplies path)
- TUI Workspaces lifecycle mode (caller-owned; this package supplies path)

## Implementation sketch

### A. Membership index + state

```text
MEMBERSHIP_KEY(session_uuid) = "membership:" .. session_uuid

claim_batch(workspace_id, session_uuid, state, state_revision):
  if membership exists and same workspace -> return ok_idempotent
  if membership exists and other workspace -> return session_already_owned
  mutations = {
    { op=set, key=MEMBERSHIP_KEY, expected_revision=0, payload={session_uuid, workspace_id} },
    { op=set, key=workspace_state, expected_revision=state_revision, payload=updated_state },
  }
  return plugin_db.batch({ mutations = mutations })
```

### B. Provider

Register `entity_provider` for `botster-workspaces.membership`. Snapshot derives from membership keys (or from workspace_state + membership keys after consistent batch). Prefer reading membership keys via `plugin_db.list({ prefix = "membership:" })` so the exclusion family matches the uniqueness index.

### C. Add dialog authoring

Pinned select + advanced text + helper text as in ledger §7. Remove required primary Session UUID text input.

### D. Action extraction

```text
advanced = trim(form session_id_advanced)
picker = trim(form session_id)
session_id = advanced or picker
```

## Risks

| Risk | Mitigation |
| --- | --- |
| Hub without entity_options | Pin Hub ≥ parent merge; contract validate fails closed |
| Consumer pin skew / wrong Web or TUI SHA | Use closed-edge pins (Web `6048e0b…` + ui-contract 0.3.2; TUI `abc804e…` + Hub `891cc79…`); no soft residual |
| Concurrent claim races | membership create-only revision 0 + batch; live dual-action proof |
| Membership/workspace_state drift | single batch; restart validation; smoke after concurrent claims |
| Provider lost after entity_broadcast reload | explicit replay acceptance |
| Advanced path steals normal UX | always below picker; helper copy; tests |
| Missing display fields confuse QA | projection tests for present/absent matrix |

## Acceptance checks / tests

### Package-local (`script/test`)

1. Green full package test suite.
2. Authored add dialog: entity_options select present; normal path is not required Session UUID text.
3. Authored `display_fields` exactly: `label`, `session_uuid`, `lifecycle`, `lifecycle_class`, `session_type_id`, `spawn_point`.
4. Projection matrix (shared projector or package fixture): present/absent for each optional field including **`lifecycle` and `lifecycle_class`**; label wins when present; UUID fallback when label absent.
5. Membership rows only `{id, session_uuid, workspace_id}`.
6. add once; same-workspace retry idempotent; other workspace conflict; membership key unique.
7. Concurrent package-level simulation: two claims, one durable membership, one conflict or idempotent owner.
8. Advanced case matrix (§7).
9. move/remove/spawn/delete keep membership keys consistent.
10. Restart durability.
11. No `list_sessions` in package sources.

### Real Hub package path (required; not Lua-only)

1. Fresh data dir; install/enable this package on Hub ≥ entity_options.
2. Render workspaces; open Add dialog; Hub admits `/session` + `/botster-workspaces.membership`.
3. Membership provider: authoritative snapshot; reconnect with new subscription_id yields fresh snapshot.
4. **Provider replay**: reload `lib.entity_broadcast` (or package-documented reload path); membership provider remains registered; nonempty snapshot for existing membership returns ([[botster plugin entity providers must replay after entity broadcast reload]]).
5. Unclaimed session appears in projected options after `/session` entity change **without** surface refresh.
6. Claim → membership upsert → option excluded without surface refresh.
7. Remove membership → option restored without surface refresh.
8. Lifecycle patch/upsert updates option metadata for **`lifecycle` and `lifecycle_class`** without surface refresh.
9. Label patch when field present updates option label without surface refresh; when absent, UUID label remains.
10. Hub session remove frame removes option without surface refresh.
11. Same-workspace retry ok; cross-workspace conflict; **live concurrent** production actions (two parallel MCP/UI add_session requests) → one owner, one conflict or idempotent, durable single membership key.
12. Advanced historical recovery for session absent from current Hub entity state.
13. Record Hub SHA + locked core worker provenance.

### Generic consumer proof (charter; no soft residual)

Web and TUI formal dependencies are **closed** with the pins above. Verify must exercise those merged consumers against this package path:

1. Documented `botster-web` Workspaces lifecycle / package smoke with `BOTSTER_WORKSPACES_PACKAGE_PATH` set to this checkout, on Web ≥ `6048e0bede71c0f90899aac7e61cdf55575f4119` with `@trybotster/ui-contract@0.3.2`: open Add dialog, select available session without typing UUID, submit, membership claimed; picker updates without surface refresh for lifecycle/`lifecycle` field changes, claim exclusion, and remove restoration.
2. Documented `botster-tui` Workspaces lifecycle mode on TUI ≥ `abc804e19bc3e01465cd308c11de5f4292331c3d` with Hub contract pin `891cc79…`: keyboard select + submit same action id/payload; same reactive updates; selection invalidation when option disappears.
3. Oracles key on node ids / action ids, not parser-friendly copy ([[acceptance harness region oracles must key on node identity not concatenated text]]).
4. Shared-hub driver still omits package install ownership when used ([[shared hub workspaces acceptance omits package path without skipping its lane]]); package-path proof remains the package-owned install+smoke path above.

Do not soft-residual consumer proof. Package-local and real-Hub producer proofs may complete in Implement; ticket closure requires the consumer path on the closed pins.

### Production entry point

Workspaces surface → workspace detail → Add existing session → Available sessions picker (or advanced historical UUID) → submit → `botster_workspaces.add_session` → membership index + workspace_state batch → membership entity frame → detail lifecycle groups show the UUID via existing `/session` bindings.

## Vault gaps

1. Package entity-options + membership exclude pattern (first product consumer).
2. Membership-index uniqueness via create-only plugin_db keys.
3. Idempotent same-workspace claim as product rule.
4. Advanced historical UUID precedence rule.

## Worktree hygiene

- `.gitignore` restored from HEAD (12 lines); keep it.
- No colon in worktree path; no `CARGO_TARGET_DIR` override required.
- Prior Plan visit created duplicate vault checklists after MCP timeouts; this visit uses exactly one new run-scoped checklist and records skip of further duplicates.

## Plan completion evidence keys

- `target_repository`: botster-workspaces
- `target_id`: tgt_71266a8d976d4535902ffed09c18a7ba
- `repository_playbook`: botster-workspaces-playbook
- `teardown_class_applies`: false
- `plan_uri`: docs/plans/replace-manual-session-id-with-available-sessions-picker.md
