# Migrate Workspaces to authoritative session types

## Ticket and routing

- Ticket: `ticket_1785984128_479155`, “Workspaces: migrate package to authoritative session types”.
- Target: `tgt_71266a8d976d4535902ffed09c18a7ba`, resolved through the admitted spawn-target registry to `trybotster/botster-workspaces` (`botster-workspaces`). The worktree remote is `https://github.com/trybotster/botster-workspaces.git`; routing was resolved from the ticket target, not from the ambient directory.
- Run: `run_1786035894_642389`, worktree branch `project-pipelines/ticket_1785984128_479155`, base `main` at `7587c7f`, branch head `6651083`.
- Repository charter: [[botster-workspaces-playbook]].
- Role and stack context: [[planner-playbook]], [[botster-planner-playbook]], [[botster repository playbooks are ownership charters composed with role overlays]], [[botster-architecture]], [[cli-patterns]], [[spa-patterns]], [[vault example paths are not repository placement conventions]].
- Targeted guidance: [[workspaces are semantic groupings by purpose not by branch]], [[botster workspace records are plugin owned references not hub authority]], [[botster plugin entities are canonical for plugin-owned dynamic state]], [[botster package manifests and lockfiles should declare capabilities and provenance]], [[botster hub gravity must be watched before it becomes the new monolith]], [[acceptance harness region oracles must key on node identity not concatenated text]], [[plugin ui action ids are a two site change and hub fails closed on unregistered ids]], [[plugin capability tests must validate against real lua runtime table not injected stubs]], [[workspace session templates are hub owned capabilities callable from lua workers]], [[session template override sources use package device repo explicit precedence]], [[cold turkey migrations eliminate dual code paths and version suffixes]], [[a regression test must be shown to go red with the fix reverted]].
- Project Pipelines package/plugin code and workflow policy are not changing, so [[project-pipelines-playbook]] is intentionally not a task-surface overlay. Project Pipelines is used only to record this plan, gate, artifact, question, and checklist evidence.

This revision supersedes the plan approved on the cancelled run `run_1785987292_480836`. That plan's technical migration content is retained; its ordering decision is replaced by the answer to `question_1786036155_624060`.

## Verified contract facts

Read from source at `trybotster/botster-hub` `8a60bd58841179f8b1fd4040d9362d18ea244230`, confirmed an ancestor of `botster-hub` `origin/main`:

- `crates/botster-hub-client/src/lib.rs:24-25` — `PROTOCOL_VERSION = 6`, `CONFORMANCE_FIXTURE_REVISION = 31`.
- `src/profile.rs:186-197` — the only `SessionActions` grants are unscoped, `session_type_spawn`, and `session_type_managed_git_spawn`. There is no `session_template_*` grant, and `PackageRegistry::enable` hard-denies an ungranted scope.
- `src/lua_runtime.rs:691-692, 833-912` — the registered Lua table is `botster.capabilities.session_types` with `list`, `show`, `spawn`, and `ensure_worktree_and_spawn`; the request key is `session_type_id`.
- `src/session_types.rs:23-48` — `PackageSessionType` requires `id`, `label`, `role`, `interaction`, `lifecycle`, and `command`. `traits`, `args`, `context`, and `target_id` default. Manifests therefore cannot omit `role`/`interaction`/`lifecycle`.
- `src/session_types.rs:112-135` — the effective row is `HubSessionType` with a fully qualified `session_type_id` alongside a bare `id` and a `source`.
- `src/session_types.rs:205` — the repo-owned definition file is `.botster/session-types.json`, root key `session_types` (`src/session_types.rs:338`).
- `src/packages.rs:184, 1177` — the package manifest key is `session_types`.
- `src/daemon_transport.rs:394-412` and `crates/botster-hub-client/src/lib.rs:453-462` — the Hub reads `DaemonHello`, validates only `protocol`, and replies with `DaemonHelloAck { protocol, compatibility: DaemonCompatibility::current(), diagnostics }`. The Hub never validates a client-declared requirement; compatibility is the client's job.

