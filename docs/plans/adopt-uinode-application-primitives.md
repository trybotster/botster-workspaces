# Adopt UINode application primitives in Workspaces plugin surfaces

## Context loaded

- Ticket: `ticket_1783529013_114468`, "Adopt UINode application primitives in Workspaces plugin surfaces".
- Run: `run_1783554796_454322`, step `botster_plan`, run step `run_step_1783554796_891902`.
- Dependencies recorded closed:
  - `ticket_1783529012_588056`, "Render new UINode application primitives in botster-web with Ionic composition".
  - `ticket_1783529012_926361`, "Consume upgraded TUI Kit primitives in botster-tui plugin surfaces".
- Initial pipeline context had no prior artifacts, reviews, findings, questions, or answers. After Plan Review, this Plan step was reopened with changes requested in review `review_1783555309_403207`.
- Gate prompt: attach context loaded, scope/non-scope, assumptions/unknowns, affected files, risks, acceptance checks/tests, and vault gaps.
- Project Pipelines checklist evidence: `project_pipelines_create_vault_checklist` and `project_pipelines_create_checklist` timed out client-side with `plugin worker invoke timeout`, but `project_pipelines_current_context` later showed both writes landed as run checklists. Do not retry checklist creation on this timeout class; inspect `run_checklists` and preserve evidence in artifacts/gates.
- Required vault context read: [[identity]], [[goals]], [[planner-playbook]], [[botster-planner-playbook]], [[botster-architecture]], [[cli-patterns]], [[spa-patterns]], [[project pipeline orchestration belongs in a device-level botster plugin]], [[project pipelines needs an operator workbench not more primitives]], [[project pipelines ui contract belongs in the plugin readme]], [[botster orchestration should spawn agents with explicit target ids]], [[botster orchestration prompts must bind agents to explicit worktrees]], [[botster workspace records are plugin owned references not hub authority]], [[plugin surface handlers must validate against hub locked uinode contract]], [[cross-client ui should share semantic primitives and actions with renderer-specific adapters]], and [[botster core lua owns plugin framework primitives not product policy]].
- Repo context inspected: `README.md`, `botster-package.json`, `plugin.lua`, `docs/workspace-domain.md`, `docs/capabilities.md`, prior `docs/plans/*.md`, `test/fixtures/workspaces/contract.json`, `test/plugin_runtime_test.lua`, `script/test`, and `script/hub_acceptance_smoke`.
- Contract context from Plan Review: botster-core origin/main `978c436865c215828b02a8b0fcca5f8d89413e96` is pinned by botster-hub and defines `metric_grid`, `toolbar`, `table`, `status_badge`, `empty_state`, `section`, and `panel` as snake_case UiNode kinds. `action_bar` is not valid; core explicitly rejects it as an unknown/deferred node kind in `crates/botster-core/tests/ui_contract_test.rs:832`.

## Scope

- Replace the current minimal app/settings surface shape in `plugin.lua` with structural UINode application primitives already supplied by the closed renderer dependencies.
- Make the first app screen an operator workspace index over plugin-owned workspace read models:
  - workspace name and purpose;
  - repository label/reference and spawn target label/reference;
  - status;
  - session count;
  - selected/default template summary;
  - cached template diagnostics.
- Use the required valid primitive vocabulary in the plugin-authored UI tree: `metric_grid`, `toolbar`, selectable `table` or `list`/`list_item` rows, `empty_state`, `status_badge`, and `section`/`panel` semantics. Do not emit `action_bar`; the ticket wording says "toolbar/action_bar", but the hub-locked UiNode contract accepts `toolbar` and rejects `action_bar`.
- Keep creation and spawn affordances wired only through registered `ui_action` contracts already present in the plugin. Forms may remain if their submit path is the supported action contract; avoid adding custom action shapes.
- Update the settings surface to show effective archive policy, package/workspace defaults, spawn target/default template diagnostics, and repair/create/spawn affordances only through supported UINode action contracts.
- Preserve current stable package surface ids, navigation ids, route ids, action ids, plugin tools, entity family, and workspace read-model fields unless the hub-locked UINode contract requires a narrow field rename.
- Update tests and docs so the production path is about structured primitives rendered by hub/web/TUI clients, not iframe/custom HTML or source-only JSON.

## Non-scope

