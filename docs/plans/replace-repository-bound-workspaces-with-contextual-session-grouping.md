# Replace repository-bound workspaces with contextual session grouping

## Target and context loaded

- Target repository: `trybotster/botster-workspaces` (`botster-workspaces`).
- Target ID: `tgt_71266a8d976d4535902ffed09c18a7ba`.
- Pipeline ticket: `ticket_1785192719_380772`.
- Pipeline run/step: `run_1785293839_742021`, `botster_stack_plan`.
- Routing proof: `project_pipelines_current_context` supplied the target ID;
  `list_spawn_targets` mapped it to `botster-workspaces`; this assigned
  worktree's `origin` is `https://github.com/trybotster/botster-workspaces.git`.
- Repository charter: [[botster-workspaces-playbook]]. The initial pipeline
  routing map omitted this repository; human answer
  `question_1785293925_901398` designated the newly validated exact charter.
  Follow-up ticket `ticket_1785294426_656956` is updating the standalone
  Project Pipelines routing source and is not an implementation dependency.
- Role and architecture context: [[identity]], [[goals]],
  [[planner-playbook]], [[botster-planner-playbook]],
  [[botster-architecture]], [[cli-patterns]], and [[spa-patterns]].
- Required Workspaces context:
  [[workspaces are semantic groupings by purpose not by branch]],
  [[botster workspace records are plugin owned references not hub authority]],
  [[botster plugin entities are canonical for plugin-owned dynamic state]],
  [[botster package manifests and lockfiles should declare capabilities and provenance]],
  and [[botster hub gravity must be watched before it becomes the new monolith]].
- Targeted plugin/runtime/UI context:
  [[botster plugin modal state belongs in client-local presentation state]],
  [[ui presentation operations are authored by accepted action results]],
  [[presentation policy uses auto resolution not separate dialog sheet and fullscreen primitives]],
  [[plugin surface actions route by explicit metadata]],
  [[plugin surface route completion needs explicit render phase]],
  [[plugin owned surface route renders run in plugin worker vms]],
  [[plugin surface handlers must validate against hub locked uinode contract]],
  [[plugin dynamic ui lists bind to plugin-owned entities]],
  [[plugin-owned dynamic state uses plugin-namespaced entity frames]],
  [[plugin authored tui surfaces dispatch via action props not node id literals]],
  [[botster web form actions must preserve collected values into transport payloads]],
  [[conformance helpers must dispatch the action id read from the rendered node]],
  [[runtime client acceptance must render delivered snapshots through real registry]],
  and [[botster web plugin app routes are stable host routes]].
- Targeted persistence/capability/test context:
  [[plugin db schema upgrades fail on required columns and unique constraints]],
  [[plugin capability tests must validate against real lua runtime table not injected stubs]],
  [[workspace session templates are hub owned capabilities callable from lua workers]],
  [[session template override sources use package device repo explicit precedence]],
  and [[botster plugins need headless real-runtime test harnesses]].
- Planning discipline:
  [[project pipeline orchestration belongs in a device-level botster plugin]],
  [[project pipelines needs an operator workbench not more primitives]],
  [[project pipelines ui contract belongs in the plugin readme]],
  [[botster orchestration should spawn agents with explicit target ids]],
  [[botster orchestration prompts must bind agents to explicit worktrees]],
  [[botster pipeline needs continuous product owner between agent steps]],
  [[plan agents must author vault context as wikilinks not home paths]], and
  [[vault example paths are not repository placement conventions]].
- [[project-pipelines-playbook]] was not loaded because this ticket changes no
  Project Pipelines package/plugin path or workflow policy. Project Pipelines
  is only the delivery mechanism.
- Repository context inspected: `README.md`, `botster-package.json`,
  `plugin.lua`, `docs/workspace-domain.md`, `docs/capabilities.md`,
  prior `docs/plans/*.md`, `test/fixtures/workspaces/contract.json`,
  `test/plugin_runtime_test.lua`, `script/test`,
  `script/hub_acceptance_smoke`, `script/validate_ui_node_contract`, recent
  history, and the target worktree status.
