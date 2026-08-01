# Expose consumer-addressable identity for the Workspaces Spawn action

## Target and routing

- Ticket: `ticket_1785611316_167898`, “Workspaces: expose consumer-addressable identity for detail actions”.
- Target repository: `trybotster/botster-workspaces`.
- Target ID: `tgt_71266a8d976d4535902ffed09c18a7ba`.
- Run: `run_1785611327_506945` in the dedicated `project-pipelines/ticket_1785611316_167898` worktree.
- Repository charter: [[botster-workspaces-playbook]]. The supplied routing map omitted this repository; human answer `question_1785611384_596027` confirmed this charter and classified the omission as recurring workflow metadata drift rather than ownership ambiguity.

## Context loaded

Role and repository guidance was loaded in the required order:

- [[planner-playbook]]
- [[botster-planner-playbook]]
- [[botster-workspaces-playbook]]

The Botster planner and repository charter then required or implicated:

- [[botster-architecture]]
- [[cli-patterns]]
- [[spa-patterns]]
- [[project pipeline orchestration belongs in a device-level botster plugin]]
- [[project pipelines needs an operator workbench not more primitives]]
- [[project pipelines ui contract belongs in the plugin readme]]
- [[botster orchestration should spawn agents with explicit target ids]]
- [[botster orchestration prompts must bind agents to explicit worktrees]]
- [[workspaces are semantic groupings by purpose not by branch]]
- [[botster workspace records are plugin owned references not hub authority]]
- [[botster plugin entities are canonical for plugin-owned dynamic state]]
- [[botster package manifests and lockfiles should declare capabilities and provenance]]
- [[botster hub gravity must be watched before it becomes the new monolith]]
- [[acceptance harness region oracles must key on node identity not concatenated text]]
- [[botster package surface semantics live in ui contract while hub owns admission]]
- [[plugin surface actions route by explicit metadata]]
- [[plugin authored tui surfaces dispatch via action props not node id literals]]
- [[renderer state accepts only realized literal identity]]
- [[conformance helpers must dispatch the action id read from the rendered node]]
- [[runtime client acceptance must render delivered snapshots through real registry]]
- [[botster core contract surface needs consumer proof]]
- [[phase one action ids are semantic botster events not DOM event names]]

[[project-pipelines-playbook]] was not loaded: the ticket uses Project Pipelines workflow machinery, but it does not change Project Pipelines package/plugin paths or workflow policy.

Repository and consumer context inspected:

- `README.md`, `plugin.lua`, `botster-package.json`, `test/plugin_runtime_test.lua`, `test/fixtures/workspaces/contract.json`, `script/test`, `script/validate_ui_node_contract`, `script/hub_acceptance_smoke`, and `script/test-hub-flow`.
- Existing plans in `docs/plans/`, especially the lifecycle and package-surface plans, establish this repository’s plan destination and downstream-proof posture.
- Current Hub `botster-ui-contract` defines `UiAction` as renderer-neutral `id`, optional `payload`, and optional `disabled`; no new shared field is required.
- Web’s production Ionic renderer exposes a realized action as `data-action-id` and dispatches that action. The active shared-Hub Web driver currently finds Spawn by visible `Spawn` copy.
- TUI’s production acceptance helper reads actions from delivered nodes/realized hit maps and dispatches the selected action. Its active shared-Hub driver currently identifies Spawn as generic `botster_workspaces.open` plus a product payload predicate.
- Source Web finding `finding_1785611217_679800` and the amended current ticket describe the missing producer identity seam. Duplicate follow-up `ticket_1785611385_764864` was closed as subsumed before implementation.

Baseline evidence on commit `723f4a3`:

- `script/test` passes.
- `BOTSTER_UI_CONTRACT_PATH=<authoritative Hub checkout>/crates/botster-ui-contract script/validate_ui_node_contract` passes.
- `BOTSTER_HUB_BIN=<authoritative Hub checkout>/target/debug/botster-hub BOTSTER_SESSION_WORKER_BIN=<authoritative Hub checkout>/target/debug/botster-session-worker script/test-hub-flow` passes through a fresh temporary Hub, installed plugin worker, target-first Spawn, persistence, lifecycle, and cleanup.

