# Coverage map: fake suite to kit specs

The hand-written fake suite `test/plugin_runtime_test.lua` (base 742891f) is
replaced by kit specs that run the package in a real Hub runtime. This map
lists each behaviour the fake suite asserted (IDs from the inventory in
botster-evidence/plugin-orchestrator-20260928/workspaces-fake-suite-inventory.md)
and names the spec that covers it, or states why it is dropped.

Drop reasons:
- **fake-count**: the assertion counted fake calls (`batch_calls`, list calls). The
  behaviour behind it (one atomic write) is covered by the state it leaves.
- **fake-inject**: the path needs a plugin_db, entity_publish, or capability failure
  that the real runtime cannot produce. No kit double exists for plugin_db
  (kit writer, msg_plugin-w_1790640861_1e348b). Covered by review.
- **fake-db**: the fake wrote the store directly (pre-index or legacy state). The
  cold cut removed the pre-index fallback; nothing can write the store from
  outside the package.
- **no-worker**: a completed spawn needs a session worker; the in-process kit
  has none. Proven by the real-Hub acceptance scripts.
- **harness**: the check existed only for the fake harness (env gates, JSON dump).

| ID | Behaviour | Covered by | Note |
|---|---|---|---|
| R1 | register once | every spec (`t:load`) | a load error fails the spec |
| R2 | tools registered | workspace_spec "registers its tools" | now 13 tools |
| R3-R6 | argument schemas | workspace_spec "registers its tools" | `hub_id` added |
| R7 | membership entity_provider | membership_spec "publish upsert and remove frames" | the kit subscribes as a client and receives the provider snapshot first |
| R8-R10 | surface_route, open_spawn, spawn ui_action | surface_spec (every spec renders or acts through them) | |
| R11, R12 | env gates | dropped: harness | the gates lived only in the fake harness |
| W1 | cold list empty | workspace_spec "fresh hub" | also asserts a JSON array |
| W2 | create five fields | workspace_spec "create trims" | |
| W3, W4 | unknown field, duplicate name | workspace_spec "create refuses" | |
| W5-W7 | rename | workspace_spec "rename trims" | |
| W8 | state survives reload | dropped: fake-db | durability is the Hub's plugin_db; not a plugin behaviour |
| W9 | opaque session id | workspace_spec "opaque non-UUID" | |
| W10, W11 | delete | workspace_spec "delete removes only the grouping" | 3 refs; count-independent |
| W12 | entity_snapshot rows | workspace_spec "entity_snapshot" | |
| M1 | add | membership_spec "add records" | one-batch count dropped: fake-count |
| M2 | index key and payload | membership_spec "add records" | new key `membership:<hub_id>/<session_id>` |
| M3, M13 | idempotent re-add | membership_spec "re-adding" | |
| M4-M6 | owner conflict, validation | membership_spec "one workspace" | |
| M7-M9 | move, remove, re-add | membership_spec "move changes the owner" | batch counts dropped: fake-count |
| M10 | revision_conflict retry | dropped: fake-inject | |
| M11, M12 | pre-index fallback | dropped: fake-db | fallback removed in the cold cut |
| S1-S3 | completed spawn records the session | dropped: no-worker | the path up to the Hub helper is covered by spawn_spec |
| S4 | git target needs branch | spawn_spec "a git target needs a branch" | |
| S5-S7 | caller id, template_id, missing type | spawn_spec "refuses caller-chosen ids" | |
| S8-S10 | Hub rejection reported | spawn_spec "a Hub spawn refusal" | real refusal (unknown session type) |
| S11, S13 | persist or publish failure after spawn | dropped: fake-inject + no-worker | |
| S12 | spawn action | dropped: no-worker | the spawn dialog's targets are covered by surface_spec "spawn dialog offers admitted spawn targets" |
| F1-F6 | session-family pruning | events_spec "current keeps / ended pruned", "missing or removed keeps" | production frames via the kit |
| F7 | session_spawned | not in this delivery | the placement event is parked until Hub gap P10 (a subscription to another package's event fails the load unless the producer is active) |
| E1-E4 | membership frames | membership_spec "publish upsert and remove frames" | rows carry `{hub_id, session_id}` |
| E5 | multi-delete range | workspace_spec "delete removes only the grouping" | index keys cleared; frame ordering not asserted |
| E6 | provider snapshot | membership_spec "publish upsert and remove frames" | snapshot frame first |
| E7 | sequence continues after reload | dropped: fake-db | durability is the Hub's |
| E8 | provider re-list on concurrent seq | dropped: fake-inject | needs an interleaved list override |
| E9-E14 | publish retry and degraded delivery | dropped: fake-inject | the real publish accepts in-sequence frames |
| U1, U2 | empty surface | surface_spec "the empty surface" | |
| U3 | open New workspace | surface_spec "New workspace action opens" | |
| U4, U26 | create action | surface_spec "create rejects an empty name" | |
| U11 | add picker options_source | surface_spec "add picker excludes memberships" | exclusion field is now `session_id` (rekey) |
| U12 | lifecycle bind_lists | surface_spec "binds its rows to /session" | |
| U16, U24 | spawn targets in the dialog | surface_spec "spawn dialog offers admitted spawn targets" | also the unwrap regression through the UI |
| U27 | remove action | surface_spec "remove action" | |
| U28-U31 | add precedence | surface_spec "add session precedence" | |
| U32 | add conflict | surface_spec "reports the conflict" | |
| U5-U10, U13-U15, U17-U23, U25 | layout detail and pinned copy | not carried | pinned labels, descriptions, node ids, and dialog layout; the real-Hub claim-stack and shared-stack acceptance scripts drive the rendered surface in the Web and the TUI |
| L1 | no template_id | spawn_spec "refuses caller-chosen ids" | |
| L2 | obsolete create fields | workspace_spec "create refuses" | |
| L3, L4 | legacy persisted state | dropped: fake-db | |
| L5 | surface JSON dump | dropped: harness | |
| P1-P6 | injected persistence failures | dropped: fake-inject | |

New behaviour covered only by specs:
- Regression, spawn target unwrap (red on 742891f): spawn_spec "spawn finds an admitted spawn target".
- Regression, global `log` in the prune path: covered by review only (fake-inject; no
  plugin_db failure double). The orchestrator accepted this (msg_plugin-w_1790640871_3d4cc8).
- Empty lists cross as JSON arrays: workspace_spec "fresh hub", "create trims".
- `hub_id` rules: workspace_spec "agent tools", membership_spec "remote hub",
  "move_agent_workspace".