- Dependency context inspected:
  - Hub merge `5ce8151` / implementation `b7ebe9d` exposes the exact real
    worker capability
    `botster.capabilities.session_templates.ensure_worktree_and_spawn`.
  - Web merge `8e5f1fa` consumes the canonical Hub UI contract, scoped
    presentation state, canonical form values, accepted replacement trees,
    and generic dialog/action behavior.
  - TUI merge `0d26ce0` routes generic plugin actions through the Hub contract
    and applies scoped presentation/replacement behavior.
- Closed run dependencies:
  `ticket_1785192690_547868` (Hub atomic managed-worktree spawn),
  `ticket_1785192696_321546` (Web generic dialog/form consumer), and
  `ticket_1785192707_900922` (TUI generic action consumer).
- Scope reduction authorized at Plan Review by human answer
  `question_1785296105_892239`. Current Hub exposes no plugin-worker session
  read capability and no documented bindable session family for plugin-authored
  surfaces, so canonical current-versus-ended lifecycle grouping was extracted
  from this ticket rather than guessed. Hub ticket `ticket_1785295607_887142`
  on target `tgt_7e208a0c76a44980a83b63af976b1f22` owns that seam (run
  `run_1785296206_981403`), and Workspaces follow-on
  `ticket_1785296184_677408` consumes it. Neither blocks this run; this ticket
  now carries no open blocking dependency.
- Downstream integration ticket `ticket_1785192726_335558` owns final
  Workspaces-specific browser and TUI click-through after all producers and
  consumers land. This repository run proves its package/runtime behavior and
  the currently executable consumer seams without pretending generic fixture
  harnesses exercise Workspaces-specific actions.
- Planning baseline: `lua test/plugin_runtime_test.lua` passes. `script/test`
  initially stopped before Lua execution because the worktree arrived with
  tracked `.gitignore` emptied. Human answer
  `question_1785295621_465172` authorized restoring only that tracked file as
  baseline hygiene while leaving `.env` and `mise.local.toml` untouched and
  untracked. `git diff -- .gitignore` is now clean and `script/test` passes.

## Product decision ledger

- The ticket is a cold-turkey replacement. The accepted workspace record is
  exactly `{ id, name, session_refs, created_at, updated_at }`; repository,
  target, branch/worktree, template/default, purpose, status/archive, settings,
  and session-role/status metadata are not compatibility inputs.
- A workspace is a semantic grouping. `session_refs` contains canonical Hub
  session UUID references only; lifecycle truth is never copied into the
  workspace record. Authoritative current-versus-ended projection is deferred to
  `ticket_1785296184_677408`; this run preserves referenced session identities
  and makes no lifecycle claim.
- With no persisted archive/deleted state, "unique active names" means names
  are unique across records that currently exist. Deletion physically removes
  only the grouping record; it does not mutate any referenced Hub resource.
- The package owns create, rename, delete, add, move, remove, and post-spawn
  membership persistence. It does not own session termination or Git cleanup.
- One session UUID may belong to at most one workspace. Add/move operations
  update the complete plugin-owned state in one `plugin.db` write.
- Spawn calls only
  `session_templates.ensure_worktree_and_spawn` with semantic target, branch,
  template, and safe context. Only an `ok=true` result may append the returned
  canonical `result.session_id`; any rejection, runtime error, or persistence
  failure must not leave membership in an ambiguous second workspace.
- The package has one stable `workspaces` app surface. Index, selected detail,
  and contextual dialogs are different presentations of that surface, not
  additional routes or durable UI state.
- The client owns the scoped presentation store, but every open/select/close
  transition is authored by a normal accepted plugin action result. Web/TUI
  must not receive workspace-specific behavior.
- Forms are contextual. The initial index and empty state contain action
  affordances only; create, rename, delete confirmation, add/move/remove, and
  spawn forms/dialogs do not exist in the rendered tree until their opening
  action has been accepted.
