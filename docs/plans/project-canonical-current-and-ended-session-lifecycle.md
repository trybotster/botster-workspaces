# Project-canonical current and ended session lifecycle

## Delivery identity

- Ticket: `ticket_1785296184_677408` — Workspaces: project canonical current and ended session lifecycle
- Target repository: `botster-workspaces` (`trybotster/botster-workspaces`)
- Target ID: `tgt_71266a8d976d4535902ffed09c18a7ba`
- Repository charter: [[botster-workspaces-playbook]]
- Pipeline: `run_1785544550_983502`, Plan step `run_step_1785544550_817460`

The target was resolved from Project Pipelines context through Botster's spawn-target registry, not from the ambient directory. The ticket's routing prompt omitted `botster-workspaces`; human answer `question_1785544618_703384` explicitly authorizes [[botster-workspaces-playbook]] for this and every later role in this run. The missing routing entry is a separate Project Pipelines prompt/configuration defect, not scope for this repository.

## Context loaded

Loaded in required order:

1. [[planner-playbook]]
2. [[botster-planner-playbook]]
3. [[botster-workspaces-playbook]]
4. Targeted architecture and task guidance listed below

Role/surface guidance:

- [[botster-architecture]]
- [[cli-patterns]]
- [[spa-patterns]]
- [[project pipeline orchestration belongs in a device-level botster plugin]]
- [[project pipelines needs an operator workbench not more primitives]]
- [[project pipelines ui contract belongs in the plugin readme]]
- [[botster orchestration should spawn agents with explicit target ids]]
- [[botster orchestration prompts must bind agents to explicit worktrees]]
- [[botster pipeline needs continuous product owner between agent steps]]
- [[plan agents must author vault context as wikilinks not home paths]]
- [[pipeline vault checklists must cite exact resolvable note titles]]
- [[vault example paths are not repository placement conventions]]

Repository-charter notes:

- [[workspaces are semantic groupings by purpose not by branch]]
- [[botster workspace records are plugin owned references not hub authority]]
- [[botster plugin entities are canonical for plugin-owned dynamic state]]
- [[botster package manifests and lockfiles should declare capabilities and provenance]]
- [[botster hub gravity must be watched before it becomes the new monolith]]

Ticket-specific notes:

- [[plugin dynamic ui lists bind to plugin-owned entities]]
- [[botster hub client state sync is entity frame only]]
- [[botster wire v2 clients must consume ui tree snapshots and render composites with entity stores]]
- [[clients subscribe to entities not ptys]]
- [[lifecycle guards evaluated before the reconciling drain are one call stale]]
- [[botster browser pull requests must retry after webrtc reconnect]]
- [[plugin-owned dynamic state uses plugin-namespaced entity frames]]
- [[botster entity snapshots are authoritative reconnect baselines]]
- [[botster client subscriptions should not hydrate global state]]
- [[plugin surfaces request model state through ui bindings not hub subscribe]]
- [[botster plugin entity hydration has full id and scoped contracts]]
- [[plugin query providers match snapshot read model shape]]

[[project-pipelines-playbook]] was not loaded: Project Pipelines is the delivery mechanism, while this change touches no Project Pipelines package/plugin path or workflow policy.

Repository evidence inspected:

- `plugin.lua`, package manifest, README, domain/capability documentation, fixtures, unit/runtime tests, UiNode validator, and real-Hub smoke scripts
- merged `botster-hub` `origin/main` at `822a75af9c9cc1815a2aaff18f3294d82810fd1f`, including the canonical `/session` producer and plugin binding contract
- Hub `fixtures/plugins/plugin-contract-matrix/plugin.lua:262-330`: `contract.sessions` emits one exact-UUID `/session` `bind_list` per requested reference, binds `@/lifecycle_class` for a present row, selects `empty_template` for an absent row, and bounds its conformance fixture at 16 references
- Hub `crates/botster-hub-test-support/fixtures/plugin-contract-matrix/README.md:75-81`: documents that reference projection as the canonical contract
- Hub `crates/botster-ui-contract/src/lib.rs:737-743,2273-2280,2426-2441`: `where` is an exact top-level-field map, `item_template` is required, `empty_template` is optional, and bound descendant IDs are rejected
- Hub `fixtures/plugins/plugin-contract-matrix/botster-package.json`: `contract.sessions` binds `/session` with only the ordinary `surfaces` capability
- merged Web and TUI generic binding plans and their current acceptance harnesses
- current ticket/run/gate/reviews/artifacts/findings/questions/answers/dependencies from Project Pipelines
- baseline `script/test` on `c78f3bf`: pass (`test/plugin_runtime_test.lua: ok`, `script/test: ok`)