Local baseline: `./script/test` is green at `6651083` (`test/plugin_runtime_test.lua: ok`, `script/test: ok`).

### One new hard blocker, verified this pass

`script/hub_acceptance_smoke` sends a `compatibility` block using the pre-protocol-6 field names `minimum_protocol_version` / `minimum_conformance_fixture_revision` at lines 100-109 and 165-182. `DaemonHello.compatibility` is `#[serde(default)]` but its inner `DaemonCompatibilityRequirement` (`crates/botster-hub-client/src/lib.rs:500-507`) has no per-field defaults, so a *present* block missing `protocol_version` fails deserialization and the handshake dies before Workspaces loads. This is not a stylistic cleanup — the real-Hub smoke cannot connect to a protocol-6 Hub until it is fixed. `script/shared_stack_acceptance` is unaffected; its hello at line 85 sends only `protocol`.

## Dependency state and ordering decision

The Hub prerequisite `ticket_1785970233_236046` is closed against Hub target `tgt_7e208a0c76a44980a83b63af976b1f22`, merged as PR #193 at `8a60bd58`. The matching public artifact is `@trybotster/hub-test-support@0.1.24`, integrity `sha512-n0/DDMw5PmnFdxp54dk4Y4pdAM0VfotQblBnamqkViwbmJgmSS7ZrAFPskzOcVZ70hHgJdfHaH4UwArwP0DvXw==`. It is the sole registered dependency of this ticket.

The prior run blocked implementation on Web `ticket_1785970233_750553` and TUI `ticket_1785970234_132113`. That ordering was circular: `ticket_1785976581_841608` states botster-tui's Workspaces lanes cannot pass until *this* ticket lands, while this ticket was told to wait for botster-tui. `question_1786036155_624060` resolved it — implement now, break the cycle in the direction botster-tui already assumes, and keep the downstream proofs mandatory for ticket closure rather than waived.

**The PR merges on real-Hub proof. The ticket does not close until the registered downstream proofs land.** These are distinct gates and must not be collapsed.

## Scope

Cold-replace the active Workspaces package contract with Hub session-type vocabulary:

1. Change the Workspaces manifest capability scope to `session_type_managed_git_spawn`.
2. Change package and repository acceptance declarations from `session_templates` to `session_types`, including `.botster/session-types.json`, and supply the descriptor fields protocol 6 requires (`role`, `interaction`, `traits`, `lifecycle`) while preserving launch/context fields.
3. Change the production Lua boundary from `botster.capabilities.session_templates` to `botster.capabilities.session_types`.
4. Consume list rows only through `session_type_id`; remove the `template_id` / bare-`id` list-row fallbacks and the `result.templates` result-wrapper fallback rather than retaining aliases.
5. Rename the Workspaces spawn request, MCP input schema, form field name, locals, errors, and active fixture/test vocabulary from template terms to `session_type_id` / session types. Keep `session_id` only where it denotes the canonical spawned session UUID, and keep authored node identities stable.
6. Preserve the existing target-first, Hub-owned managed-Git operation and failure atomicity: call only `session_types.ensure_worktree_and_spawn`, append exactly `result.session_id` after success, and record nothing on rejection or worker failure.
7. Repair the `script/hub_acceptance_smoke` handshake to the protocol-6 `DaemonCompatibilityRequirement` shape and assert the Hub-emitted compatibility, so the real-Hub proof actually reaches Workspaces and actually proves the protocol it claims.
8. Update active package documentation, contract fixtures, repository test guards, and both real-Hub acceptance harnesses to describe and exercise the new contract.

## Non-scope