- Spawn is target-first. If the shared form contract cannot filter a dependent
  template select locally, use the existing action-result/replacement contract
  as a two-phase dialog: select the user-facing spawn point, then render the
  branch/worktree and Hub-filtered effective session-type fields for that
  target. Do not invent a dependent-select primitive or expose unfiltered
  templates.

## Scope

1. Replace the persisted domain and public operations:
   - reduce each workspace to the exact five-field schema;
   - remove tolerant/defaulting reads and legacy normalization;
   - reject unknown/obsolete fields at every create/rename/imported-state
     boundary;
   - enforce trimmed non-empty names and uniqueness among existing records;
   - make delete remove the grouping record;
   - implement add, move, and remove session-reference mutations with one
     membership owner across the full state.
2. Replace the manifest/package policy:
   - retain MCP, `plugin_db`, and surfaces capabilities;
   - declare the exact Hub session-action scope
     `session_template_managed_git_spawn`;
   - retain only read capabilities actually needed for admitted spawn-target,
     effective-template, and session projections;
   - remove workspace filesystem authority, archive-policy configuration,
     the settings surface, and settings navigation;
   - keep the existing stable app surface/navigation identity `workspaces`.
3. Replace the runtime workflow:
   - project enabled Git-capable spawn points from
     `botster.capabilities.spawn_targets.list`;
   - project effective templates only through
     `session_templates.list({ target_id = ... })`;
   - invoke `session_templates.ensure_worktree_and_spawn` directly in the
     plugin worker;
   - persist exactly the returned `result.session_id` in exactly one workspace
     after success and persist nothing after failure;
   - publish/re-render the resulting workspace entity read model through the
     normal plugin-owned entity path.
4. Replace the owner-authored app surface:
   - index: contextual New workspace action, workspace rows/cards, and empty
     state, with no inline form;
   - selected detail: name plus preserved referenced session identities, Spawn
     session, rename/delete, add/move existing session, and remove membership
     actions; no current-versus-ended lifecycle grouping in this run;
   - contextual dialogs/forms driven by accepted presentation operations and
     owner-authored replacement roots;
   - spawn inputs in order: user-facing Spawn point, branch/worktree, then the
     selected target's effective Hub session type.
5. Replace docs, fixture contracts, fast Lua tests, Hub-locked UiNode
   validation, and the real packaged Hub acceptance flow so they describe and
   prove only the new product.

## Non-scope

- No compatibility reader, schema migration, dual action envelope, versioned
  workspace type, legacy fixture, soft-delete/archive path, or setting that
  preserves the old repository-bound product.
- No raw Git, filesystem, shell, worktree, branch, template-resolution,
  process, PTY, terminal, or session-lifecycle implementation in this repo.
- No direct `spawn_session_template`, daemon-request handoff, or separate
  ensure-then-spawn sequence; the single atomic Hub capability is required.
- No Hub, Web, TUI, TUI-kit, Core, or Project Pipelines source changes.
  Missing generic capability or renderer behavior must be registered against
  the owning repository rather than copied here.
- No second workspace detail route, workspace-specific React/Rust state,
  imperative session-list refresh, renderer-specific props, private action
  IDs in shared clients, iframe/custom HTML, or new UI primitive.
- No session termination on workspace delete or membership removal, and no
  branch/worktree/repository cleanup.
- No plugin-owned session lifecycle truth, polling, provisional current/ended
  grouping, or local substitute for the missing Hub seam. That seam is owned by
  `ticket_1785295607_887142` and consumed by `ticket_1785296184_677408`.
- No adjacent package refactor, generalized repository abstraction, new state
  library, or speculative configuration.

## Repository ownership and cross-repository seams

- `botster-workspaces` owns the five-field records, plugin.db storage,
  uniqueness and single-membership invariants, grouping history, entity read
  models, and all workspace workflow surfaces/actions.