## Product decision ledger

1. A workspace remains a plugin-owned semantic grouping whose canonical persisted references are session UUIDs. Its record stays exactly `{id, name, session_refs, created_at, updated_at}`.
2. Hub owns session existence, lifecycle, identity, processes, PTYs, and the canonical `/session` entity. Workspaces neither stores nor computes lifecycle state.
3. Workspaces owns the product presentation: referenced sessions are grouped as Current, Ended, and Unavailable/uncertain. Hub's canonical classes map directly: `current` to Current, `ended` to Ended, and `indeterminate` to Unavailable/uncertain. A reference absent from the authoritative entity family is also shown as unavailable, not silently discarded.
4. Ended, indeterminate, and absent references remain in `session_refs` until an explicit workspace move/remove. Deleting a workspace never deletes or stops a Hub session.
5. Lifecycle transitions are reconciled from entity snapshot/upsert/patch/remove frames against one structural surface tree. No polling, imperative list refresh, lifecycle-specific plugin entity, or surface re-render is a synchronization mechanism.
6. Per-reference bindings filter by canonical session UUID and lifecycle class. This compound exact-top-level-field filter is admitted by the merged UiNode contract, not an implementation assumption. Stored UUID order is preserved within each presentation group.
7. Identity and action payloads stay literal because each reference UUID is known when Lua authors the tree. The validator admits a bound ID only at a `bind_list` item-template root and rejects bound descendant IDs. This design therefore does not depend on open Hub contract ticket `ticket_1785443253_376782`, and that ticket is not a dependency.
8. The canonical Hub fixture proves that `/session` binding needs only the ordinary `surfaces` capability. `botster-package.json` remains unchanged; do not add a lifecycle/read capability defensively.
9. Each reference produces at most four bindings: Current, Ended, indeterminate, and absence detection. The UiNode contract has no binding-count admission limit and current Workspaces membership is uncapped, so this ticket does not invent a product cap. Instead it must prove the exact `4N` ceiling and validate/render a representative 16-reference workspace, matching the canonical Hub conformance fixture's exercised bound.
10. Human answer `question_1785545020_154092` chose strict downstream proof. This ticket may implement its owner surface while the prerequisites run, but cannot close or claim the consumer gate until both merged harness modes exercise this real package through the normal Hub path.

## Scope

The smallest owner-repository change is to replace the deferred/static session-reference presentation with a structural UiNode projection over the canonical Hub session entity, then prove current-to-ended, uncertain/absent, removal, and reconnect behavior without changing workspace persistence.

In scope:

- owner-authored Current, Ended, and Unavailable/uncertain sections on workspace detail
- exact UUID and lifecycle-class `ui.bind_list` filters against `/session`
- stable realized row identity and existing remove-session actions
- explicit empty/absent-reference presentation through contract-valid templates
- unchanged workspace CRUD, move, remove, spawn, and plugin-owned entity semantics
- repository tests, locked-contract validation, real Hub/plugin-worker lifecycle proof, and real generic Web/TUI proof
- documentation of lifecycle presentation and authority boundaries

## Non-scope

- Hub lifecycle classification, retention, process, PTY, registry, or entity protocol changes
- Web or TUI renderer/product implementation in this repository
- a new Workspaces lifecycle cache, persisted status fields, timestamps, polling loop, or imperative `list_sessions` synchronization
- changing workspace meaning to repository, branch, checkout, or terminal ownership
- destructive session cleanup when a workspace or reference is removed
- broad UiNode abstraction, optional configuration, compatibility schema, version-suffixed parallel path, unrelated cleanup, or Project Pipelines prompt repair
- the broader final browser/TUI/Hub workspace-and-spawn workflow owned by `ticket_1785192726_335558`

## Ownership boundaries and dependencies

`botster-workspaces` owns workspace records, names, membership/order, move/remove semantics, current-versus-ended product grouping, plugin persistence, Lua surface composition, package documentation, and owner tests.

