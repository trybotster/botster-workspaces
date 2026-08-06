# Migrate Workspaces to authoritative session types

## Ticket and routing

- Ticket: `ticket_1785984128_479155`, “Workspaces: migrate package to authoritative session types”.
- Target: `tgt_71266a8d976d4535902ffed09c18a7ba`, resolved through the admitted spawn-target registry to `trybotster/botster-workspaces` (`botster-workspaces`).
- Run: `run_1785987292_480836`, worktree branch `project-pipelines/ticket_1785984128_479155` at `7587c7f`; the worktree remote is `https://github.com/trybotster/botster-workspaces.git`.
- Repository charter: [[botster-workspaces-playbook]].
- Role and stack context: [[planner-playbook]], [[botster-planner-playbook]], [[botster-architecture]], [[cli-patterns]], and [[spa-patterns]].
- Targeted guidance: [[workspaces are semantic groupings by purpose not by branch]], [[botster workspace records are plugin owned references not hub authority]], [[botster plugin entities are canonical for plugin-owned dynamic state]], [[botster package manifests and lockfiles should declare capabilities and provenance]], [[botster hub gravity must be watched before it becomes the new monolith]], [[acceptance harness region oracles must key on node identity not concatenated text]], [[plugin ui action ids are a two site change and hub fails closed on unregistered ids]], [[plugin capability tests must validate against real lua runtime table not injected stubs]], [[workspace session templates are hub owned capabilities callable from lua workers]], [[session template override sources use package device repo explicit precedence]], and [[cold turkey migrations eliminate dual code paths and version suffixes]].
- Project Pipelines package/plugin code and workflow policy are not changing, so [[project-pipelines-playbook]] is intentionally not a task-surface overlay. Project Pipelines is used only to record this plan, gate, dependency, artifact, and vault-checklist evidence.

## Dependency state

