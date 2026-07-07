# Adopt Explicit Plugin Navigation Entries

## Context loaded

- Ticket: `ticket_1783371445_836975`, "Adopt explicit plugin navigation entries in botster-workspaces".
- Run: `run_1783381572_459963`, step `botster_plan`, target repo `trybotster/botster-workspaces`.
- Dependency: `ticket_1783371372_931094` is recorded as closed; implementer must verify the local hub checkout used for acceptance includes that merged schema/runtime before changing the package.
- No open questions, findings, reviews, or prior answers were present in current pipeline context.
- Required vault context read: [[planner-playbook]], [[botster-planner-playbook]], [[botster-architecture]], [[cli-patterns]], [[spa-patterns]], [[project pipeline orchestration belongs in a device-level botster plugin]], [[project pipelines needs an operator workbench not more primitives]], [[project pipelines ui contract belongs in the plugin readme]], [[botster orchestration should spawn agents with explicit target ids]], [[botster orchestration prompts must bind agents to explicit worktrees]], and [[botster plugin surfaces own navigation and plugin scoped sessions]].
- Repo context inspected: `botster-package.json`, `plugin.lua`, `README.md`, `script/test`, `script/validate_ui_node_contract`, `script/hub_acceptance_smoke`, `test/plugin_runtime_test.lua`, and `test/fixtures/workspaces/contract.json`.

## Scope

- Update `botster-package.json` to declare the new explicit package navigation entries for the existing Workspaces app surface and settings surface.
- Remove Workspaces-owned ordering/priority/pinning/hiding authority from the package manifest. The current `surfaces[].order` fields are the main suspected violation unless the merged hub schema maps them differently.
- Preserve existing surface ids and route identity unless the hub contract requires a narrow rename:
  - app surface id: `workspaces`
  - settings surface id: `workspaces-settings`
  - app route target remains the existing `workspaces` plugin surface render path.
- Update manifest validation in `script/test` and fixture data in `test/fixtures/workspaces/contract.json` so the repo asserts the new navigation contract and rejects old ordering/priority/pinning/hiding fields.
- Update `script/hub_acceptance_smoke` to prove the production path changed: after package admission, the hub exposes Workspaces navigation through the admitted navigation registry and opening that entry renders the existing Workspaces surface.
- Update runtime tests only where needed to keep app/settings render coverage tied to the same stable descriptor ids.
- Update `README.md` and, if helpful, `docs/capabilities.md` to explain the boundary: package navigation entries make app surfaces discoverable; surface root `UiNode`s own page content only; hub/web/TUI clients own placement, layout, and ordering.

## Non-scope

- No sidebar replacement, route layout, padding model, `local_navigation`, or page-shell assumptions inside Workspaces.
- No custom HTML, iframe, plugin asset bridge behavior, or vault graph migration.
- No new app/settings surface ids unless the new hub contract cannot admit the current ids.
- No Workspaces-specific global priority, pinning, hiding, sorting, or cross-plugin placement policy.
- No changes to workspace CRUD, session-template selection/spawn behavior, plugin-db persistence, or entity-family shape except tests/docs touched by the navigation contract.
- No hub/core schema work in this repo; if the closed dependency is not actually available in the local acceptance hub, implementation should stop and report the dependency mismatch.

## Assumptions and unknowns

- Assumption: the closed hub dependency adds a package-manifest-level navigation contract that can refer to existing package app/settings surfaces without moving layout authority into Workspaces.
- Assumption: navigation entries are distinct from `surfaces` descriptors. Surfaces keep render metadata and capabilities; navigation declares discoverability for host clients.
- Assumption: the accepted navigation entry can target `package_name=botster-workspaces` plus `surface_id=workspaces` or the schema-equivalent target. Implementer must follow the merged hub schema exactly.
- Assumption: settings navigation is allowed only if the hub contract treats package settings as a navigable app-wide entry; otherwise the explicit nav entry should be limited to the app surface while settings remains discoverable through package settings routes.
- Unknown: exact JSON key names for the merged contract, such as `navigation`, `navigation_entries`, `app_navigation`, `target`, or `surface_id`. Resolve from the hub schema/tests, not guesswork.
- Unknown: exact daemon response shape for the admitted navigation registry. The smoke should assert the hub-produced field, not a source-level manifest shape.
- Unknown: whether existing `surface:workspaces` and `/packages/botster-workspaces/surfaces/workspaces` route paths remain current or are superseded by `/apps/:package/:surface`. Preserve whichever production hub contract reports, and document the actual path in README.