It does not own Hub session truth or generic renderer state. Cross-repository seams are dependencies, not edits in this run:

- Closed Hub producer dependency `ticket_1785295607_887142`: canonical session entity supplies UUID-filterable rows, `lifecycle_class`, authoritative snapshots, ordered deltas, stale-to-indeterminate behavior, and explicit removal.
- Closed Web generic consumer dependency `ticket_1785298229_125024`: Web materializes admitted bindings from its generic entity store.
- Closed TUI generic consumer dependencies `ticket_1785298229_854008` and `ticket_1785438029_926883`: TUI materializes the same grammar with realized row identity.
- Open blocking Web proof `ticket_1785545085_392193` / `run_1785545100_548796`: add a reusable real-package Workspaces lifecycle acceptance mode; it may fix only genuinely generic renderer defects.
- Open blocking TUI proof `ticket_1785545086_939840` / `run_1785545102_681755`: add the equivalent real-package TUI mode under the same restriction.
- Known Hub gap `ticket_1785443253_376782`: descendant identity for multi-control bound rows remains open, but the literal per-reference design intentionally avoids it; no dependency is required.
- Broader downstream integration `ticket_1785192726_335558` remains separate and does not substitute for this charter gate.

Neither prerequisite may absorb Workspaces semantics, hard-code product state, bypass the Hub contract, hand-author transport payloads, or use sibling-worktree overrides. This ticket consumes only merged, repository-documented modes with explicit package/binary provenance.

## Affected surfaces and files

- `plugin.lua`: replace the static reference list with lifecycle-filtered, exact-UUID structural bindings and retained remove actions.
- `test/plugin_runtime_test.lua`: assert record invariance, canonical binding sources/filters, grouping, stable IDs/actions, absent templates, and no plugin-owned lifecycle state.
- `test/fixtures/workspaces/contract.json`: replace `lifecycle_grouping: deferred` with the delivered contract and expected authority boundary.
- `script/test`: keep the repository unit/runtime entry point covering the new contract.
- `script/hub_acceptance_smoke`: extend real-Hub evidence to held-open session entity snapshots/deltas, lifecycle change, reconnect baseline, removal, reference retention, and non-destructive workspace deletion.
- `script/test-hub-flow`: change only if isolated orchestration or explicit binary/package provenance is needed by the expanded smoke.
- `script/validate_ui_node_contract`: expected unchanged; update only if its generic validation path cannot inspect a valid canonical binding already admitted by Hub.
- `README.md`, `docs/workspace-domain.md`, `docs/capabilities.md`: replace deferred lifecycle language with delivered behavior, authority, and verification instructions.
- `docs/plans/project-canonical-current-and-ended-session-lifecycle.md`: this implementation plan.
- `botster-package.json`: inspected and expected unchanged; `/session` binding must not become a new Workspaces authority capability.

## Implementation sequence

1. Make this plan document durable in the first Implement commit; it is intentionally an untracked Plan-step artifact until then and must not be lost if the worktree is recreated.
2. Add focused runtime-test expectations first. Require three labeled groups, one exact-UUID binding per stored reference per relevant lifecycle projection, canonical `/session` source, stable literal unique IDs, and the existing literal UUID-specific remove action. Assert that persisted/read-model keys remain exactly the five canonical workspace keys and that lifecycle fields never enter plugin state.
3. Build small local Lua helpers only where repetition requires them: generate deterministic IDs from workspace/reference/group, generate exact filters, and compose the item/empty templates. Keep authority and grouping logic visible in `plugin.lua`; do not introduce a generic framework.
4. Render Current (`lifecycle_class=current`), Ended (`ended`), and Unavailable/uncertain (`indeterminate`) from the same stored UUID sequence. These lifecycle-group bindings omit `empty_template`, which the merged contract makes optional, so non-matches render nothing. Add a separate exact-UUID absence projection whose `empty_template` names the retained UUID, mirroring Hub's canonical `contract.sessions` shape.
5. Validate only the genuinely open part of the absence projection: because `item_template` is required, its present-row template must render no visible content while its `empty_template` renders the unavailable reference. Locked-contract validation and both real clients must prove the minimal present template creates no blank row, duplicate affordance, focus target, or identity artifact. If that one negative-projection shape fails, stop and route the precise Hub/UI-contract prerequisite; the exact UUID projection, multi-key lifecycle filters, optional lifecycle `empty_template`, and capability admission are already settled and must not be re-litigated.
6. Update fixture and documentation in the same cold replacement. Remove the deferred claim; add no dual schema or compatibility branch.
7. Extend the isolated real-Hub smoke with a distinct held-open session-entity subscription. Render the workspace detail once, then prove transitions from entity frames without another surface render or lifecycle list query.
8. Prove structural scale before downstream handoff: a 16-reference fixture must yield no more than 64 reference bindings, pass locked-contract validation, preserve literal unique IDs/action UUIDs, and materialize without blank/duplicate rows.
9. After the Web and TUI prerequisites merge, run their documented Workspaces modes against this exact package revision, including the representative 16-reference case. Record the merged commits/artifact pins and actual commands in implementation evidence; do not invent temporary sibling paths.

