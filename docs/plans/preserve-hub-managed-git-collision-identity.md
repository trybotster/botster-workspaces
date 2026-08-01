# Preserve Hub managed-Git collision identity in Workspaces

## Target and routing

- Ticket: `ticket_1785625579_666761`, “Workspaces: preserve Hub managed-Git collision identity”.
- Target repository: `trybotster/botster-workspaces`.
- Target ID: `tgt_71266a8d976d4535902ffed09c18a7ba`.
- Run: `run_1785625592_402690` in the dedicated `project-pipelines/ticket_1785625579_666761` worktree.
- Repository charter: [[botster-workspaces-playbook]]. The supplied routing map omitted this repository; human answer `question_1785625727_734956` confirmed the exact charter. The omission is workflow metadata debt, separately recorded as Project Pipelines ticket `ticket_1785626117_842560`; it does not block or broaden this Workspaces repair.

## Context loaded

Role and repository guidance was loaded in the required order:

- [[planner-playbook]]
- [[botster-planner-playbook]]
- [[botster-workspaces-playbook]]
- Targeted Botster maps and atomic notes: [[botster-architecture]], [[cli-patterns]], [[spa-patterns]], [[project pipeline orchestration belongs in a device-level botster plugin]], [[project pipelines needs an operator workbench not more primitives]], [[project pipelines ui contract belongs in the plugin readme]], [[botster orchestration should spawn agents with explicit target ids]], [[botster orchestration prompts must bind agents to explicit worktrees]], [[botster pipeline needs continuous product owner between agent steps]], [[plan agents must author vault context as wikilinks not home paths]], [[pipeline vault checklists must cite exact resolvable note titles]], [[vault example paths are not repository placement conventions]], [[workspaces are semantic groupings by purpose not by branch]], [[botster workspace records are plugin owned references not hub authority]], [[botster plugin entities are canonical for plugin-owned dynamic state]], [[botster package manifests and lockfiles should declare capabilities and provenance]], [[botster hub gravity must be watched before it becomes the new monolith]], [[acceptance harness region oracles must key on node identity not concatenated text]], and [[plugin ui action ids are a two site change and hub fails closed on unregistered ids]].
- [[project-pipelines-playbook]] was loaded last because the missing Workspaces routing entry implicated sourced workflow policy. Its repair remains separately owned by `botster-project-pipelines` and is non-scope here.

Repository/runtime context inspected:

- `README.md`, `botster-package.json`, `plugin.lua`, `test/plugin_runtime_test.lua`, `test/fixtures/workspaces/contract.json`, `script/test`, `script/test-hub-flow`, `script/hub_acceptance_smoke`, `script/validate_ui_node_contract`, existing `docs/plans/*.md`, recent history, and the clean target worktree.
- The production package manifest loads `plugin.lua`; `botster_workspaces.spawn` calls only `botster.capabilities.session_templates.ensure_worktree_and_spawn`.
- At `plugin.lua:663-667`, a rejected capability result reads `result.error.code`, otherwise falling back to `hub_spawn_rejected`.
- The Lua fixture at `test/plugin_runtime_test.lua:79-85` models the stale `{code,message}` error shape and therefore passes without exercising the real Hub contract.
- Hub revision `fab44c5de7b28a8756268608662d2b870efb001a` serializes `ManagedGitError` directly as `{"kind": ..., "message": ...}` under `error`; its managed-Git implementation emits `branch_in_use` and `path_collision`.
- Parent integration revision `13924bbc3cf835835732d1d6f4a0e90167daa8dd` already has the downstream `collision_proof!` oracle. It creates a branch checked out in a foreign worktree and a foreign sentinel at the deterministic managed path, then requires exact error identity plus unchanged workspace references, Hub session IDs, Git branches/worktrees, and foreign resources. Evidence `/private/tmp/botster-workspaces-shared-stack-evidence-13924bb/failure.json` shows that unchanged oracle currently fails with `branch_in_use collision returned hub_spawn_rejected`.
- Baseline `script/test` passes on `737ec8133c5f985f4c2bd5a369365049558afa56`, confirming the focused test currently misses the production-shaped defect.

## Scope and decision

Cold-switch the Workspaces adapter from `hub_error.code` to the Hub-owned `hub_error.kind` field. Preserve the Hub-provided message and preserve the existing `hub_spawn_rejected` fallback for malformed or untyped rejection tables. Do not add a `code` compatibility fallback, collision allowlist, translation table, new error type, or wrapper abstraction: the Hub already owns the typed collision vocabulary.

In scope:

- Change the rejected-result adapter in `plugin.lua` to surface `result.error.kind` as the Workspaces `error.code` exposed by the existing plugin result contract.
- Replace the stale Lua rejection fixture with the real `{kind,message}` shape and prove both `branch_in_use` and `path_collision` survive unchanged while membership remains unchanged.
- Prove the committed producer through the existing parent real-Hub collision oracle, unchanged, using Hub `fab44c5` (or a later explicitly recorded compatible revision) and matching worker provenance.