- `botster-hub` owns admitted spawn points, stored base refs, effective
  template filtering, Git/worktree locks and rollback, canonical session UUIDs,
  lifecycle truth, the atomic ensure-and-spawn capability, and the generic
  session-lifecycle projection tracked by `ticket_1785295607_887142`.
- `botster-ui-contract`/Hub protocol owns UiNode, action request/result,
  presentation, replacement, form-value, and entity-frame contracts.
- `botster-web` and `botster-tui` own generic presentation storage, rendering,
  form drafts/errors, focus/input, and application of accepted replacements.
  They consume this package without workspace-specific branches.
- The three original capability/consumer dependencies are closed and this run
  has no open blocking dependency. Hub ticket `ticket_1785295607_887142` and
  Workspaces follow-on `ticket_1785296184_677408` own lifecycle projection and
  run after this ticket. The routing-map maintenance ticket is workflow
  hygiene only. Final Workspaces-specific Web/TUI click-through stays in
  `ticket_1785192726_335558`, not in this repository run.

## Assumptions and unknowns

- Assumption: existing record names remain case-sensitive after trimming,
  matching the current package's equality behavior. If product requires
  case-folded uniqueness, ask the human before changing semantics.
- Assumption: `session_refs` is an ordered, duplicate-free array of canonical
  session UUID strings. Hub facts provide labels and lifecycle state at render
  time; the package does not add metadata to the record to improve display.
- Assumption: a referenced session that is unavailable or ended remains
  membership history and must not be silently pruned, regardless of which
  ticket later resolves its lifecycle state.
- Assumption: moving a session atomically removes it from its prior workspace
  and inserts it once in the destination. Adding an already-owned session
  without explicit move intent is rejected with the current owner identified.
- Assumption: deleting a workspace releases its name and membership ownership
  immediately while preserving the Hub sessions themselves.
- Assumption: a successful Hub spawn followed by a `plugin.db` persistence
  failure cannot unspawn the Hub session. The action must return a typed
  persistence error and never claim membership; acceptance should make this
  exceptional boundary observable rather than attempting forbidden lifecycle
  rollback.
- Resolved by scope reduction: current Hub has neither a `sessions`/`entities`
  Lua capability nor a documented bindable session entity family for plugin
  surfaces. Rather than guess that seam, lifecycle projection moved to
  `ticket_1785295607_887142` (Hub producer) and `ticket_1785296184_677408`
  (Workspaces consumer). This run must not invent a local substitute, restore
  persisted status fields, poll, or perform an imperative client refresh; it
  stores and renders session references only.
- Unknown for implementation inspection: whether the canonical current UiNode
  contract supports a single target-dependent form. Prefer the two-phase
  accepted-replacement flow above when it does not.
- Ask-human threshold: stop if the exact five-field record cannot support a
  required behavior without adding metadata, or if "active name" requires a
  hidden archive/status concept. Do not silently weaken the schema.
- Convention conflict: the older atomic note
  [[botster workspace records are plugin owned references not hub authority]]
  lists repository/target/template/settings metadata as plugin-owned. The
  ticket and the newer repository charter explicitly supersede that field list
  while preserving its authority boundary. No engineering-convention waiver is
  required.

## Affected surfaces and files

- `plugin.lua`
  - delete old config/archive, repo/target/default-template normalization,
    tolerant reads, soft-delete/status, settings surface, and old
    `spawn_default_session` daemon-request behavior;
  - implement exact record validation, CRUD/rename, single membership
    add/move/remove, entity projection, Hub target/template projections, direct
    atomic spawn, and one contextual app surface with action handlers.
- `botster-package.json`
  - replace capability grants, remove archive configuration and settings
    surface/navigation, retain the stable app descriptor/navigation.
- `test/plugin_runtime_test.lua`
  - replace the injected old-domain tests and surface assertions; keep fast
    boundary fakes but do not use them as proof that the real Hub capability
    exists.
- `test/fixtures/workspaces/contract.json`
  - cold-replace all legacy records/operations with the exact reduced schema,
    membership/move/remove, contextual UI, and atomic-spawn outcomes.