- No Hub, Core, Web, TUI, TUI-kit, or Project Pipelines source changes. Specifically, this run does **not** edit botster-tui's `script/test-live-hub`, its `app.rs` acceptance driver, or botster-web's browser driver, even though this ticket's rename is what breaks them. See “Cross-repository consequences”.
- No session-type CRUD, source precedence, descriptor taxonomy, spawn admission, Git/worktree policy, or lifecycle authority in Workspaces; all remain Hub-owned.
- No changes to the five-field workspace record, membership semantics, plugin.db schema, workspace entity family, `/session` lifecycle bindings, surface action ids, or grouping-only deletion.
- No compatibility aliases, dual manifest keys, dual Lua capability tables, acceptance of `template_id`, or fallback decoding of old list rows.
- No rename of the authored `botster-workspaces-spawn-template` node id. It is stable presentation identity, not a request/result field; the form field it carries changes to `session_type_id`. Both first-party drivers key on the field *name*, not this id, so renaming the id would break them a second way for no gain.
- No rename or deletion of `plugin.lua`'s `OBSOLETE_FIELDS` keys `default_session_template`, `default_session_template_id`, and `default_session_template_refs`. They are frozen pre-production create-argument keys that must continue to produce `obsolete_field`, not active Hub vocabulary. Persisted records carrying any extra field remain a separate `legacy_workspace_schema` path through `validate_state`.
- No npm/build toolchain added to this Lua package. The published npm artifact is consumed in a clean temporary verification consumer, not made a production dependency.
- Existing `docs/plans/` and `docs/reports/` files describing completed historical tickets remain historical artifacts. The cold-cut token audit covers current code, manifests, fixtures, scripts, README, and reference docs; it does not rewrite history.

## Implementation plan

### 1. Cut the manifest and fixture declarations over

- In `botster-package.json` and `test/fixtures/workspaces/contract.json`, replace `session_template_managed_git_spawn` with `session_type_managed_git_spawn`.
- Rename `test/fixtures/session-template-package/` and `test/fixtures/shared-stack-owner-template/` to session-type vocabulary, including their package identities where those are used only as acceptance fixtures.
- In both fixture manifests, replace `session_templates` with `session_types`, preserve `id`, `target_id`, `command`, and `context`, and add the now-required `label`, `role: "botster.agent"`, `interaction: "interactive"`, `traits`, and `lifecycle: "task"`. Do not let Workspaces infer semantics from labels or commands.
- In `script/shared_stack_acceptance`, replace `.botster/session-templates.json` and its root key with `.botster/session-types.json` / `session_types`, and give the repository-owned definition the same explicit semantics.

### 2. Cut the Lua production path over without aliases

- In `plugin.lua`, rename the target-filtered projection helper/state (`templates_for_target`, `templates_by_target`) from templates to session types and call only `botster.capabilities.session_types.list({ target_id = ... })`.
- Accept only list rows with a nonblank `session_type_id`; keep the existing presentation label but drop the `template_id` / bare-`id` / `result.templates` fallbacks at `plugin.lua:589-596`.
- Change `botster_workspaces.spawn` and its registered MCP input schema (`plugin.lua:1771-1775`) to require `session_type_id`. Reject `template_id` as `unknown_field` before any Hub capability call or workspace write.
- Change the action adapter (`plugin.lua:878-892`), the `select_input` form field name (`plugin.lua:1232-1237`), the stable field-error mapping, locals, projection error codes, and internal variables to session-type vocabulary. Keep the public tool/action name `botster_workspaces.spawn`, the semantic `botster_workspaces.open_spawn` action id, and the authored `botster-workspaces-spawn-template` node id unchanged; this ticket changes the request contract, not presentation identity or action ownership.
- Call only `botster.capabilities.session_types.ensure_worktree_and_spawn` with `{ target_id, branch, session_type_id, context }`. Preserve the trusted-field exclusions and the post-success `result.session_id` persistence path exactly.

### 3. Make the repository tests enforce the cold cut