## Decision and scope

The ticket mandates the smallest existing renderer-neutral channel, `UiAction.id`: give only the workspace-detail Spawn opener the semantic action ID `botster_workspaces.open_spawn` and register that ID to the existing `open_presentation` behavior. The Spawn node continues to carry its existing payload, label, and authored node ID, but consumers can locate the control by semantic action metadata and then dispatch the exact action/node/payload read from the realized artifact.

This is a cold replacement for the Spawn opener: it must no longer advertise generic `botster_workspaces.open`. Other presentation controls continue using that generic action because the ticket and source finding identify only Spawn, and broad action-vocabulary churn would be speculative.

In scope:

- Author the Spawn opener with `botster_workspaces.open_spawn` through the existing `UiAction` shape.
- Register that semantic action to the existing presentation handler without duplicating presentation policy.
- Preserve visible `Spawn` copy, `botster-workspaces-spawn-<workspace.id>`, and stable detail/lifecycle section IDs.
- Make package/runtime and real-Hub tests find the Spawn control by its semantic action metadata, read back its literal node/action/payload values, dispatch those exact values, and correlate the accepted action result.
- Document the package-owned semantic identity in the local README and fixture contract.
- Publish renderer-neutral owner-contract evidence that the separately routed Web and TUI adoption tickets can consume after this producer merges.

Non-scope:

- New UiNode fields, renderer-specific props, protocol/schema changes, or Core/Hub contract work.
- Web DOM policy, React branches, TUI renderer policy, client-local Workspaces state, or edits in either consumer repository.
- Copy changes, aria-label changes, dynamic node-ID reconstruction, text parsing, or a product-specific acceptance protocol.
- Renaming the other detail actions, changing workspace records, lifecycle grouping, target/template selection, atomic Spawn semantics, or persistence.
- Compatibility aliases, dual Spawn action IDs, fallback selectors, optional configuration, broad refactors, or adjacent cleanup.
- Repairing the Project Pipelines routing prompt.

## Repository ownership and cross-repository dependencies

`botster-workspaces` owns the semantic action vocabulary and owner-authored `UiNode` tree, so the producer change belongs in `plugin.lua` and package tests/docs. Hub remains the authority for contract validation, package admission, plugin-worker dispatch, target/template resolution, and atomic spawning. Web and TUI remain generic consumers of delivered action metadata.

This producer ticket has no blocking dependencies. The earlier edges to the in-flight Web driver ticket `ticket_1785602852_464676` and TUI driver ticket `ticket_1785602853_851250` were inverted and have been removed. Those tickets finish their already-authorized pre-switch driver work unchanged; neither owns adoption of `open_spawn`.

Post-merge consumption is separately routed and does not block this producer run:

- `ticket_1785612604_234437` (`botster-web`, `tgt_40abcf71ccf049f4ac0c99953a799869`) owns replacing visible-copy Spawn selection with realized `data-action-id='botster_workspaces.open_spawn'`, exact read-back dispatch, and correlated browser request/result proof after this producer merges.
- `ticket_1785612604_598776` (`botster-tui`, `tgt_c3d470bab78549df920a41e8fb0e58d8`) owns replacing generic `botster_workspaces.open` plus dialog-payload discrimination with the realized `open_spawn` action through the delivered tree/hit map after this producer merges.
- Final integration ticket `ticket_1785192726_335558` depends on this producer and both adoption tickets and owns their combined clean-Hub downstream gate.

These downstream edges are recorded on the adoption/integration tickets, not as dependencies of this producer. No Web or TUI source changes belong in this worktree.

## Implementation plan