- `script/test`
  - replace obsolete manifest/docs/fixture/source assertions and retain leak,
    direct-filesystem, and repo-local runtime gates.
- `script/hub_acceptance_smoke`
  - replace `spawn_session_template` request relay with package install/enable,
    real worker capability invocation, returned UUID persistence/failure
    atomicity, entity/surface rendering, and non-destructive delete proof.
- `script/validate_ui_node_contract`
  - replace the obsolete `BOTSTER_CORE_PATH`/`botster_core::UiNode` validator
    with `BOTSTER_UI_CONTRACT_PATH` pointing at the exact Hub
    `crates/botster-ui-contract` artifact consumed by the acceptance Hub;
  - generate and validate exactly one app-surface payload, replacing the
    hard-coded two-payload assertion and its app/settings error text;
  - deserialize/validate `botster_ui_contract::UiNode`; do not retain a Core
    fallback or dual validator.
- `README.md`
  - document the five-field product, one stable route, contextual interactions,
    exact Hub capability boundary, real packaged proof, and remove the old
    settings/default/archive/repository material.
- `docs/workspace-domain.md`
  - cold-replace the old domain contract with grouping, membership/history,
    atomic spawn, and rename/delete semantics; record that authoritative
    current/ended lifecycle projection is owned by `ticket_1785296184_677408`.
- `docs/capabilities.md`
  - document only the retained package capabilities and Hub authority.
- `docs/plans/replace-repository-bound-workspaces-with-contextual-session-grouping.md`
  - this reviewable plan artifact.

Botster layers touched are the first-party Lua plugin worker, plugin.db record
model, package manifest, plugin-owned entities, owner-authored shared UiNode
surface/actions, repository tests/docs, and real Hub package acceptance.

## Implementation sequence

1. Confirm the worktree still targets `botster-workspaces`, keep the restored
   `.gitignore` baseline, preserve user-owned untracked files, and record exact
   Hub/UI-contract/Web/TUI revisions used for proof. No dependency gate remains
   on this ticket; implementation starts immediately.
2. Rewrite the fixture/docs schema first as the executable contract. Delete
   every obsolete field and operation name rather than aliasing it.
3. Replace persistence validation and workspace model operations in
   `plugin.lua`; make absent state the only clean-start default and reject
   legacy/unknown record shapes with a typed operator-legible
   `legacy_workspace_schema` (or equivalent stable code) error. Document that
   pre-production installs with old records must use a new clean Hub data
   directory or explicitly discard the old disposable data directory after
   backup; no automatic reset or destructive cleanup occurs.
4. Implement single membership add/move/remove and exact entity projections.
   Persist each multi-workspace mutation as one state write. Render referenced
   UUIDs as preserved membership without asserting lifecycle state; the
   current/ended split belongs to `ticket_1785296184_677408`.
5. Replace manifest grants and wire target-filtered template projection plus
   `ensure_worktree_and_spawn`; append only the returned UUID after success.
6. Replace the app tree/actions with contextual presentation and replacement
   flows. Drive selection and all dialogs through rendered action metadata.
7. Replace fast tests and the real Hub smoke. Prove the registered package
   production entrypoint, not only local Lua functions.
8. Remove all obsolete docs/source/fixture strings, run repository gates, then
   run the exact Web package render/route smoke and the generic TUI contract
   smoke with the scoped claims below. Leave full package-specific browser/TUI
   interaction to `ticket_1785192726_335558`.

## Risks

- Legacy tolerance may survive in a helper, fixture, docs paragraph, MCP schema,
  or UI label even after the main record changes. Use exact-key negative tests
  plus repository-wide obsolete-token scans.
- Mutating two workspace arrays in separate writes can duplicate or lose
  membership. Compute and validate the full next state, then persist once.
- Recording before Hub success or trusting a requested session ID would violate
  atomicity. Read only `result.session_id` from `ok=true`.
- A Hub spawn can succeed while plugin persistence fails. Make that boundary
  explicit and test it; do not terminate the session or fabricate membership.