- Update `test/plugin_runtime_test.lua` so its fake boundary exposes only `session_types`, returns rows with fully qualified `session_type_id`, and asserts the exact managed spawn request.
- Add a negative assertion that `template_id` is rejected and does not call the capability or mutate membership. Keep rejection, thrown-worker, duplicate UUID, and post-spawn persistence-failure coverage on the new request shape.
- Update `test/fixtures/workspaces/contract.json` and `script/test` to assert the new Hub API, field names, scope, fixture directories, and docs. `script/test` sites that must move: the `session_templates` required token (`script/test:75`), the `session_templates.ensure_worktree_and_spawn` operation assertion (`:129`), and the README token list (`:164`).
- Add a scoped forbidden-token audit across active files for `session_templates`, `session_template_`, `template_id`, and `.botster/session-templates.json`. Enumerate the audited files explicitly (the existing `scanned_files` list at `script/test:224-239` is the right shape, extended to the renamed fixture trees); exclude historical plans/reports; allowlist only the three exact `OBSOLETE_FIELDS` record keys, which contain `session_template` as a substring. Assert those three keys remain present.
- Add a Lua regression calling `create_workspace` separately with `default_session_template`, `default_session_template_id`, and `default_session_template_refs`, each requiring the typed code `obsolete_field` — explicitly not `unknown_field`. `plugin.lua:272` is the sole `OBSOLETE_FIELDS` consumer, so this test fails if any key is removed. Leave the existing persisted-state `legacy_workspace_schema` coverage at `test/plugin_runtime_test.lua:937` unchanged; `validate_state` (`plugin.lua:125-160`) enforces `WORKSPACE_KEYS` independently and never reads `OBSOLETE_FIELDS`.
- Per [[a regression test must be shown to go red with the fix reverted]], each new negative assertion must be demonstrated red against the pre-change behavior, not merely observed green after.

### 4. Repair and tighten the real-Hub harnesses

- Fix both `script/hub_acceptance_smoke` hello sites to the current `DaemonCompatibilityRequirement` shape (`protocol`, `protocol_version`, `required_features`, `minimum_conformance_fixture_revision`, `client_name`). This is required for the script to connect at all.
- Assert the Hub-emitted `DaemonHelloAck.compatibility`: `protocol_version == 6`, `conformance_fixture_revision == 31`, and `features` including `session_type_entity_subscriptions`. The Hub ignores the client block, so the hello assertions are the only real protocol proof available here.
- Update the smoke to locate and submit the authored `session_type_id` field and to assert the canonical spawned `/session` entity carries the selected fully qualified `session_type_id` as well as the returned UUID.
- Update `script/test-hub-flow` and `script/shared_stack_acceptance` fixture paths, package ids, constants, values, messages, and repository definition paths. Keep their existing parent-owned Hub, managed-Git collision, persistence/restart, lifecycle, and teardown oracles.
- In the isolated real-Hub flow, add a negative admission/request check proving an old `session_templates` manifest or an old `template_id` request is rejected rather than silently translated.

### 5. Update current documentation

- Update `README.md`, `docs/workspace-domain.md`, and `docs/capabilities.md` to name `session_types`, `session_type_id`, `session_type_managed_git_spawn`, and `session_types.ensure_worktree_and_spawn` consistently.
- Document that Workspaces displays Hub-provided session-type presentation but does not own role/interaction/trait/lifecycle taxonomy or source editability.
- Document protocol-6 real-Hub verification and the registry-published `@trybotster/hub-test-support@0.1.24` provenance check without adding the npm package as a runtime dependency.
- Record the three unproven downstream gaps and their owner tickets in the implementation report, so a skipped proof reads as a known gap and never as a pass.

## Affected surfaces and files

Botster layers touched: package manifest, Lua plugin runtime, plugin-owned UiNode surface (form field only), and real-Hub acceptance harnesses. No Rust hub, TUI, SPA, or MCP-server layer changes.