- No hub/core, botster-web, or botster-tui primitive implementation. Those are dependency tickets and are recorded closed for this run.
- No iframe, custom HTML, plugin asset bridge, or raw renderer-specific markup for the basic workspace index.
- No new Workspaces authority over hub-owned spawn targets, worktrees, session templates, session lifecycle, process state, PTY state, terminal scrollback, package admission, or host filesystem paths.
- No new plugin persistence schema unless a displayed value cannot be derived from existing workspace records, read models, package config, or cached diagnostics.
- No Project Pipelines product UI or workflow logic inside `botster-workspaces`.
- No broad redesign of CRUD, default template selection, or `spawn_session_template` behavior beyond keeping visible actions wired to the existing action contracts.

## Assumptions and unknowns

Assumptions:

- The two closed dependency tickets mean the local acceptance hub and botster-web renderer can consume the new UINode application primitives. The known TUI production plugin-surface path still flattens composite trees to text and discards HitMap per `finding_1783535917_129676`, so botster-web is the acceptance client for the ticket's "web and/or TUI" criterion. TUI structured plugin-surface rendering is out of scope and a follow-up candidate.
- The Workspaces plugin should author concrete structural UI from plugin-owned `plugin_db` state for this milestone, matching the existing domain note that live plugin entity broadcast is not required here.
- Existing `botster_workspaces.create_workspace` and `botster_workspaces.spawn_default_session` action handlers remain the supported action contracts for create/spawn affordances.
- "Table/list selection" can be satisfied with the core-supported `table` primitive if botster-web renders it on the installed surface path, otherwise with supported `list`/`list_item` rows. Do not invent private `row`, `binding`, or `action_bar` nodes.
- Status and diagnostic badges are presentation of plugin-owned read-model fields; they must not resolve or mutate hub-owned resources during render.

Resolved contract facts from botster-core `978c436`:

- Valid UiNode kinds use snake_case serialization. The relevant accepted kind names are `panel`, `metric`, `metric_grid`, `toolbar`, `status_badge`, `section`, `empty_state`, `list`, `list_item`, `table`, `button`, `icon_button`, `form`, `form_field`, `text_input`, `textarea`, `checkbox`, and `select`.
- Action-bearing prop keys are snake_case, including `action`, `primary_action`, `secondary_action`, and `row_action`; do not use camelCase keys such as `primaryAction`.
- Core validates props as well as node kinds. A tree made only of accepted kinds can still fail `UiNode::validate()` if it carries invalid props.

Remaining unknown for Implementer to resolve from renderer behavior, not core grammar:

- Whether the installed botster-web surface path renders `table` well enough for the workspace index, or whether the safer shape is a selectable `list`/`list_item` composition while still satisfying the ticket's "table/list selection" wording.

## Affected surfaces/files

- `plugin.lua`: main implementation surface. Replace `workspaces_surface`, `settings_surface`, `list_item`, `workspace_list_children`, and related UI helper functions around lines 850-1091 with structural UINode helpers and rows. Keep CRUD/read-model/action handlers intact unless a UI contract change forces a narrow helper change.
- `test/plugin_runtime_test.lua`: update the surface smoke validator and assertions around lines 127-148 and 532-557. `section` must no longer be treated as invalid because the hub contract supports it. Add assertions that app/settings surfaces include the required primitive types and still render workspace text, session counts, template summaries, diagnostics, and action ids. Treat this Lua validator as a fast smoke only; real contract proof comes from `script/validate_ui_node_contract`.
- `script/hub_acceptance_smoke`: strengthen runtime proof so `plugin_surface_render` for `workspaces` and `workspaces-settings` verifies the new primitives are present after install/enable, not only that old text exists.
- `README.md`: update the app/settings discovery section to document the structured UINode primitive surface shape and supported action-contract boundary.
- `docs/workspace-domain.md`: update the surface/read-model section if implementation changes the documented "concrete structural UI" shape or adds stable UI expectations.
- `test/fixtures/workspaces/contract.json` and `script/test`: update only if docs/fixture contract currently asserts the old minimal list/form surface shape or needs new primitive-contract checks.
- `docs/plans/adopt-uinode-application-primitives.md`: this plan artifact.

Botster layers touched: first-party Lua plugin surface, plugin runtime tests, real hub acceptance smoke, and repo docs. Hub/core, browser, and TUI are consumer layers for acceptance only.

Worktree/target assumptions: this run is already bound to target `tgt_71266a8d976d4535902ffed09c18a7ba` and the assigned Project Pipelines worktree. Acceptance against a real hub must use an explicit hub binary/data dir/socket that includes the closed dependency work; do not rely on an ambient stale hub.