## Affected surfaces/files

- `botster-package.json`: add explicit navigation entries; remove Workspaces-owned `order` or other forbidden placement fields; keep existing app/settings surfaces stable.
- `script/test`: manifest schema assertions for navigation entries, forbidden placement keys, stable ids, docs coverage, and leak scan.
- `script/hub_acceptance_smoke`: real hub assertions for admitted package navigation registry plus render/open path for the existing Workspaces app surface.
- `test/fixtures/workspaces/contract.json`: add navigation contract fixture fields if the current fixture remains the repo's manifest contract source.
- `README.md`: document app navigation versus surface content responsibilities and the verified client route/registry path.
- `docs/capabilities.md`: update capability/navigation wording if current "surfaces" documentation implies surfaces alone own discoverability.
- `test/plugin_runtime_test.lua`: likely unchanged unless local runtime fixture needs to dump/assert navigation-adjacent descriptor expectations.
- `docs/plans/adopt-explicit-plugin-navigation-entries.md`: this plan artifact.

Botster layers touched: first-party plugin package manifest, plugin runtime tests, hub acceptance smoke, and docs. Hub/core, React SPA, TUI, and Rust runtime code are consumers only for this ticket; they should be proven through hub acceptance rather than modified here.

Worktree/target assumptions: this run is bound to the Project Pipelines worktree for `trybotster/botster-workspaces`. Acceptance against hub must use an explicit local hub checkout/binary that includes dependency `ticket_1783371372_931094`; do not rely on an ambient unrelated hub.

## Risks

- Schema drift risk: implementing against guessed JSON keys could pass source tests while failing hub admission. Mitigation: derive keys from the closed hub schema and add `script/hub_acceptance_smoke` assertions against the hub-admitted registry.
- Authority boundary risk: leaving `order` or adding `priority`, `pinned`, `hidden`, or equivalent fields would preserve Workspaces-owned global placement authority. Mitigation: add negative assertions in `script/test`.
- Unwired implementation risk: adding manifest JSON without proving the daemon/client registry consumes it would satisfy source inspection only. Mitigation: smoke must query the running hub's admitted navigation registry and open/render the entry.
- Route churn risk: changing surface ids or route paths unnecessarily could break web/TUI clients. Mitigation: keep existing ids and assert the route/surface render path still works.
- Cross-client risk: app navigation could become web-only. Mitigation: keep the proof at the hub-admitted registry and plugin surface render contract, which web and TUI clients consume.
- Stale dependency risk: the worktree may not have the closed hub dependency's schema available. Mitigation: implementer verifies hub schema/binary first and records exact evidence; if absent, block instead of inventing compatibility shims.

## Acceptance checks/tests

- `script/test` passes and proves:
  - manifest declares explicit Workspaces navigation entries using the new schema;
  - forbidden ordering/priority/pinning/hiding placement fields are absent;
  - current app/settings surfaces and route names stay stable or have a documented hub-required narrow change;
  - README/docs distinguish app navigation from surface content ownership;
  - existing CRUD/session-template/plugin-db/runtime assertions still pass.
- `script/validate_ui_node_contract` passes with `BOTSTER_CORE_PATH` pointing at the locked hub/core checkout used by the implementation.
- `script/hub_acceptance_smoke <botster-hub.sock> [workspace-name]` passes against a real local hub containing the closed dependency and proves:
  - package admission exposes Workspaces in the admitted navigation registry;
  - the navigation entry targets the existing Workspaces surface;
  - opening/rendering that target returns the existing Workspaces `UiNode` surface;
  - settings and app surfaces remain renderable through the plugin surface render contract;
  - workspace CRUD/session-template/plugin-db paths still work.
- If hub acceptance requires a specific setup command, record the exact hub binary path, data dir mode, install/enable commands, and socket path in the implementer artifact.
- Leak/PII scan remains covered by `script/test`.

## Vault gaps worth capturing

- Capture if the new merged contract has a durable convention not yet in the vault: explicit package navigation entries are discoverability declarations, while host clients own placement/order/pinning and plugin surface roots own only page content.
- Capture if the hub acceptance smoke reveals a reusable daemon request or registry field for "admitted package navigation"; future first-party plugin tickets will need the same production-path proof.
- No convention conflict found. Existing [[botster plugin surfaces own navigation and plugin scoped sessions]] mentions older `nav = { section, order, label, icon }` surface registration language, but this ticket's architecture direction supersedes Workspaces-owned order authority for package manifest navigation.