- Synthetic `botster.capabilities` stubs can falsely prove an API name. Require
  package enablement and real worker invocation against merged Hub.
- Rendering Hub lifecycle status into persisted workspace rows would recreate
  duplicate authority. Keep session status derived/client-bound.
- Inline or always-present forms would violate the contextual interaction
  contract even if hidden with CSS. Assert the delivered tree before and after
  accepted open actions.
- Presentation state can leak across clients/surfaces if persisted or globally
  keyed. Use the canonical client-local, Hub/package/surface-scoped store only.
- A static unfiltered template select can offer an ineligible session type.
  Use target-filtered Hub projection and a replacement-driven second phase.
- Source-level UiNode assertions can pass while Web/TUI actions are inert.
  Require exact Hub UI-contract validation, real Hub surface render, the
  package-specific Web render/route smoke, and separately identified generic
  action-contract evidence.
- Legacy plugin.db state will now fail closed. The error must be typed and
  operator-legible, and every acceptance Hub must use a fresh isolated data
  directory so old pre-production state is not confused with a regression.
- The old Core-backed validation script can green-light a tree Hub rejects.
  Repoint it to the exact Hub UI-contract crate and forbid a fallback.
- Generic Web/TUI conformance harnesses do not prove Workspaces-specific
  click-through. Scope claims to their actual behavior and leave final
  end-to-end product proof to `ticket_1785192726_335558`.

## Acceptance checks and downstream proof

Repository and static gates:

```sh
script/test
BOTSTER_UI_CONTRACT_PATH=/path/to/current-botster-hub/crates/botster-ui-contract \
  script/validate_ui_node_contract
git diff --check
rg -n 'purpose|local_repo_ref|spawn_target_ref|default_session_template|archive_policy|workspaces-settings|spawn_default_session|relative_worktree_hint' \
  README.md botster-package.json plugin.lua docs/workspace-domain.md \
  docs/capabilities.md script test
```

`script/test` must pass from the resolved clean baseline; it is not waived.
The UI validator must consume the same Hub UI-contract revision as the real
acceptance Hub and validate one app surface. The obsolete-token scan must
return only intentional negative assertions that
prove rejection/removal; no legacy production field, compatibility reader,
fixture, surface, action, or documentation remains.

Required fast/runtime assertions:

- Exact records contain only `id`, `name`, `session_refs`, `created_at`, and
  `updated_at`; unknown/obsolete fields and legacy persisted records are
  rejected rather than normalized.
- Names are trimmed, non-empty, unique across current records, released by
  delete, and safely renamed without changing IDs or session membership.
- A UUID cannot appear twice or in two workspaces. Add rejects an existing
  owner; explicit move updates source and destination atomically; remove affects
  grouping only; restart preserves the invariant.
- Ended/unavailable referenced sessions remain in `session_refs` until an
  explicit remove/move. Workspace delete removes only the record and never
  calls a Hub termination or Git/filesystem mutation capability.
- The manifest has no workspace filesystem, archive setting, or settings
  surface and grants the exact managed-Git session action capability.
- The registered app route remains `workspaces`. Its initial populated and
  empty trees have contextual action controls and no Form node.
- A rendered New workspace control dispatches the action ID read from its
  UiNode. Accepted `set` opens the Dialog; rejected submit retains values and
  errors; accepted submit clears presentation and installs the owner-authored
  replacement.
- Workspace row/card selection sets the surface-scoped selected workspace,
  reveals the detail tree on the same stable route, and stays stable across
  re-render. Detail preserves every referenced session identity without
  asserting current/ended state. Spawn, rename, delete, add/move existing
  session, and remove membership are each implemented and asserted in this run
  without client-specific policy.
- Spawn selection is target-first; only enabled Git-capable spawn points are
  shown, and the effective session-type options come from
  `session_templates.list` for the chosen target. The form never accepts caller
  session ID, cwd, repo/worktree path, base ref, or Git command.