## Runtime proof design

The real-Hub smoke should use two real session references plus one never-known canonical UUID so each semantic is independently observable:

1. Start a fresh isolated Hub and plugin worker, install this package, and open a held session-entity subscription that declares the required entity family.
2. Create a workspace, spawn real sessions through the package action/tool path, and add the never-known UUID through the normal workspace mutation path.
3. Render workspace detail once. From the authoritative entity baseline/deltas, assert live sessions materialize in Current and the never-known reference materializes as unavailable while all UUIDs remain in plugin state.
4. Let one real session end through its normal process lifecycle. Consume the ordered lifecycle patch and assert that the same reference moves from Current to Ended without a new `plugin_surface_render`, imperative session-list refresh, or plugin-state write.
5. End and explicitly remove the second real Hub session entity. Assert entity removal yields unavailable presentation while the workspace retains its UUID.
6. Close and reconnect the subscription. Require a fresh authoritative baseline before subsequent deltas and assert the retained ended/unknown presentation remains correct without stale-generation rows.
7. Delete the workspace and prove the retained ended Hub session still exists. This preserves the grouping-only, non-destructive boundary.

The downstream Web mode must render and inspect the real owner-authored surface through production route/registry/entity-store code. The downstream TUI mode must navigate and inspect it through the production registry, binding resolver, and keyboard path. Both must cover current, ended, indeterminate or absent, patch, remove, and reconnect baseline behavior and must fail if they depend on a list refresh or surface refresh. Existing generic conformance alone is supporting evidence, not completion evidence.

In addition to the focused two-real-session lifecycle scenario, both modes must load a representative 16-reference workspace and prove the admitted tree renders with unique actionable rows, no blank/duplicate artifacts, and no more than four reference bindings per stored UUID. Sixteen is a verification floor borrowed from the canonical Hub fixture, not a new product membership cap.

## Acceptance checks and tests

Repository gates:

- `script/test`
- `BOTSTER_UI_CONTRACT_PATH=<current botster-hub crates/botster-ui-contract> script/validate_ui_node_contract`
- `BOTSTER_HUB_BIN=<current botster-hub binary> BOTSTER_SESSION_WORKER_BIN=<matching worker binary> script/test-hub-flow`
- `git diff --check`
- focused scans/assertions that persisted workspace records contain no lifecycle/status fields and runtime lifecycle synchronization contains no polling or `list_sessions` fallback
- a red/green regression check showing that removing a lifecycle filter, absent template, or held-subscription reconciliation assertion causes the relevant test to fail
- a 16-reference scale assertion proving at most 64 reference bindings, locked-contract acceptance, literal descendant IDs/action UUIDs, stable ordering, and no blank or duplicate materialization

The Hub-flow evidence must include exact Hub and worker source provenance, cold plugin database creation, package install/route registration, locked UiNode acceptance, obsolete schema rejection, atomic spawn behavior, current-to-ended delivery, indeterminate/absent retention, reconnect baseline, explicit entity removal, and non-destructive workspace deletion.

Downstream charter gates, blocked until merged prerequisites exist:

- Run the repository-documented Web Workspaces lifecycle acceptance mode from `ticket_1785545085_392193` with explicit current Hub/worker binaries and this package path/revision.
- Run the repository-documented TUI Workspaces lifecycle acceptance mode from `ticket_1785545086_939840` with the same provenance.
- Preserve their exact commands and merged commit/artifact pins in the implementation artifact. Both must prove the production runtime/user path, not source presence or hand-authored fixture transport.

