# Make botster-workspaces own workspace templates and default session launches

## Context loaded

- Pipeline ticket: `ticket_1782761720_571499`, "Make botster-workspaces own workspace templates and default session launches".
- Current run: `run_1782761798_650210`, Plan step `botster_plan`.
- Prior artifacts, findings, questions, and answers: none in current pipeline context.
- Gate prompt: attach context loaded, scope/non-scope, assumptions/unknowns, affected files, risks, acceptance checks/tests, and vault gaps.
- Project Pipelines checklist evidence: `project_pipelines_create_vault_checklist` timed out with `plugin worker invoke timeout`; per [[project pipelines checklist worker timeouts require artifact evidence fallback]], checklist evidence is preserved in this plan artifact and gate evidence.
- Required vault context read: [[identity]], [[goals]], [[planner-playbook]], [[botster-planner-playbook]], [[botster-architecture]], [[cli-patterns]], [[spa-patterns]], [[project pipeline orchestration belongs in a device-level botster plugin]], [[project pipelines needs an operator workbench not more primitives]], [[project pipelines ui contract belongs in the plugin readme]], [[botster orchestration should spawn agents with explicit target ids]], [[botster orchestration prompts must bind agents to explicit worktrees]], [[plan agents must author vault context as wikilinks not home paths]], [[botster workspace records are plugin owned references not hub authority]], [[workspace session templates are daemon references not lua capabilities]], [[botster plugin entities are canonical for plugin-owned dynamic state]], [[botster plugin runtime data must not live in the plugin source tree]], [[plugin surface handlers must validate against hub locked uinode contract]], and [[botster plugins need headless real-runtime test harnesses]].
- Repo context inspected: `README.md`, `botster-package.json`, `plugin.lua`, `docs/workspace-domain.md`, `docs/capabilities.md`, `docs/plans/define-workspace-domain-contract.md`, `test/fixtures/workspaces/contract.json`, `test/plugin_runtime_test.lua`, `script/test`, `script/hub_acceptance_smoke`, and `script/validate_ui_node_contract`.
- Verification during planning: `script/test` passed on 2026-06-29.

## Scope

- Harden the existing `botster-workspaces` plugin as the owner of plugin-owned workspace records, local repo references, spawn target references, grouped session references, default session template references, cached diagnostics, settings, and workspace read models.
- Preserve the authority boundary: workspace records hold references and selected defaults; hub session-template APIs resolve and spawn actual sessions.
- Ensure default launch requests use the hub daemon `spawn_session_template` contract and carry only hub-approved template data/context such as `workspace_id`, prompt, ticket id, and branch name.
- Support both interactive and accessory PTY intents as reference metadata through template fields such as role, group, accessory, and selected state, without introducing agent-specific runtime concepts.
- Keep Project Pipelines out of the plugin contract except as this delivery pipeline's workflow.
- Keep app/settings surfaces consumable by web/TUI through descriptor-backed structural UI over plugin-owned state.
- Prove the production path by enabling the plugin on a real local hub, creating/listing/updating a workspace, selecting/requesting a default template launch, sending the returned template spawn request through the daemon, attaching/draining output, and rendering app/settings surfaces.

## Non-scope

- No Project Pipelines product logic, MCP tools, gates, run behavior, or UI inside `botster-workspaces`.
- No new hub/core session-template registry, target admission, process spawn, PTY, terminal, filesystem, or package registry authority.
- No raw executable/argument/PTY/spawn-target/filesystem request construction in the workspace plugin.
- No broad Botster core, TUI, SPA, or hub refactor unless a current contract mismatch blocks acceptance.
- No new runnable app process for `botster-workspaces`; the package remains a Lua plugin entrypoint plus surfaces/tools.
- No speculative configuration UI beyond the already documented update-driven default template selection path.

## Assumptions and Unknowns

Assumptions:

- The current repo already contains the previous contract pass; this ticket should harden runtime and real-hub acceptance rather than redesigning the domain model.
- The current hub daemon session-template contract exposes `list_session_templates` and accepts `spawn_session_template` requests over the daemon socket.
- `script/test` is the repo-approved lightweight harness; `script/hub_acceptance_smoke` is the real local hub path proof.
- The plugin should return a daemon `spawn_session_template` request when a direct worker-side template spawn bridge is absent; the daemon submission is the production user path that proves hub authority.
- Accessory/interactive PTY intent is workspace-owned metadata about a referenced hub template, not a separate workspace-owned runtime class.