- A successful real capability call persists exactly
  `result.session_id` once in the selected workspace and removes it from no
  other workspace except through explicit move semantics. A typed Hub failure
  and a thrown worker error persist nothing.

Real packaged Hub gate (fresh isolated data directory only):

```sh
script/hub_acceptance_smoke <isolated-current-hub.sock> [workspace-name]
```

The smoke must install and enable this checkout through a current merged Hub
started from a newly created empty data directory,
list the actual registered tools/surface/actions, create and select a workspace,
project target-filtered choices, call the real plugin-worker
`session_templates.ensure_worktree_and_spawn`, observe a canonical UUID-backed
Hub session, verify that exact UUID in one persisted workspace after restart,
exercise a negative Hub spawn with unchanged membership, render the initial and
post-action surface trees through `plugin_surface_render`, and prove deletion
leaves the session and managed Git resources intact. A mocked Lua table or a
returned-but-unsubmitted daemon request is not acceptable evidence.

Cold-start/operator assertions:

- Absence of the workspace state key creates an empty valid state.
- A seeded old repository-bound record returns the documented typed
  legacy-schema error; it is not normalized, silently dropped, or surfaced as
  an unhandled worker traceback.
- README/local-development guidance says existing pre-production users must
  stop the old Hub and either start with a new empty `--data-dir` or back up and
  explicitly discard the old disposable Hub data directory before reinstall.
  The package performs no automatic deletion.

Downstream generic-consumer proof required by the repository charter:

- Web package proof uses the exact existing command from `botster-web`:

  ```sh
  BOTSTER_HUB_BIN=<hub> \
  BOTSTER_SESSION_WORKER_BIN=<worker> \
  BOTSTER_WORKSPACES_PACKAGE_PATH=<this-checkout> \
    npm run smoke:live-packaged-protocol
  ```

  For this package, that harness proves install/enable, discovery of the real
  Workspaces app surface, `plugin_surface_render`, stable-route navigation, and
  direct-load/reload. Its contract-matrix mode separately proves generic
  dialog/form/presentation/replacement mechanics; it does not prove those
  interactions against `botster-workspaces`.
- TUI's current `script/test-live-hub` proves generic real-frame/input/action
  semantics only against Hub's plugin-contract-matrix fixture. It has no
  Workspaces package input, so this plan makes no Workspaces-specific claim
  from that command and requires no TUI source change.
- Final real-renderer Workspaces click-through—New workspace, selected detail,
  target-first Spawn, canonical form values, rejected/accepted dialogs,
  current-to-ended entity convergence, and keyboard TUI interaction—is owned
  by already-open integration ticket `ticket_1785192726_335558`, which now
  depends on `ticket_1785296184_677408`.
- Record exact Hub, UI-contract, Web, TUI, and test-support provenance used.
  Do not substitute generic fixture evidence for package-specific behavior.

## Pipeline and vault checklist evidence

- Run vault checklist: `checklist_1785294571_837409`.
- Its creation call timed out, but durable listing showed the write landed, so
  it was adopted rather than duplicated.
- The checklist must record the notes above, the resolved stale-note conflict,
  planning verification, the human `.gitignore` disposition, the registered
  Hub dependency, accurately scoped downstream commands, implementation
  evidence, and the capture disposition below.

## Vault gaps worth capturing

- [[botster workspace records are plugin owned references not hub authority]]
  is stale in its field examples: it still names repository/target/template
  defaults and settings. After implementation proves the replacement, capture
  and process a superseding atomic note for the exact five-field reference
  model, then update the old note's status/link.
- [[workspace session templates are hub owned capabilities callable from lua workers]]
  describes the older default-template selection path. It should be updated
  after proof to name the target-filtered
  `ensure_worktree_and_spawn` composition and returned-UUID persistence rule.
- If implementation establishes a reusable rule for post-spawn
  plugin-persistence failure, capture it through the vault inbox pipeline after
  the behavior and operator-facing error are proven.
- No vault note should be written from planning speculation alone.