The Hub prerequisite is already registered and closed as `ticket_1785970233_236046` against Hub target `tgt_7e208a0c76a44980a83b63af976b1f22`. Its merged contract is `trybotster/botster-hub` commit `8a60bd58841179f8b1fd4040d9362d18ea244230` (PR #193): daemon protocol 6, conformance revision 31, `session_types`, `session_type_id`, and the `session_type_spawn` / `session_type_managed_git_spawn` scopes.

The normal npm registry publishes the corresponding downstream contract as `@trybotster/hub-test-support@0.1.24`, integrity `sha512-n0/DDMw5PmnFdxp54dk4Y4pdAM0VfotQblBnamqkViwbmJgmSS7ZrAFPskzOcVZ70hHgJdfHaH4UwArwP0DvXw==`. Verification must consume that registry coordinate from a clean temporary npm consumer; it must not use a local tarball or sibling-worktree override. The npm artifact proves the public protocol bytes and provenance, while a real Hub binary from the merged Hub commit proves runtime behavior.

No additional cross-repository implementation is part of this run. A missing or incompatible Hub artifact is a dependency failure to report against the Hub target, not permission to patch Hub from this worktree.

## Scope

Cold-replace the active Workspaces package contract with Hub session-type vocabulary:

1. Change the Workspaces manifest capability scope to `session_type_managed_git_spawn`.
2. Change package and repository acceptance declarations from `session_templates` to `session_types`, including `.botster/session-types.json`, and supply the authoritative semantic descriptor fields required by protocol 6 (`role`, `interaction`, `traits`, and `lifecycle`) while preserving launch/context fields.
3. Change the production Lua boundary from `botster.capabilities.session_templates` to `botster.capabilities.session_types`.
4. Consume list rows only through `session_type_id`; remove `template_id` / bare-`id` list-row fallbacks and result-wrapper fallbacks rather than retaining aliases.
5. Rename the Workspaces spawn request, MCP input schema, form field, node ids, locals, errors, and active fixture/test vocabulary from template terms to `session_type_id` / session types. Keep `session_id` only where it denotes the canonical spawned session UUID.
6. Preserve the existing target-first, Hub-owned managed-Git operation and failure atomicity: call only `session_types.ensure_worktree_and_spawn`, append exactly `result.session_id` after success, and record nothing on rejection or worker failure.
7. Update active package documentation, contract fixtures, repository test guards, and both real-Hub acceptance harnesses to describe and exercise the new contract.

## Non-scope

- No Hub, Core, Web, TUI, TUI-kit, or Project Pipelines source changes.
- No session-type CRUD, source precedence, descriptor taxonomy, spawn admission, Git/worktree policy, or lifecycle authority in Workspaces; all remain Hub-owned.
- No changes to the five-field workspace record, membership semantics, plugin.db schema, workspace entity family, `/session` lifecycle bindings, surface action ids, or grouping-only deletion.
- No compatibility aliases, dual manifest keys, dual Lua capability tables, acceptance of `template_id`, or fallback decoding of old list rows.
- No npm/build toolchain added to this Lua package. The published npm artifact is consumed in a clean temporary verification consumer, not made a production dependency.
- Existing `docs/plans/` and `docs/reports/` files that describe completed historical tickets remain historical artifacts. The cold-cut token audit covers current code, manifests, fixtures, scripts, README, and reference docs; it does not rewrite history.

## Implementation plan

### 1. Cut the manifest and fixture declarations over

- In `botster-package.json` and `test/fixtures/workspaces/contract.json`, replace `session_template_managed_git_spawn` with `session_type_managed_git_spawn`.
- Rename `test/fixtures/session-template-package/` and `test/fixtures/shared-stack-owner-template/` to session-type vocabulary, including their package identities where used only as acceptance fixtures.
- In both fixture manifests, replace `session_templates` with `session_types`, preserve `id`, `target_id`, `command`, and `context`, and add explicit `role: "botster.agent"`, `interaction: "interactive"`, `traits`, and `lifecycle: "task"` values. Do not let Workspaces infer semantics from labels or commands.
- In `script/shared_stack_acceptance`, replace `.botster/session-templates.json` and its root key with `.botster/session-types.json` / `session_types`, and give the repository-owned definition the same explicit semantics.

### 2. Cut the Lua production path over without aliases

- In `plugin.lua`, rename the target-filtered projection helper/state from templates to session types and call only `botster.capabilities.session_types.list({ target_id = ... })`.
- Accept only list rows with nonblank `session_type_id`; use the existing presentation label but do not fall back to `template_id`, bare `id`, `result.templates`, or other legacy shapes.
- Change `botster_workspaces.spawn` and its registered input schema to require `session_type_id`. Reject `template_id` as `unknown_field` before any Hub capability call or workspace write.
- Change the action adapter, form input name, stable field-error mapping, node ids, locals, projection errors, and internal variables to session-type vocabulary. Keep the public tool/action name `botster_workspaces.spawn` and the semantic `botster_workspaces.open_spawn` action id unchanged; this ticket changes the request contract, not action ownership.
- Call only `botster.capabilities.session_types.ensure_worktree_and_spawn` with `{ target_id, branch, session_type_id, context }`. Preserve the trusted-field exclusions and the post-success `result.session_id` persistence path exactly.

### 3. Make the repository tests enforce the cold cut

- Update `test/plugin_runtime_test.lua` so its fake boundary exposes only `session_types`, returns rows with fully qualified `session_type_id`, and asserts the exact managed spawn request.
- Add a negative assertion that `template_id` is rejected and does not call the capability or mutate membership. Keep rejection, thrown-worker, duplicate UUID, and post-spawn persistence-failure coverage on the new request shape.
- Update `test/fixtures/workspaces/contract.json` and `script/test` to assert the new Hub API, field names, scope, fixture directories, and docs. Add a scoped forbidden-token audit across active files for `session_templates`, `session_template_`, `template_id`, and `.botster/session-templates.json`; exclude historical plans/reports deliberately.
- Update `script/hub_acceptance_smoke` to locate and submit the authored `session_type_id` field, require protocol 6 / conformance revision 31 and `session_type_entity_subscriptions`, and assert the canonical spawned `/session` entity carries the selected fully qualified `session_type_id` as well as the returned UUID.
- Update `script/test-hub-flow` and `script/shared_stack_acceptance` fixture paths, package ids, constants, values, messages, and repository definition paths. Keep their existing parent-owned Hub, managed-Git collision, persistence/restart, lifecycle, and teardown oracles.
- In the isolated real-Hub flow, add a negative admission/request check proving an old `session_templates` manifest or old `template_id` request is rejected rather than silently translated.

### 4. Update current documentation

- Update `README.md`, `docs/workspace-domain.md`, and `docs/capabilities.md` to name `session_types`, `session_type_id`, `session_type_managed_git_spawn`, and `session_types.ensure_worktree_and_spawn` consistently.
- Document that Workspaces displays Hub-provided session-type presentation but does not own role/interaction/trait/lifecycle taxonomy or source editability.
- Document protocol-6 real-Hub verification and the registry-published `@trybotster/hub-test-support@0.1.24` provenance check without adding the npm package as a runtime dependency.

## Affected surfaces and files

- Package contract: `botster-package.json`.
- Production plugin/runtime path: `plugin.lua`.
- Package reference docs: `README.md`, `docs/workspace-domain.md`, `docs/capabilities.md`.
- Local contract and Lua tests: `test/fixtures/workspaces/contract.json`, `test/plugin_runtime_test.lua`, `script/test`.
- Package-owned session-type fixtures: the renamed `test/fixtures/session-template-package/` and `test/fixtures/shared-stack-owner-template/` trees.
- Real-Hub paths: `script/test-hub-flow`, `script/hub_acceptance_smoke`, and `script/shared_stack_acceptance`.
- Review artifact: this plan.

## Ownership boundaries

Workspaces continues to own only semantic grouping records, workspace UI/actions, plugin.db persistence, and the decision to request a spawn before recording the returned UUID. Hub owns session-type definitions and precedence, package/repo/device sources, semantic descriptor truth, spawn-target admission, managed Git, session UUID generation, host metadata, entity projection, PTY/process lifecycle, and rollback.

The package reads the Hub contract and invokes one granted capability; it does not duplicate session-type rows in plugin.db or publish a competing session-type entity family. Web and TUI remain generic consumers of the owner-authored UiNode tree and Hub entities. Any failure in protocol 6, package admission, the real Lua capability table, or session metadata projection is routed back to the Hub dependency rather than worked around locally.

## Assumptions and unknowns

- The closed dependency's merged commit and published npm coordinate are authoritative. Registry lookup confirmed `0.1.24` is the current latest version with the announced integrity.
- The managed Lua response continues to return the canonical UUID at `result.session_id`; `session_type_id` is the request/list/entity vocabulary, while `session_id` remains the unrelated session identity vocabulary.
- Effective list rows use fully qualified `session_type_id` values; Workspaces should pass that identity back unchanged rather than reconstructing it from source/id fields.
- Historical plans and implementation reports are immutable evidence, not live compatibility paths, so their old terminology is not rewritten.
- No repository CI configuration exists; `script/test` is the repository-owned local gate and the documented Hub/shared-stack scripts are the integration gates.
- A clean Hub binary and session-worker binary from merged Hub commit `8a60bd5` must be available or built for the real-runtime check. Their absence blocks verification but does not justify a sibling-source fallback or cross-repository edit.

No human decision is currently required. If the current Hub's exact package schema contradicts the merged source or published artifact during implementation, stop and register that as a Hub dependency issue rather than choosing a compatibility path.

## Risks

- A partial rename could leave the fake Lua test green while the production worker table fails. The real installed-package Hub path is mandatory.
- Retaining `template_id` as a fallback would make the migration look successful while preserving a second contract. Negative tests and an active-file token audit must fail that state.
- Fully qualified session-type ids can expose bugs hidden by bare ids. Tests and the real smoke must select the id returned by `session_types.list` and pass it through unchanged.
- Renaming authored input/node ids can break a client or driver that improperly hard-codes product fields. The generic Web/TUI shared-stack path is the downstream guard; no renderer-specific workaround belongs here.
- The npm package proves public contract bytes but does not prove a running Hub. Verification must record npm integrity and live Hub/session-worker provenance separately.
- Real-Hub scripts currently use pre-protocol-6 handshake fields. Updating only the spawn call without making the handshake exact could produce misleading failures before Workspaces loads.
- Broad repository greps will find historical template-era plans. The guard must enumerate active files so it detects live aliases without rewriting durable history.

## Acceptance checks

1. Baseline/local gate: run `script/test`; it must pass Lua behavior, manifest/contract synchronization, active vocabulary guards, action-registration ablations, Ruby syntax checks, and shared-stack input validation. Baseline before implementation was green on `7587c7f` (`test/plugin_runtime_test.lua: ok`, `script/test: ok`).
2. Cold-cut negative proof: show that a `template_id` Workspaces spawn request returns `unknown_field`, makes zero session-type capability calls, and records no membership; show that an old `session_templates` fixture is rejected by the protocol-6 Hub rather than admitted as an alias.
3. Published contract proof: in a new temporary npm consumer, install exactly `@trybotster/hub-test-support@0.1.24` from the normal registry, retain the lock/integrity evidence, import `metadata`, run `verifyPackageAssets()`, and assert protocol 6, conformance revision 31, required `session_type_entity_subscriptions`, and generated `session_type_id`/session-type DTOs. Do not use a tarball or local/sibling override.
4. Real package path: with `BOTSTER_HUB_BIN` and `BOTSTER_SESSION_WORKER_BIN` proven from Hub merge `8a60bd5`, run `script/test-hub-flow`. It must start one fresh Hub, admit the Git target, install/enable the renamed session-type fixture and this package, render the target-first surface, list effective session types through the real worker capability table, submit the returned fully qualified `session_type_id`, create/reuse the managed worktree as expected, spawn, and append exactly the returned `result.session_id` only after success.
5. Runtime truth: the same smoke must assert protocol/revision/features at hello, observe the spawned `/session` entity carrying the selected `session_type_id`, preserve the UUID through plugin reload, record nothing on typed spawn rejection, retain ended history, and leave Hub sessions/worktrees/repositories untouched by workspace deletion.
6. UI downstream proof: when current Web and TUI consumer inputs are available, run the repository-owned `script/test-hub-flow shared-stack validate-inputs ...` and `shared-stack run ...` profile with immutable provenance. Both generic consumers must drive the renamed form field from the authored tree against the same protocol-6 Hub, without hard-coded template vocabulary or renderer-specific package state.
7. Final audit: `git diff --check`, a clean `git status --short` after committed changes, and a scoped `rg` over active source/manifests/tests/scripts/current docs showing no `session_templates`, `session_template_`, `template_id`, or `session-templates.json` tokens. Historical plan/report matches are documented, not treated as live aliases.

## Required evidence and artifacts

- Implementation report under the repository's existing `docs/reports/` convention, naming changed files, Hub/npm provenance, exact commands/results, negative proofs, and any deviation from this plan.
- Project Pipelines gate evidence with target/repository routing, this plan URI, dependency ticket, checklist id, assumptions, and verification results.
- PR linked before Review, per the pipeline merge policy.

## Vault gaps worth capturing

The vault's current notes [[workspace session templates are hub owned capabilities callable from lua workers]] and [[session template override sources use package device repo explicit precedence]] now describe the superseded vocabulary as current. After implementation proves the downstream path, capture a new atomic note for authoritative Hub session types and supersede/reweave those notes. The durable claim should preserve the ownership boundary while recording protocol-6 names, semantic descriptors, source/editability authority, fully qualified `session_type_id`, and the real-worker capability proof. Do not capture implementation guesses before the live verification lands.