Non-scope:

- Any Hub managed-Git, admission, locking, path selection, rollback, serialization, or error-vocabulary change.
- Git or filesystem operations in `plugin.lua`; Workspaces must not inspect, create, repair, or clean branches, worktrees, paths, or repositories.
- Workspace schema, grouping, membership semantics, UI tree/actions, lifecycle projection, Web/TUI renderer behavior, or session spawning success behavior.
- Compatibility reads of both `kind` and `code`, versioned error names, configuration, speculative abstraction, broad refactoring, adjacent cleanup, or weakening/changing the parent integration oracle.
- Project Pipelines routing implementation; `ticket_1785626117_842560` owns that separate repository.

## Ownership boundaries and dependencies

`botster-workspaces` owns adapting the Hub capability result into its existing plugin result and deciding whether a returned session UUID is recorded. It may preserve Hub-owned typed identity, but it must not reinterpret or take authority over Git collisions.

`botster-hub` remains authoritative for managed Git, collision detection, the `ManagedGitError {kind,message}` serialization, non-destructive failure behavior, sessions, and resource state. No Hub source change or blocking Hub dependency is required: revision `fab44c5` already exposes the contract needed by this repair.

Parent integration ticket `ticket_1785192726_335558` owns the complete shared Web/TUI/Hub oracle and must consume this producer repair before it can pass. That is downstream validation, not permission to edit the parent harness in this child run. There are no cross-repository implementation dependencies and no dependency edge to register for this ticket.

Project Pipelines routing follow-up `ticket_1785626117_842560` correctly targets `botster-project-pipelines` (`tgt_a72ca1a83d504385b8648f71409119ab`) and is explicitly non-blocking.

## Implementation plan

1. In the rejected-result branch of `spawn_session` in `plugin.lua`, read `hub_error.kind` instead of `hub_error.code`; retain the current message projection and malformed-result fallback. Do not touch the `pcall` worker-error branch, successful returned-UUID validation/persistence, or any Hub capability request fields.
2. In `test/plugin_runtime_test.lua`, make the fake `ensure_worktree_and_spawn` emit the actual Hub rejection shape. Exercise `branch_in_use` and `path_collision` as separate cases, assert the exact Hub kind becomes the existing Workspaces `error.code`, assert the Hub message is retained, and assert the workspace membership count/content is unchanged after each rejection. Retain the thrown-worker and post-spawn persistence-failure cases.
3. Run the repository gate and a deliberate red/green check: the focused test must fail when the adapter is temporarily reverted to `.code`, then pass with `.kind`. Keep that temporary mutation out of the final diff.
4. Build or identify Hub `fab44c5` and its matching `botster-session-worker`, then run the existing immutable-input shared-stack harness pinned at parent revision `13924bbc3cf835835732d1d6f4a0e90167daa8dd` with the committed child checkout supplied as `workspaces_package`. Do not edit its `collision_proof!` function or reduce its assertions. Capture the resulting summary/evidence ledger showing both exact collision identities and zero state/resource mutation.
5. Confirm the final diff is limited to the adapter, focused fixture/test, and this reviewable plan. If implementation reveals any need to change Hub behavior, the parent oracle, workspace grouping, or Git resources, stop and return to Plan Review rather than expanding scope.

## Affected surfaces and files

- `plugin.lua`: production Workspaces adapter for rejected atomic managed-Git spawn results.
- `test/plugin_runtime_test.lua`: focused real-shape regression proof for both collision kinds and failure atomicity.
- `docs/plans/preserve-hub-managed-git-collision-identity.md`: repository-visible planning artifact.

Expected unchanged files include `botster-package.json`, `test/fixtures/workspaces/contract.json`, `script/test`, `script/test-hub-flow`, `script/hub_acceptance_smoke`, all workspace/domain docs, and all Hub/Web/TUI sources. The existing parent-only `script/shared_stack_acceptance` is executed as downstream proof but is not copied or edited here.

## Assumptions and unknowns

- Verified fact: the authoritative Hub value is `error.kind`, not `error.code`; both target collision kinds are stable Hub-owned strings at `fab44c5`.
- Verified fact: the public Workspaces result contract already exposes errors through `error.code`. This repair preserves that package-facing shape by sourcing its value from Hub `kind`; it does not rename the Workspaces field.
- Assumption: all typed rejections returned by this capability should preserve their Hub `kind`, not only the two collision kinds. Forwarding the field directly avoids creating a stale package-owned allowlist.
- Assumption: malformed rejection tables should retain the existing `hub_spawn_rejected` fallback. The ticket repairs typed identity and does not request fail-open behavior for untyped values.
- Unknown to resolve during final proof: the exact immutable manifest and binary paths used to rerun the parent shared-stack harness. Evidence must record harness revision `13924bbc3cf835835732d1d6f4a0e90167daa8dd`, Hub, locked Core/worker, Workspaces, Web, TUI, TUI-kit, and UI-contract revisions; mutable branch names or dirty checkouts do not count.
- No Rails convention applies. General conventions align with the plan: smallest readable change, existing framework/runtime contract, cold replacement rather than dual paths, and no speculative abstraction. No convention conflict was found.