Unknowns for Implementer to confirm:

- Whether the target hub revision exposes direct worker-side `botster.capabilities.session_templates.spawn`; if not, keep the current daemon-request fallback and prove it through `script/hub_acceptance_smoke`.
- Whether `script/hub_acceptance_smoke` currently has all required fixture setup documented or needs a small README/local-dev update to make the real-hub acceptance repeatable.
- Whether `script/validate_ui_node_contract` can be run in this worktree with a locked `BOTSTER_CORE_PATH`; if unavailable, document the skip and rely on hub smoke surface render as runtime proof.

## Affected Surfaces and Files

- `plugin.lua`: workspace CRUD/update/delete, template reference normalization, diagnostics refresh, selected default template launch request, read models, and app/settings surface renderers.
- `botster-package.json`: capability and surface descriptors; no runnable entrypoint unless a separate ticket requires a launchable app process.
- `README.md`: runtime contract, local development, real hub smoke flow, and explicit statement that default template selection is update/tool-driven.
- `docs/workspace-domain.md`: authoritative workspace/default-template/session-group/update/spawn/delete/read-model contract.
- `docs/capabilities.md`: plugin-owned state versus hub-owned authority and current manifest capability mapping.
- `test/fixtures/workspaces/contract.json`: fixture contract for workspace records, template refs, operations, and negative assertions.
- `test/plugin_runtime_test.lua`: Lua runtime coverage for plugin tools, persistence behavior, selected template requests, hub-owned field rejection, read models, and surfaces.
- `script/test`: repo-local contract, leak, and runtime test harness.
- `script/hub_acceptance_smoke`: real local hub proof for plugin enablement, tools, workspace create/list/update/show/snapshot, default session-template spawn, terminal output, and surfaces.
- `script/validate_ui_node_contract`: optional hub-locked UiNode validation when `BOTSTER_CORE_PATH` is available.

## Risks

- Returning or persisting raw paths, process commands, target records, or PTY details would violate the workspace plugin/hub authority split and the no-PII requirement.
- Treating daemon session-template APIs as plugin-local Lua authority would contradict [[workspace session templates are daemon references not lua capabilities]] unless the current hub explicitly provides that worker capability.
- A test that only inspects `daemon_request` shape is insufficient; acceptance must prove the request is consumed by the daemon and produces an attachable session.
- Surface tests can pass against synthetic Lua tables while failing in the hub; either validate against `UiNode` or prove through `plugin_surface_render` on the real hub.
- Long generated session ids previously caused runtime errors in the session-template path; keep generated ids short and covered by acceptance.
- Checklist persistence is currently unreliable; preserve workflow evidence in this artifact and gate evidence.

## Acceptance Checks and Tests

- `script/test` passes, including manifest/docs/fixture checks, Lua runtime behavior, no Project Pipelines implementation, no direct host filesystem APIs, and PII/leak scans.
- `script/hub_acceptance_smoke <botster-hub.sock> [workspace-name]` passes against a real local hub with the package enabled and at least one session template available.
- Real-hub smoke evidence must show:
  - plugin tools are listed through `plugin_mcp_list_tools`;
  - `list_session_templates` returns a template;
  - `botster_workspaces.create` creates or idempotently finds a workspace;
  - `botster_workspaces.update` stores grouped session references;
  - `botster_workspaces.refresh_template_diagnostics` preserves and validates the template reference;
  - `botster_workspaces.spawn_default_session` selects `spawn_session_template`;
  - the returned daemon request is sent to the hub and returns `kind: spawned`;
  - attach/drain observes expected template output;
  - list/show/entity snapshot expose workspace-owned read models;
  - app and settings surfaces render through `plugin_surface_render`.
- If `BOTSTER_CORE_PATH` is available, `script/validate_ui_node_contract` passes against the hub-locked `botster_core::UiNode` contract.
- Any skipped real-hub or UiNode validation must include exact blocker evidence, not a generic environment excuse.

## Vault Gaps Worth Capturing

- If implementation changes the daemon-request fallback or direct worker capability boundary, update [[workspace session templates are daemon references not lua capabilities]] with the new proven contract.
- If the real-hub smoke setup requires additional template fixture packages or launch steps, capture a durable note for the repeatable `botster-workspaces` acceptance harness.
- No new durable convention is needed for the current plan shape if implementation only tightens the existing contract and acceptance evidence.