1. In `plugin.lua`, change the detail Spawn button’s `UiAction.id` from `botster_workspaces.open` to `botster_workspaces.open_spawn`. Add one `ui_action` descriptor for that exact semantic ID and route it to `open_presentation`. Keep the existing Spawn payload, node ID, label, presentation key/value, and target-first dialog flow unchanged. Do not retain a second Spawn handler/action path.
2. In `test/plugin_runtime_test.lua`, add a traversal assertion that locates exactly one detail Spawn opener by `props.action.id`, not by label or reconstructed node ID. Assert the read-back node ID remains the existing authored value, the label remains `Spawn`, the payload still selects the workspace and target-first dialog, dispatch uses the read-back action/payload, and the accepted result echoes that action ID before revealing the target form. Add a negative assertion that the Spawn node no longer advertises generic `botster_workspaces.open`.
3. In `test/fixtures/workspaces/contract.json` and `script/test`, record/assert the Spawn opener’s semantic action ID and required registered handler token while leaving the existing detail-action vocabulary intact. Keep fixture additions limited to the new public seam.
4. In `script/hub_acceptance_smoke`, add a generic recursive action lookup and use it to find the delivered Spawn control by `props.action.id == botster_workspaces.open_spawn`. Read `id`, action ID, and payload from that delivered node, dispatch those exact values, and require the action result to echo the same identity and open the existing target-first form. Do not use `botster-workspaces-spawn-#{workspace_id}` as the lookup oracle.
5. In `README.md`, document that the detail Spawn opener exposes `botster_workspaces.open_spawn` as its renderer-neutral consumer identity and that consumers must read and dispatch realized action metadata rather than parse copy or synthesize node IDs.
6. Run the repository and real-Hub producer gates and attach the exact committed Workspaces revision plus semantic action evidence for downstream adoption. Do not wait for, edit, or run post-change Web/TUI adoption as a gate of this producer. The separately routed adoption tickets and final integration ticket own that work after merge.

## Affected surfaces and files

- `plugin.lua`: owner-authored detail Spawn `UiAction` and handler registry.
- `test/plugin_runtime_test.lua`: focused producer identity/read-back/dispatch regression coverage.
- `test/fixtures/workspaces/contract.json`: package contract expectation for the Spawn opener semantic ID.
- `script/test`: fixture/source contract assertions.
- `script/hub_acceptance_smoke`: delivered-tree semantic lookup and exact read-back dispatch proof.
- `README.md`: local package UI contract.
- `docs/plans/expose-consumer-addressable-detail-action-identity.md`: reviewable plan artifact.

`botster-package.json`, lifecycle bindings, workspace persistence, domain/capability docs, Hub source, Web source, and TUI source should remain unchanged in this repository run unless implementation discovers direct contradictory evidence and returns to Plan Review.

## Assumptions and unknowns

- Ticket requirement: `botster_workspaces.open_spawn` is the semantic name for opening the target-first Spawn presentation; it is distinct from mutation action `botster_workspaces.spawn` and selector action `botster_workspaces.select_spawn_target`.
- Assumption: multiple `ui_action` descriptors may share the existing `open_presentation` callback; current registration and action-result behavior route by descriptor ID and echo the request action ID.
- Ticket requirement: only the Spawn opener cold-switches from generic `botster_workspaces.open` plus dialog-payload discrimination; other detail actions remain unchanged.
- Verified contract fact: `UiAction.id` is already admitted by Hub, exposed by Web, and consumed by TUI, so no contract release or renderer change is a prerequisite.
- Known sequencing: the in-flight Web/TUI driver tickets complete unchanged against the pre-switch producer; `ticket_1785612604_234437` and `ticket_1785612604_598776` own post-merge adoption, and final integration owns combined proof.
- No Rails convention applies to this Lua package. General conventions do apply: readable minimal changes, existing contract primitives first, cold replacement of the ambiguous Spawn action, and no speculative abstraction.
- No convention conflict was found.

## Risks