No pre-existing failure is accepted without the exact failing command, output, and source-based evidence that it is unrelated.

## Assumptions and unknowns

- Assumption: the merged Hub contract remains canonical: `starting|running|stopping` project to `current`, `exited|failed` to `ended`, missing lifecycle or stale registry to `indeterminate`, and an omitted row means unknown/unavailable.
- Verified contract fact: `where` accepts compound exact top-level fields, so `{session_uuid, lifecycle_class}` is admitted; `empty_template` is optional, while `item_template` is required.
- Verified package precedent: canonical `contract.sessions` binds `/session` under only `surfaces`, so Workspaces needs no lifecycle/read capability or manifest change.
- Assumption: one exact UUID filter matches at most one canonical row, while stored UUIDs provide deterministic ordering and action identity.
- Verified identity constraint: bound IDs are allowed only on the item-template root, not descendants. Literal per-reference IDs and action UUIDs deliberately avoid open Hub ticket `ticket_1785443253_376782`.
- Unknown requiring implementation proof: only whether the required minimal `item_template` on the separate absence-detection binding is artifact-free when its UUID is present. The canonical exact-UUID/empty-template absence behavior itself is already proven. Failure triggers a precise dependency question, not a local workaround.
- Scale fact and proof obligation: the design emits at most four bindings per reference, Workspaces has no membership cap, and UiNode admission defines no count limit. Repository plus both consumer modes must exercise 16 references/at most 64 bindings; this does not impose a product cap.
- Unknown until prerequisites merge: their exact command names and artifact pins. The implementation artifact must take these from merged repository documentation.
- Verified manifest fact: Hub's canonical `/session` binding fixture declares only `surfaces`; `botster-package.json` remains unchanged.
- Rails conventions are not implicated by this Lua/package repository. General preferences apply: readable, minimal, framework/contract primitives first, no speculative abstraction, and cold replacement of the deferred path.

## Risks and mitigations

- Duplicate authority: lifecycle fields in plugin state could drift from Hub. Prevent with exact-key tests and canonical Hub bindings only.
- False runtime proof: re-rendering or querying sessions after every event could hide broken reconciliation. Render once and consume held subscription frames.
- Unknown-reference blank artifacts: exact absence selection is already canonical; validate the required minimal present-row template through locked contract plus both real clients and fail closed only on that narrow gap.
- Row/action identity collisions across mutually materialized groups: derive deterministic group/reference IDs and assert post-expansion uniqueness and UUID payloads.
- Binding growth: assert the `4N` ceiling and validate/render 16 references (at most 64 bindings) in repository, Web, and TUI modes without inventing an unrelated membership cap.
- Stale reconnect state: require authoritative baseline replacement before ordered deltas and test a lifecycle transition across reconnect.
- Timing races on natural exit: wait on bounded entity conditions and sequence numbers, not fixed sleeps or pre-drain lifecycle guards.
- Destructive boundary regression: independently retain one ended Hub session through workspace deletion and one removed entity reference in plugin state.
- Capability creep or Hub gravity: do not add plugin lifecycle authority, direct Core calls, or renderer-specific props.
- Cross-repository drift: completion remains blocked on the two merged consumer modes and explicit provenance; no sibling overrides.

## Vault checklist and gaps

The exact notes above constrain authority, bindings, reconnect behavior, target/worktree routing, and downstream proof. They introduce no convention conflict with the repository plan. Baseline verification passed; implementation and downstream commands remain mandatory evidence.

No durable knowledge is captured during Plan. Candidate gaps to capture only if implementation proves them reusable:

- The ticket routing prompt lacks the already-authoritative `botster-workspaces` mapping. The human identified this as a separate Project Pipelines configuration defect; do not duplicate it as repository work.
- If the required absence-detection `item_template` cannot suppress a present row without a visible artifact, capture that precise remaining negative-projection limitation; exact UUID matching and absent `empty_template` selection are already canonical.
- If both consumer prerequisites establish the same reusable product-package acceptance pattern, capture that pattern after merged evidence exists rather than generalizing it in advance.

Every implementation line must trace to the owner presentation, its required proof, a loaded convention, or cleanup made necessary by that change.
