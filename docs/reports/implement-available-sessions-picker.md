# Implement report: Available sessions picker (final)

## Target repository and target_id

- **Target repository:** `botster-workspaces` (`trybotster/botster-workspaces`)
- **target_id:** `tgt_71266a8d976d4535902ffed09c18a7ba`
- **Branch / PR:** `project-pipelines/ticket_1786474780_590414` / https://github.com/trybotster/botster-workspaces/pull/16
- **Base:** `origin/main` producer merge `c069900` (membership `entity_publish`)
- **teardown_class_applies:** false

## Playbooks / notes applied

- [[implementer-playbook]]
- [[botster-implementer-playbook]]
- [[botster-workspaces-playbook]]
- Membership publish consumed from closed sibling `ticket_1786507221_760227` (not reimplemented).
- Hub fanout + empty `items` coercion from closed `ticket_1786494180_266672`.
- Web lifecycle harness select path from closed `ticket_1786494437_647488` at `2a41220`.

## Review findings — resolution map

| Finding | Resolution |
| --- | --- |
| Live membership subscription updates | Consumed producer on main + Hub fanout: smoke holds open membership subscription and observes claim `entity_upsert` and remove `entity_remove` without resubscribe |
| Fake canonical UUID sentinel | Removed; empty provider returns truthful `items == []` (Hub `coerce_entity_frame_empty_items`); smoke asserts `items == []` |
| Generic Web/TUI package paths | Web lifecycle + membership-reactive **pass** on `2a41220`; TUI lifecycle **pass** on `abc804e1` |
| PR 16 not linked | Linked via `project_pipelines_link_pr` (`pr_1786494179_679803`) |
| Absolute local paths in report | Path-neutral env vars only (`BOTSTER_HUB_BIN`, `BOTSTER_SESSION_WORKER_BIN`, `BOTSTER_WORKSPACES_PACKAGE_PATH`) |

## Files changed (picker product on producer main)

| Path | Role |
| --- | --- |
| `plugin.lua` | entity_options Available sessions + advanced historical UUID; form precedence |
| `script/hub_acceptance_smoke` | entity_options authoring; empty `items == []`; held-open publish proofs (from main) |
| `test/plugin_runtime_test.lua` | Picker + advanced precedence |
| `test/fixtures/workspaces/contract.json` | Picker contract |
| `README.md` / `docs/workspace-domain.md` | Picker docs |
| `docs/plans/...` / `docs/reports/...` | Plan + this report |

## Ownership

- Package owns picker authoring and membership publish (main producer).
- No Web/TUI code in this worktree; consumers exercised generically.
- No duplicate producer stack — rebased onto `c069900`.

## Cross-repo dependencies (all closed)

| Ticket | Pin / note |
| --- | --- |
| Hub entity_options | closed |
| Web entity_options render | closed |
| TUI entity_options render | closed |
| Hub fanout + empty array | closed (`35dd7d2` on Hub main ≥ `de6b099`) |
| Membership publish producer | closed (`c069900`) |
| Web lifecycle harness | closed (`2a41220`) |

## Tests and downstream proof

### Package-local

```sh
script/test
# ok
```

### Real Hub package path

```sh
BOTSTER_HUB_BIN=<hub-debug-from-origin/main> \
BOTSTER_SESSION_WORKER_BIN=<session-worker-debug> \
  script/test-hub-flow
# hub_acceptance_smoke: ok (conformance 35)
# includes empty membership items == [], entity_options descriptor,
# held-open claim upsert + remove, concurrent claims, spawn path
```

### Generic consumers

| Consumer | Pin | Command | Result |
| --- | --- | --- | --- |
| Web lifecycle + membership reactive | `2a412208bc9508f24a57688ec5db94a5519d2573` | `BOTSTER_WORKSPACES_PACKAGE_PATH=<package> npm run smoke:workspaces-lifecycle` | **pass** — `workspaces-entity-options-membership-reactive` (claim_exclusion, membership_restore, dual_client, stale_submit_blocked) + full lifecycle acceptance |
| TUI lifecycle | `abc804e19bc3e01465cd308c11de5f4292331c3d` | `script/test-live-hub workspaces lifecycle` | **pass** (see latest log) |

### Provenance (path-neutral)

| Identity | Value |
| --- | --- |
| Workspaces tip | branch commit after final implement commit |
| Hub source | `origin/main` (`de6b099…`, includes fanout `35dd7d2`) |
| Hub binary | `$BOTSTER_HUB_BIN` debug build of that tree |
| Worker binary | `$BOTSTER_SESSION_WORKER_BIN` |
| Protocol | `botster-hub-daemon-v1` / v6 / conformance **35** |
| Web consumer | `2a41220` + `@trybotster/ui-contract@0.3.2` |
| TUI consumer | `abc804e1` + Hub git pin for contract packages |

### Production entry point

Workspaces surface → Add existing session → Available sessions (`entity_options` `/session` exclude membership) or advanced historical UUID → `botster_workspaces.add_session` → membership index batch + `entity_publish` upsert → open pickers exclude without surface refresh → remove publishes membership remove and restores option.

## Residual risk

- None blocking for Review admission. Web/TUI proofs used explicit closed pins above; continuous main drift may require re-pin later.

## Missing vault guidance

1. First product `entity_options` + membership exclude consumer pattern.
2. Membership index create-only uniqueness + publish after batch.
3. Advanced historical UUID precedence.
4. Empty entity_provider items rely on Hub field-exact coercion (not package sentinels).