- Package contract: `botster-package.json`.
- Production plugin/runtime path: `plugin.lua`.
- Package reference docs: `README.md`, `docs/workspace-domain.md`, `docs/capabilities.md`.
- Local contract and Lua tests: `test/fixtures/workspaces/contract.json`, `test/plugin_runtime_test.lua`, `script/test`.
- Package-owned session-type fixtures: the renamed `test/fixtures/session-template-package/` and `test/fixtures/shared-stack-owner-template/` trees.
- Real-Hub paths: `script/test-hub-flow`, `script/hub_acceptance_smoke`, `script/shared_stack_acceptance`.
- Plan and implementation report artifacts under the repository's existing `docs/plans/` and `docs/reports/` convention.

## Ownership boundaries

Workspaces continues to own only semantic grouping records, workspace UI/actions, plugin.db persistence, and the decision to request a spawn before recording the returned UUID. Hub owns session-type definitions and precedence, package/repo/device sources, semantic descriptor truth, spawn-target admission, managed Git, session UUID generation, host metadata, entity projection, PTY/process lifecycle, and rollback.

The package reads the Hub contract and invokes one granted capability. It does not duplicate session-type rows in plugin.db or publish a competing session-type entity family. Web and TUI remain generic consumers of the owner-authored UiNode tree and Hub entities. Any failure in protocol 6, package admission, the real Lua capability table, or session metadata projection is routed back to the Hub dependency rather than worked around locally.

### Cross-repository consequences — certain, not speculative

Renaming the spawn request field `template_id` → `session_type_id` is required by this ticket, and keeping the old form input name while the tool argument is `session_type_id` would be precisely the compatibility alias the ticket forbids. Both first-party drivers key on the field **name**, so both break deterministically. Verified from source:

- `botster-tui` `crates/botster-tui/src/app.rs:3893` — `select_only_acceptance_value(app, router, "template_id", ...)`.
- `botster-web` `scripts/workspaces-shared-hub-browser-helpers.mjs:69` and `scripts/workspaces-shared-hub-browser-smoke.mjs:135`.

Under the charter, botster-workspaces does not own either repository, so this run does not repair them. The owner work is registered and verified:

| Gap | Owner repository | Ticket |
| --- | --- | --- |
| TUI acceptance-driver field rename, plus un-skip and proof of all three `script/test-live-hub` Workspaces lanes | `trybotster/botster-tui` | `ticket_1786036326_597046` (blocked on this ticket **and** `ticket_1785976581_841608`) |
| Web shared-hub browser-driver field rename and smoke proof | `trybotster/botster-web` | `ticket_1786036336_442121` (blocked on this ticket) |

The three TUI lanes need two independent conditions, and only one of them is this ticket's: Workspaces must declare the granted scope, **and** botster-tui must repin to protocol 6, because `ensure_compatible` now demands exact protocol equality and botster-tui `origin/main` (`fe03a90`) is still pinned to Hub rev `e8febabf` = protocol 4 / revision 27. A lane that still fails after this ticket lands is not automatically a Workspaces defect.

The ticket's premise that the lanes are already “marked blocked-pending-THIS-TICKET” is not yet true on botster-tui `origin/main` — `script/test-live-hub` currently carries no skip markers, and `ticket_1785976581_841608` holds only a plan commit. The lane obligation is therefore forward-looking, and the closure gate below is written against the tickets rather than against markers that do not exist yet.

## Assumptions and unknowns