- Action-routing regression: changing the advertised ID without registering it would make the control discoverable but dead. Mitigation: producer runtime and real-Hub tests dispatch only the ID read from the delivered node and require an accepted matching result.
- Semantic collision: reusing `botster_workspaces.spawn` for the opener would conflate presentation with mutation. Mitigation: use the distinct `open_spawn` semantic ID and retain the existing mutation/target-selection IDs.
- False-positive acceptance: locating by node ID or label and then dispatching a constant would fail to prove the new seam. Mitigation: locate by action metadata and pass the captured action/node/payload through every request assertion.
- Cross-client drift: Web or TUI may keep old label/generic-action selectors. Mitigation: the separately routed adoption tickets and final integration gate own correction after producer merge; this package must not add a fallback.
- Unintended broad churn: renaming all presentation actions could break unrelated consumer paths. Mitigation: change only the source-finding Spawn opener.
- Stable-contract regression: visible copy or section IDs could move while tests remain green. Mitigation: assert the existing label, authored node ID, and detail/lifecycle section IDs remain unchanged.
- Stale binary evidence: the baseline Hub and worker binaries had different mtimes, so a same-version local build can hide contract drift. Mitigation: Implement must record actual Hub and worker source revisions, binary paths, and mtimes used for final proof, and rebuild both when they cannot be tied to the same Hub source revision and `botster-ui-contract` checkout validated by this run.

## Acceptance checks and downstream proof

Repository gates:

- `script/test` passes and proves the fixture/source contract, exact semantic ID, unchanged copy/IDs, and no generic action remaining on Spawn.
- `BOTSTER_UI_CONTRACT_PATH=<exact current Hub botster-ui-contract crate> script/validate_ui_node_contract` passes for the owner-authored tree.
- A focused red/green regression demonstrates that reverting Spawn to `botster_workspaces.open`, dispatching a hardcoded ID instead of the read-back ID, or omitting the new handler makes the appropriate test fail.

Real Hub/plugin-worker gate:

- `BOTSTER_HUB_BIN=<exact current Hub binary> BOTSTER_SESSION_WORKER_BIN=<matching worker> script/test-hub-flow` passes from a fresh temporary Hub data directory.
- Evidence records the actual package/Hub/worker source revisions, binary paths and mtimes, installed package path/revision, cold `plugin.db`, delivered Spawn node ID/action ID/payload, matching `plugin_surface_action` request/result, accepted target-first presentation, exact returned session UUID persistence, failure atomicity, lifecycle behavior, and non-destructive cleanup. Rebuild Hub and worker when those binaries cannot be tied to the validated Hub source revision.
- The smoke must locate the Spawn opener by semantic action metadata and dispatch exact read-back values; source existence or reconstructed dynamic IDs are insufficient.

Deferred downstream proof required by [[botster-workspaces-playbook]], but explicitly not a gate of this producer run:

- Web adoption ticket `ticket_1785612604_234437` consumes the merged producer, locates `data-action-id='botster_workspaces.open_spawn'`, reads realized action/node identity, and correlates exact Ionic/WebRTC request/result without visible-copy parsing or node-ID construction.
- TUI adoption ticket `ticket_1785612604_598776` consumes the merged producer, finds the exact realized semantic action through the production tree/hit map, and correlates keyboard read-back dispatch/result without client-specific Workspaces policy.
- Final integration ticket `ticket_1785192726_335558` combines the merged producer and both adoption artifacts for the full target-first Spawn and lifecycle matrix.
- This producer advances after its local package/runtime and real-Hub gates. It must not wait on consumer adoption, consume dirty sibling worktrees, or add compatibility behavior to make pre-switch consumers pass.

## Vault gaps worth capturing

- The Botster Stack Delivery routing prompt still omits `botster-workspaces` even though `ticket_1785294426_656956` is closed and [[botster-workspaces-playbook]] exists. Capture the concrete recurrence after the Project Pipelines owner verifies why the sourced pipeline definition drifted.