Pipeline gates/artifacts: Plan gate should carry this document plus checklist evidence. Implementer must attach command output for `script/test`, `BOTSTER_CORE_PATH=<botster-core@978c436> script/validate_ui_node_contract`, and `script/hub_acceptance_smoke`.

## Risks

- Schema drift risk: guessing node property names could pass Lua tests while failing hub validation and web renderers. Mitigation: emit only core `978c436` snake_case kinds/props and require `script/validate_ui_node_contract`.
- TUI limitation risk: the closed TUI dependency still leaves production plugin surfaces flattened into one text preview and non-interactive. Mitigation: satisfy this ticket's "web and/or TUI" acceptance through botster-web plus hub `plugin_surface_render`; keep TUI structured rendering out of scope.
- Authority boundary risk: adding diagnostics by synchronously resolving spawn targets/templates during render could move hub authority into the plugin surface. Mitigation: render cached plugin-owned references and diagnostics; keep hub resolution in existing tool/action paths.
- Unwired implementation risk: adding helper functions without changing `workspaces_surface`/`settings_surface` would leave production routes on the old surface. Mitigation: tests must invoke the registered surface handlers and real `plugin_surface_render`.
- Test drift risk: existing tests currently mark `section` invalid, which conflicts with this ticket's required section/panel semantics. Mitigation: update the Lua smoke validator, but do not treat that edit as contract proof; `script/validate_ui_node_contract` is the conformance gate.
- UX regression risk: replacing forms with a denser index could accidentally remove create/spawn affordances. Mitigation: keep visible action-contract-backed controls and assert action ids remain reachable.
- Checklist persistence risk: Project Pipelines checklist create calls may time out after successful writes. Mitigation: check `run_checklists` before retrying, and preserve vault-note provenance, convention-conflict result, verification plan, and capture decision in artifacts/gates.

## Acceptance checks and tests

- `script/test` passes and proves:
  - manifest/navigation/capability assertions still pass;
  - plugin CRUD, plugin_db persistence, template diagnostics, selected-template spawn request, hub-owned field rejection, and entity snapshot behavior still pass;
  - registered `workspaces_surface` and `workspaces_settings_surface` emit supported UINode trees using the required primitives;
  - app surface renders workspace name, purpose, repo/spawn target, status badge, session count metric, default template summary, diagnostics, empty state, and create/spawn action ids;
  - settings surface renders effective archive policy, defaults, spawn target/template diagnostics, and supported action/form contracts;
  - no iframe/custom HTML/raw host path leakage is introduced.
- `BOTSTER_CORE_PATH=<botster-core@978c436> script/validate_ui_node_contract` passes. This is required Implement gate evidence; acceptance is not met if it is skipped. If it cannot run, the implementer must provide exact missing checkout/binary/path evidence and keep the step from advancing until the blocker is resolved or explicitly waived by review.
- `script/hub_acceptance_smoke <botster-hub.sock> [workspace-name]` passes against a real local hub with the package installed/enabled and proves:
  - package navigation still exposes app/settings surface routes;
  - `plugin_surface_render` returns the new structured UINode app/settings body;
  - rendered app/settings text still includes the created workspace, `2 sessions`, template summary, diagnostics, and settings/archive-policy content;
  - primitive presence is checked from the rendered body, not from source scans;
  - workspace template spawn path still reaches `kind: spawned` when a hub session template is available.
- If a botster-web packaged smoke exists for installed plugin surfaces, run the narrow surface render path there as additional proof. If not, record the gap and rely on hub `plugin_surface_render`, `script/validate_ui_node_contract`, and dependency closure. Do not require TUI structured surface smoke for this ticket because the current production TUI path is known to flatten composite plugin surfaces.
- Any skipped acceptance must include the exact missing binary/socket/contract evidence and why the skip is unrelated to changed code.

## Vault gaps worth capturing

- Capture a Workspaces-specific note if implementation reveals a stable UINode application-surface pattern for first-party plugins: metric summary plus toolbar plus selectable table/list plus settings diagnostics.
- Capture that `action_bar` is deferred/rejected UiNode vocabulary despite this ticket's wording, so future adoption plans use `toolbar`.
- Capture if the hub-locked UINode grammar differs materially from current vault assumptions for `empty_state.primary_action`, selectable table/list rows, or action labels/icons.
- Capture if real-hub acceptance requires a reusable setup for proving plugin app/settings surfaces through web or TUI after package install.
- No convention conflict found. The only local conflict is stale test validation that rejects `section`; the ticket and closed dependencies supersede that test assumption.