## Risks

- A dual `kind or code` reader would hide stale fixtures and prolong ambiguity. Mitigation: cold-switch both production and focused fixture to `kind`, with a red/green revert check.
- A collision allowlist would transfer Hub vocabulary ownership into Workspaces and drop future typed errors. Mitigation: forward any valid Hub `kind` directly.
- A focused Lua-only green result could still miss real mlua serialization or plugin-worker behavior. Mitigation: require the unchanged real-Hub parent collision oracle against the committed package.
- A real-Hub check that asserts only the error string could miss destructive side effects. Mitigation: retain the parent oracle’s before/after workspace refs, Hub session IDs, Git snapshot, foreign worktree, and sentinel assertions.
- Running the parent harness against the parent checkout instead of this committed child artifact would produce irrelevant evidence. Mitigation: its immutable input manifest must name this child checkout/revision as `workspaces_package`.
- Broadening local test harnesses could duplicate and drift from the stronger parent integration oracle. Mitigation: change only the focused Lua proof locally and consume the parent oracle unchanged.

## Acceptance checks and downstream proof

Focused repository proof:

- `script/test` passes.
- `test/plugin_runtime_test.lua` supplies `{ok=false,error={kind="branch_in_use",message=...}}` and `{ok=false,error={kind="path_collision",message=...}}`; each returns the exact kind through Workspaces `error.code`, retains the message, and leaves workspace membership unchanged.
- The existing thrown worker error remains `hub_spawn_failed`; malformed/untyped Hub rejection remains `hub_spawn_rejected`; successful spawn and post-spawn persistence-failure behavior remain unchanged.
- A deliberate temporary `.kind` -> `.code` revert makes the new focused collision assertion fail, and restoring `.kind` makes it pass.
- `git diff --check` passes and `git diff --stat` confirms no unrelated product, schema, UI, Hub, Web, or TUI files changed.

Actual production path proof:

- The manifest still loads `plugin.lua`; the registered `botster_workspaces.spawn` tool/action reaches `spawn_session`, calls the real `session_templates.ensure_worktree_and_spawn`, and returns the adapted rejection without performing any Git operation or membership write.
- Use `script/test-hub-flow shared-stack run <immutable-input-manifest> <new-evidence-dir>` (or its direct `script/shared_stack_acceptance` equivalent) from parent harness revision `13924bbc3cf835835732d1d6f4a0e90167daa8dd`, with the committed child revision as `workspaces_package` and Hub `fab44c5` plus matching worker provenance.
- The unchanged `collision_proof!` must return `branch_in_use` and `path_collision` exactly; workspace `session_refs`, Hub session IDs/count, repository HEAD/branches/worktrees, the foreign checked-out worktree, deterministic collision path, and sentinel contents must all match their pre-collision state.
- Preserve the parent integration oracle’s full Web/TUI/lifecycle/provenance assertions. A collision-only bypass, hand-authored substitute result, fixture-only proof, or weakened parent check is insufficient.

## Pipeline artifacts and checklists

- Plan artifact: this file.
- Source failure evidence: `/private/tmp/botster-workspaces-shared-stack-evidence-13924bb/failure.json` (runtime-local evidence path, not a durable repository reference).
- Run checklists: `checklist_1785625946_529021` (Plan workflow discipline) and `checklist_1785625951_872108` (vault discipline).
- Final implementation evidence must attach exact commands, exit statuses, revisions, the real-Hub evidence directory/summary, convention conflict disposition, and vault capture disposition.

## Vault gaps worth capturing

- After implementation and real-Hub proof, capture an atomic gotcha that Lua adapters must preserve the serialized field name of Hub-owned typed errors (`kind` here) rather than inventing or assuming a generic `code` field. Do not write the note from planning speculation alone.
- [[botster workspace records are plugin owned references not hub authority]] is stale in its opening field examples, though its authority boundary remains correct and [[botster-workspaces-playbook]] carries the current exact-record charter. This known gap should be updated through the vault pipeline when the broader record-model capture is processed, not in this code ticket.
- The active Botster Stack Delivery prompt regressed the Workspaces route despite closed ticket `ticket_1785294426_656956`; Project Pipelines follow-up `ticket_1785626117_842560` now owns the durable workflow repair and regression proof.