- The closed dependency's merged commit and published npm coordinate are authoritative. `8a60bd58` is confirmed an ancestor of `botster-hub` `origin/main`.
- The managed Lua response continues to return the canonical UUID at `result.session_id`. `session_type_id` is the request/list/entity vocabulary; `session_id` remains the unrelated session-identity vocabulary.
- Effective list rows carry a fully qualified `session_type_id`. Workspaces passes that identity back unchanged rather than reconstructing it from `source` and `id`.
- Historical plans and implementation reports are immutable evidence, not live compatibility paths, so their old terminology is not rewritten.
- No repository CI configuration exists. `script/test` is the repository-owned local gate; the documented Hub and shared-stack scripts are the integration gates.
- The Hub and session-worker binaries used for the real-runtime check must be built from a **clean** checkout at `8a60bd5` with provenance recorded. A prebuilt binary in a developer checkout is not acceptable evidence unless that checkout is verified clean at that commit. Their absence blocks verification but never justifies a sibling-source fallback or a cross-repository edit.
- All three `script/test-live-hub` Workspaces profiles require `BOTSTER_WORKSPACES_PACKAGE_PATH` and drive the real package, so all three are in the lane obligation. `ticket_1785976581_841608` originally scoped its skip to `installed-driver` only; that ticket has since been corrected.
- Open unknown: whether repairing the `hub_acceptance_smoke` handshake surfaces further protocol-6 drift in that script beyond the compatibility block. If it does, that is in-scope repair of this repository's own harness, not a Hub dependency issue.

If the running Hub's exact package schema contradicts the merged source or published artifact during implementation, stop and register that as a Hub dependency issue rather than choosing a compatibility path.

## Risks

- A partial rename could leave the fake Lua test green while the production worker table fails. [[plugin capability tests must validate against real lua runtime table not injected stubs]] makes the real installed-package Hub path mandatory, not optional.
- Retaining `template_id` as a fallback would make the migration look successful while preserving a second contract. Negative tests and the active-file token audit must fail that state.
- The token audit is the guard on the `OBSOLETE_FIELDS` freeze and is also the thing most likely to over-match it. An audit written as a bare substring scan would flag the three frozen keys and invite deleting them, silently weakening a charter gate. The allowlist must be exact keys, not a `session_template` prefix exemption.
- Fully qualified session-type ids can expose bugs hidden by bare ids. Tests and the real smoke must select the id returned by `session_types.list` and pass it through unchanged.
- The handshake repair is on the critical path: until it lands, the real-Hub smoke cannot connect to a protocol-6 Hub, and a failure there could easily be misread as a Workspaces migration defect.
- The npm package proves public contract bytes but does not prove a running Hub. Record npm integrity and live Hub/session-worker provenance separately.
- Broad repository greps will match historical template-era plans. The guard must enumerate active files so it detects live aliases without rewriting durable history.
- Landing this PR knowingly red-lines two other repositories' drivers. That is intended and registered, but the implementation report must say so plainly rather than reporting an unqualified green.

## Acceptance checks

**Gates 1-5 must pass before the PR merges.**

1. **Local gate.** `./script/test` passes Lua behavior, manifest/contract synchronization, active vocabulary guards, action-registration ablations, Ruby syntax checks, and shared-stack input validation. Baseline before implementation was green at `6651083`.
2. **Cold-cut negative proof.** A `template_id` Workspaces spawn request returns `unknown_field`, makes zero session-type capability calls, and records no membership. An old `session_templates` fixture is rejected by the protocol-6 Hub rather than admitted as an alias. Separately, each frozen create argument (`default_session_template`, `default_session_template_id`, `default_session_template_refs`) returns `obsolete_field`, explicitly not `unknown_field`, while the existing persisted-state `legacy_workspace_schema` regression stays green. Each negative assertion is demonstrated red against pre-change behavior.
3. **Published contract proof.** In a new temporary npm consumer, install exactly `@trybotster/hub-test-support@0.1.24` from the normal registry, retain lock/integrity evidence, import `metadata`, run `verifyPackageAssets()`, and assert protocol 6, conformance revision 31, required `session_type_entity_subscriptions`, and generated `session_type_id` / session-type DTOs. No tarball, no local or sibling override.
4. **Real package path.** With `BOTSTER_HUB_BIN` and `BOTSTER_SESSION_WORKER_BIN` built from a clean checkout at Hub `8a60bd5`, `script/test-hub-flow` starts one fresh Hub, admits the Git target, installs and enables the renamed session-type fixture and this package, renders the target-first surface, lists effective session types through the real worker capability table, submits the returned fully qualified `session_type_id`, creates or reuses the managed worktree as expected, spawns, and appends exactly the returned `result.session_id` only after success. Package enable succeeding is itself proof that the scope migration is correct, since Hub `8a60bd58` hard-denies the legacy scope.
5. **Runtime truth.** The same smoke asserts Hub-emitted protocol 6 / revision 31 / `session_type_entity_subscriptions` at hello, observes the spawned `/session` entity carrying the selected `session_type_id`, preserves the UUID through plugin reload, records nothing on typed spawn rejection, retains ended history, and leaves Hub sessions, worktrees, and repositories untouched by workspace deletion.
6. **Final audit.** `git diff --check`, a clean `git status --short` after committed changes, and a scoped `rg` over active source, manifests, tests, scripts, and current docs showing no `session_templates`, `session_template_`, `template_id`, or `session-templates.json` tokens outside the exact frozen `OBSOLETE_FIELDS` allowlist. Historical plan/report matches and the three legacy rejection keys are documented, not treated as live aliases.

**Gates 7-8 block closure of this ticket. They do not block the PR, and they must not be weakened to make them pass.**

7. **Generic-consumer proof (this repository).** `script/test-hub-flow shared-stack validate-inputs ...` and `shared-stack run ...` with immutable protocol-6 provenance, driving the renamed form field from the authored tree through generic Web and TUI consumers without hard-coded template vocabulary or renderer-specific package state. Currently unrunnable: `verify_contract_provenance!` requires both clients pinned to the supplied Hub, and botster-web `origin/main` (`9753297`) pins `@trybotster/hub-test-support` 0.1.21 while botster-tui `origin/main` (`fe03a90`) pins Hub rev `e8febabf`. Unblocked by `ticket_1786036336_442121` and `ticket_1786036326_597046`.
8. **TUI live-hub lanes.** All three `script/test-live-hub workspaces` profiles — `installed-driver`, `plumbing`, and `lifecycle` — green against a protocol-6 Hub with the migrated package. Owned by `ticket_1786036326_597046`, which is blocked on both this ticket and `ticket_1785976581_841608`.

Do not close this ticket on the strength of the PR merging. Do not re-apply a skip to make a lane appear green.

## Required evidence and artifacts

- Implementation report under `docs/reports/`, naming changed files, Hub/npm provenance, exact commands and results, negative proofs, the three named downstream gaps with their owner ticket ids, and any deviation from this plan.
- Project Pipelines gate evidence with target/repository routing, this plan URI, dependency state, checklist id, assumptions, and verification results.
- PR linked before Review, per the pipeline merge policy.

## Vault gaps worth capturing

- [[workspace session templates are hub owned capabilities callable from lua workers]] and [[session template override sources use package device repo explicit precedence]] both describe the superseded vocabulary as current. After implementation proves the real-Hub path, capture a superseding atomic note for authoritative Hub session types and reweave both. The durable claim should preserve the ownership boundary while recording protocol-6 names, the required `role`/`interaction`/`lifecycle` descriptor fields, source/editability authority, the fully qualified `session_type_id`, and the real-worker capability proof.
- The same note also still says workspace plugins "can normalize legacy `default_session_template_id` into `default_session_template_refs`". The repository already cold-cut those to rejected `OBSOLETE_FIELDS` under the five-field record, so that sentence is stale independently of this ticket. Recorded as a convention conflict; the resolution is to supersede the note, not to soften the repository's reduced schema.
- Candidate new gotcha: a Botster daemon client's `DaemonHello.compatibility` is `#[serde(default)]` at the field level but strict inside, so a *stale-but-present* compatibility block fails the handshake while omitting it entirely succeeds. That asymmetry cost real diagnosis time here and is not recorded anywhere in the vault.
- Candidate new convention: when a package rename breaks first-party consumers that key on a request field name, the owner-work split belongs in separate tickets rather than folded into mid-flight ones, because folding recreates circular dependencies. This run's `question_1786036155_624060` exchange is the worked example.

Do not capture implementation guesses before the live verification lands.
