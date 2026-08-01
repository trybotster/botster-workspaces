# Prove the complete Workspaces browser, TUI, and Hub spawn flow

## Target and context loaded

- Target repository: `trybotster/botster-workspaces` (`botster-workspaces`).
- Target ID: `tgt_71266a8d976d4535902ffed09c18a7ba`.
- Ticket/run: `ticket_1785192726_335558` / `run_1785602425_939731`.
- Routing proof: `project_pipelines_current_context` supplied the target ID and
  `list_spawn_targets` mapped it to the admitted `botster-workspaces` target.
  The supplied routing table omitted this repository; human answer
  `question_1785602485_811365` designated
  [[botster-workspaces-playbook]] as the exact ownership charter and classified
  the omission as Project Pipelines workflow metadata drift.
- Role and architecture context: [[identity]], [[goals]],
  [[planner-playbook]], [[botster-planner-playbook]],
  [[botster-architecture]], [[cli-patterns]], and [[spa-patterns]].
- Workspaces charter context:
  [[workspaces are semantic groupings by purpose not by branch]],
  [[botster workspace records are plugin owned references not hub authority]],
  [[botster plugin entities are canonical for plugin-owned dynamic state]],
  [[botster package manifests and lockfiles should declare capabilities and provenance]],
  [[botster hub gravity must be watched before it becomes the new monolith]],
  and [[acceptance harness region oracles must key on node identity not concatenated text]].
- Targeted runtime and acceptance context:
  [[workspace session templates are hub owned capabilities callable from lua workers]],
  [[device hub owns admitted spawn targets not ambient repo cwd]],
  [[runtime client acceptance must render delivered snapshots through real registry]],
  [[renderer acceptance tests must drive real frame backend]],
  [[conformance helpers must dispatch the action id read from the rendered node]],
  [[conformance harnesses gate on deterministic invariants not timing]],
  [[plugin surface actions route by explicit metadata]],
  [[closed dependency tickets signal merged source not a consumable release]],
  [[external client hub tests use subprocess spawned hub test support]],
  [[botster web generated protocol drift checks need explicit hub artifact paths]],
  [[hub generated protocol changes are a four site release chain]],
  [[botster core contract surface needs consumer proof]], and
  [[botster package surface semantics live in ui contract while hub owns admission]].
- Planning and workflow context:
  [[project pipeline orchestration belongs in a device-level botster plugin]],
  [[project pipelines needs an operator workbench not more primitives]],
  [[project pipelines ui contract belongs in the plugin readme]],
  [[botster orchestration should spawn agents with explicit target ids]],
  [[botster orchestration prompts must bind agents to explicit worktrees]],
  [[botster pipeline needs continuous product owner between agent steps]],
  [[plan steps need reviewable plan artifacts]],
  [[plan agents must author vault context as wikilinks not home paths]],
  [[pipeline vault checklists must cite exact resolvable note titles]], and
  [[vault example paths are not repository placement conventions]].
- [[project-pipelines-playbook]] was loaded because the missing repository
  routing entry, dependency registration, checklist evidence, and gate policy
  are workflow-policy surfaces implicated by this Plan run. This repository
  implementation does not edit the Project Pipelines package.
- Repository context inspected: `README.md`, `docs/workspace-domain.md`,
  `docs/capabilities.md`, active `docs/plans/` prior art,
  `botster-package.json`, `plugin.lua`, `script/test`,
  `script/test-hub-flow`, `script/hub_acceptance_smoke`,
  `script/validate_ui_node_contract`, `test/plugin_runtime_test.lua`, current
  main history, and the clean assigned worktree.
- Downstream context inspected on merged main:
  - Web `a618fcd` with `npm run smoke:workspaces-lifecycle`, the production
    renderer/transport harness, `@trybotster/ui-contract@0.2.0`, and the
    identity-based sixteen-reference lifecycle oracle. Its installed runnable
    entrypoint already receives `BOTSTER_HUB_CONNECTION`,
    `scripts/local-package-server.mjs` decodes that connection, the live harness
    honors `BOTSTER_LIVE_DATA_DIR`, and
    `scripts/live-caller-owned-repeatability.mjs` proves reuse with
    `install:false` and `enable:false`.
  - TUI `0668435` with `script/test-live-hub workspaces lifecycle`, production
    frame/hit-map keyboard routing, and its Hub-owned Git contract pin. Its
    installed runnable entrypoint already receives `BOTSTER_HUB_CONNECTION`
    and `BOTSTER_HUB_DATA_DIR`, both parsed by the production binary.
  - Hub `88d3438` with explicit spawn-target `base_ref`, managed-Git
    ensure/reuse/collision semantics, `botster-ui-contract`, generated client
    artifacts, and package supervision.
  - Core `5846fc7` with the UI contract deletion and terminal-only public
    boundary.
- Human answer `question_1785602772_466681` requires final acceptance to use
  one shared fresh Hub data directory with Web, TUI, and Workspaces installed
  and enabled once at immutable pins. Web and TUI may run sequentially, but
  both must observe shared durable state and use their production interaction
  paths. Separate clean-Hub runs are supporting diagnostics only.

## Product decision ledger

1. This is a verification/integration change. It may add orchestration,
   assertions, documentation, and durable evidence in `botster-workspaces`; it
   must not repair Hub, Web, TUI, Core, or UI-contract behavior locally.
2. Final proof uses Model A: the Workspaces parent harness starts and owns one
   long-lived Hub process and one fresh data directory for the entire scenario.
   The Hub uses an immutable merged binary with its matching locked Core session
   worker. Current immutable Web, TUI, and Workspaces package trees are
   installed and enabled once. Consumer drivers never start, stop, restart, or
   reinstall the Hub/packages.
3. The parent launches the installed Web and TUI runnable entrypoints through
   current Hub package/app commands, which supply the already-supported
   `BOTSTER_HUB_CONNECTION` injection and TUI `BOTSTER_HUB_DATA_DIR` injection.
   The clients run sequentially against the same live Hub state and may
   reconnect/reopen only at their client boundary. Each observes state created
   by the other/shared workflow and exercises a real interaction path. Web
   actions originate in rendered Ionic controls and production transport
   callbacks. TUI actions originate in keyboard focus/dispatch over the
   production frame and hit map.
4. The harness admits one temporary real Git target with an explicit stored
   `base_ref`. It installs an effective session-template package and proves the
   target-filtered template visible to the Workspaces target-first form.
5. Three successful spawn requests prove distinct managed-Git states:
   - a missing branch is created from the stored `base_ref` with a managed
     worktree;
   - a second spawn of that branch reuses the now-existing exact managed
     worktree;
   - a separately pre-created local branch receives a new managed worktree.
6. Collision proof is negative and non-destructive. At least a branch checked
   out by a foreign worktree and a foreign resource occupying the deterministic
   managed path are rejected with typed Hub errors. Neither failure may append
   a workspace reference, mutate the colliding branch/worktree, or delete a
   repository resource.
7. Every successful spawn records exactly the Hub-returned canonical session
   UUID once and the global single-workspace owner invariant remains true.
   Client oracles read returned/rendered action metadata and canonical entity
   frames; the integration harness never invents a successful session ID.
8. In both clients, the workspace surface is rendered/pulled once per
   sanctioned open/reconnect boundary. Each consumer driver records surface
   request counts. Current-to-ended changes must arrive through canonical
   `/session` snapshot/upsert/patch/remove frames without `list_sessions`, list
   refresh, polling, or an extra surface render used as synchronization.
9. Ended and removed/absent session references remain deliberate workspace
   history. Deleting the workspace removes only the grouping record and leaves
   sessions, managed worktrees, local branches, the source repository, and the
   explicit `base_ref` unchanged.
10. Contract provenance is part of the result. Core must expose no UI contract;
    Web must resolve its exact published `@trybotster/ui-contract` coordinate
    to Hub-produced bytes; TUI/TUI-kit must resolve one Rust
    `botster-ui-contract` Git source from `botster-hub`; Hub/client/test-support
    must use the in-repository contract crate.
11. No sibling-worktree paths, local dependency overrides, compatibility modes,
    dogfood bridges, fixed sleeps as success criteria, or timing-only assertions
    are accepted. Inputs are explicit immutable package/binary paths and exact
    revisions supplied by the caller.
12. Human answer `question_1785604382_430643` authorizes a pre-dependency slice:
    add only an independently testable Workspaces-owned shared-stack input
    skeleton and immutable provenance checks. It must not guess consumer driver
    invocation, consume sibling worktrees, run final acceptance, or claim Web
    or TUI behavior before both registered dependencies merge.

## Scope

The smallest Workspaces-owned change is an opt-in shared-stack profile beside
the existing real-Hub smoke. It owns lifecycle/setup/cleanup of one isolated
Hub, immutable package provenance checks, the Git-state matrix, coordination of
the merged consumer profiles, and final owner-boundary assertions.

In scope:

- a shared-Hub integration profile with strict required inputs for exact Hub,
  worker, Web, TUI, Workspaces, UI-contract, and consumer-runner provenance;
- one fresh Hub database and one admitted real Git repository with explicit
  `base_ref`, effective package session templates, deterministic branch and
  worktree fixtures, and cleanup that preserves failure evidence;
- install/enable/show proof for all three first-party packages in the same Hub;
- browser create/select/Spawn actions through the installed Web runtime and
  production renderer/transport;
- keyboard-driven TUI surface navigation/actions through the installed TUI
  runtime and shared contract;
- cross-client observation of the same workspace, membership, session entity
  lifecycle, client reconnect/reopen state, and history while the parent-owned
  Hub remains live;
- successful missing-branch, existing-worktree, and existing-branch spawns;
- typed collision rejection and repository/worktree/branch/session snapshots
  before and after each negative case;
- Core/UI-contract provenance and absence checks;
- repository docs, deterministic focused tests, and a durable implementation
  report recording exact pins and commands.

## Non-scope

- changing workspace schema, grouping semantics, Lua actions, lifecycle
  projection, UiNode copy/identity, manifest capabilities, or persistence;
- changing Hub managed-Git policy, target admission, template resolution,
  session lifecycle, package supervision, or UI-contract types;
- changing Web/TUI renderer behavior in this repository or adding
  workspace-specific client code;
- adding a second UI contract, compatibility envelope, local source override,
  test-only plugin action path, or dogfood adapter;
- broad refactors of the existing package runtime smoke, adjacent cleanup, new
  configuration, or a general multi-repository test framework;
- publication or release repair. A missing/stale consumable artifact is routed
  to its owning repository and remains a dependency.

## Ownership boundaries and cross-repository dependencies

`botster-workspaces` owns the final product-shaped scenario, semantic workspace
assertions, package fixture, shared-Hub orchestration, and non-destructive
grouping boundary. It consumes privileged Hub mechanisms and generic clients;
it does not implement them.

Closed prerequisites already present in this run include Core UI-contract
removal, contextual workspace replacement, the Hub Core-pin refresh, and
canonical current/ended lifecycle. Both clients already consume Hub-supervised
runnable-entrypoint connection injections. Web also supports a supplied
`BOTSTER_LIVE_DATA_DIR` and proves restored enabled-package reuse; TUI consumes
the injected Hub data directory directly. Their existing lifecycle modes are
useful supporting proof. The genuine missing delta is deterministic driving of
the owner-authored Spawn form across the managed-Git matrix from a Hub-launched
instance, with structured correlated evidence.

That narrow driver work is registered as blocking dependencies on the
authoritative consumer targets:

- Web `ticket_1785602852_464676`, target
  `tgt_40abcf71ccf049f4ac0c99953a799869`: reuse the existing
  `BOTSTER_HUB_CONNECTION`, `BOTSTER_LIVE_DATA_DIR`, and installed-package
  runtime paths; add only a deterministic rendered Workspaces
  create/select/assigned-Spawn driver plus structured action/entity/surface-
  request evidence. It must not own the daemon or package installation.
- TUI `ticket_1785602853_851250`, target
  `tgt_c3d470bab78549df920a41e8fb0e58d8`: reuse the existing
  `BOTSTER_HUB_CONNECTION` and `BOTSTER_HUB_DATA_DIR` runnable path; add only a
  deterministic keyboard Workspaces assigned-Spawn driver plus structured
  action/entity/surface-request evidence. It must explicitly prove no
  `list_sessions`, polling, list refresh, or synchronization surface rerender,
  and must not own the daemon or package installation.

If the shared run exposes a Hub managed-Git, package-supervision, client
protocol, Core boundary, or published-artifact defect, create a focused ticket
against that repository target and add it as a dependency. Do not patch it in
this run. The open Hub descendant-bound-identity ticket is not a dependency:
the current Workspaces surface deliberately uses valid literal per-reference
control identity.

The separate Project Pipelines routing-map omission remains workflow metadata
drift outside this repository. The human supplied the authoritative charter for
this run; implementation must not edit Project Pipelines package paths here.

## Affected surfaces and files

- `docs/plans/prove-complete-workspace-browser-tui-hub-spawn-flow.md`: this
  reviewable Plan artifact.
- `script/test-hub-flow`: add an explicit shared-stack profile while preserving
  the current default owner-runtime smoke. It owns the fresh data directory,
  one long-lived daemon lifecycle, Git fixture, package installation, Hub app
  launches, consumer sequencing, evidence collation, and cleanup. Client
  drivers receive Hub-injected connection/data context and never stop the Hub.
- `script/hub_acceptance_smoke`: expected to retain its current owner-runtime
  role. Extract or extend only narrow daemon-state assertions reusable after
  real consumer actions; do not count its hand-authored action requests as
  browser/TUI interaction proof.
- A small repository-local helper under `script/` may be added only if keeping
  process lifecycle, Git fixture setup, and state-oracle code inside
  `script/test-hub-flow` would obscure ownership. Prefer Ruby standard-library
  filesystem/process/JSON primitives already used by the repository.
- `script/test`: add static/profile contract assertions and red/green focused
  checks without making the expensive cross-repository stack run part of the
  default fast suite.
- `README.md`: document exact required immutable inputs, the shared-data-dir
  rule, command, scenario, supporting-vs-final evidence distinction, and owner
  routing on failure.
- `docs/workspace-domain.md` and `docs/capabilities.md`: expected unchanged
  unless a short verification cross-reference is needed; domain and authority
  contracts do not change.
- `test/plugin_runtime_test.lua`, `plugin.lua`, `botster-package.json`, and
  `test/fixtures/workspaces/contract.json`: inspected and expected unchanged.
- `docs/reports/prove-complete-workspace-browser-tui-hub-spawn-flow-implement-report.md`:
  durable Implement evidence with exact revisions, artifact
  coordinates/hashes, commands, structured client ledgers, negative cases, and
  cleanup result. `docs/reports/` has no prior art in this repository; this
  change establishes it deliberately while mirroring the established sibling
  Botster `-implement-report.md` naming convention.

## Implementation sequence

0. Before both consumer dependencies merge, implement only the authorized
   provenance/input skeleton from `question_1785604382_430643`, with positive
   validation and deterministic rejection of false hashes, dirty/mismatched
   revisions, and inferred relative paths. Do not define driver invocation.
1. Wait for both registered consumer dependencies to merge. Refresh Web, TUI,
   Hub, Core, and Workspaces main references and record exact immutable commits,
   lockfiles, published package coordinates, and package hashes. Reject dirty
   checkouts and inferred sibling paths.
2. Add the opt-in shared-stack profile to `script/test-hub-flow`. Require
   explicit executable/package/runner inputs, validate that each path belongs
   to the declared immutable revision/artifact, and create one short
   harness-owned data directory and socket.
3. Initialize a real Git source repository with a `main` commit. Admit it as a
   Git spawn target with explicit `--base-ref main`. Install/enable the effective
   session-template fixture, Workspaces, Web, and TUI packages through current
   Hub package commands. Assert exact enabled package rows, source provenance,
   runnable entrypoints, and template visibility before launching a client.
4. Prepare deterministic Git cases without bypassing Hub policy: leave branch
   A missing; pre-create branch B but no worktree; reserve branch C in a foreign
   worktree; and prepare a separate deterministic managed-path collision. Take
   machine-readable repository refs/worktree snapshots.
5. With the parent-owned Hub still live, launch the installed Web runnable
   entrypoint through Hub package/app commands and run the merged deterministic
   driver. Through rendered navigation and Ionic callbacks, create a uniquely
   named workspace, select detail, select the admitted target/effective
   template, and spawn missing branch A. Require the accepted action's returned
   session UUID, one workspace membership, canonical current entity, observable
   Hub-managed branch/worktree, and a surface-request baseline.
6. End the Web driver phase without stopping the Hub. Launch the installed TUI
   runnable entrypoint through Hub package/app commands and run the merged
   deterministic keyboard driver against the same state. Require the
   workspace/session created by Web to materialize first. Use keyboard focus and
   action dispatch to spawn branch A again (existing exact worktree) and branch
   B (existing branch/new managed worktree). Require distinct returned sessions,
   exact action identity from the realized hit map, single-owner membership,
   and a surface-request baseline.
7. Use the assigned real client controls to request branches C and the managed
   path collision. Assert typed rejection, retained form/error state where the
   client contract requires it, unchanged membership, no session upsert for the
   rejected requests, and byte-for-byte-equivalent Git refs/worktree ownership
   snapshots for the foreign resources.
8. With clients running sequentially/reconnected only at the client boundary,
   assert all three successful sessions appear in the same workspace. Stop them
   through the sanctioned Hub lifecycle path and consume ordered
   current-to-ended entity patches. In both client ledgers, require unchanged
   surface-request counts after the sanctioned open, no list/poll request, and
   history materialization from entity frames. Reopen/reconnect only when the
   consumer contract requires a new baseline and use authored node identity,
   not copy.
9. Delete the workspace through a real client action. Assert the grouping is
   absent while session history/entities, all successful worktrees, created and
   pre-existing branches, the foreign collision resources, repository commits,
   and source repository remain intact. The parent stops the one Hub only after
   all state, cross-client, provenance, and cleanup assertions are collected;
   no consumer may restart it as a retry.
10. Prove contract provenance: run Core's boundary test and source/export scan;
    verify Web's exact installed npm contract bytes and one resolved coordinate
    against the Hub-produced release; verify TUI/TUI-kit resolve one Hub Git
    `botster-ui-contract` source; verify Hub crates use their path workspace
    contract. Run explicit generated-protocol drift checks with authoritative
    Hub paths so skips cannot count as evidence.
11. Run the repository gates, deliberate negative oracle checks, `git diff
    --check`, PII/secret scans, and the complete shared-stack profile from a
    second fresh directory for repeatability. Attach the implementation report
    and route any cross-owner failure as a dependency instead of weakening an
    assertion.

## Acceptance checks and tests

Repository and owner-runtime checks:

- `script/test`
- `BOTSTER_UI_CONTRACT_PATH=<immutable Hub botster-ui-contract crate> script/validate_ui_node_contract`
- `BOTSTER_HUB_BIN=<immutable Hub binary> BOTSTER_SESSION_WORKER_BIN=<matching locked-Core worker> script/test-hub-flow`
- the new explicit shared-stack profile with exact immutable Hub, worker, Core,
  Web, TUI, Workspaces, published npm, and consumer-runner inputs
- `git diff --check`
- deliberate red/green checks showing that omission of explicit `base_ref`, a
  direct client action payload, a list/surface refresh fallback, a duplicate
  workspace membership, a collision mutation, or a destructive delete causes
  the relevant oracle to fail

The final shared-stack ledger must prove:

- one fresh Hub data directory, one socket, and exact package rows showing
  current Web, TUI, and Workspaces installed/enabled once;
- one real admitted Git target with persisted explicit `base_ref=main` and one
  effective session template selected through each client's real surface;
- Web-rendered contextual create and detail selection, plus at least one
  target-first Spawn through real renderer/transport click-through;
- TUI observation of Web state and target-first Spawn through keyboard focus,
  production frame, realized hit map, and shared action contract;
- missing branch creation, exact existing-worktree reuse, and existing branch
  reuse with three successful canonical session UUIDs;
- each returned UUID appears once in exactly one workspace and matches the Hub
  result/entity identity;
- branch-in-use and deterministic path-collision rejections change neither
  workspace membership nor foreign repository/worktree/branch state;
- canonical snapshot/upsert/patch/remove order moves sessions without
  `list_sessions`, polling, list refresh, or synchronization rerender;
- Web observes state/actions produced in the TUI/shared phase and TUI observes
  state/actions produced in the Web/shared phase;
- ended/removed references remain history across sanctioned client
  reconnect/reopen while the same parent-owned Hub remains live;
- workspace deletion preserves sessions, worktrees, branches, commits,
  `base_ref`, collision fixtures, and repository availability;
- Core has no UI contract dependency, module, re-export, alias, forwarding
  type, UI fixture, or public docs start path;
- Web resolves one exact registry `@trybotster/ui-contract` coordinate whose
  installed schema/declarations/fixtures match the Hub-produced artifact;
- TUI and TUI-kit resolve one Rust `botster-ui-contract` source at a merged Hub
  revision, with no Core UI crate or local override;
- all readiness and transition waits are bounded on exact entities, request
  IDs, sequence numbers, package health, or process exit—not fixed-delay
  success.

Existing Web/TUI lifecycle and caller-owned-data-dir modes remain useful
regression diagnostics and prove the connection/reuse plumbing. They do not
drive the Workspaces target-first Spawn form across the managed-Git matrix and
therefore cannot satisfy the final gate after `question_1785602772_466681`.

## Assumptions and unknowns

- Confirmed by human answer: one shared fresh Hub is mandatory; clients may run
  sequentially and use distinct deterministic names, but separate Hub databases
  are not final evidence.
- Verified fact: both installed clients already accept Hub-supervised
  connection injection; Web also supports caller-supplied data-dir reuse and
  TUI consumes the Hub data-dir injection. The dependencies add deterministic
  Workspaces interaction/evidence drivers only. If either needs a new generic
  Hub primitive rather than a driver hook, register that precise Hub dependency.
- Assumption: a second successful spawn for branch A is the correct production
  proof of the exact existing-worktree path, because the first missing-branch
  spawn creates the Hub-managed deterministic worktree.
- Assumption: a local pre-created branch without a worktree exercises the
  existing-branch path, while a branch checked out elsewhere and a foreign
  deterministic path exercise the two collision classes already owned by Hub.
- Unknown until dependency implementation: the exact CLI/profile names and
  structured result format exposed by Web and TUI. Implement must update this
  plan and report to the merged repository-documented commands; it must not
  invent aliases or private entrypoints.
- Unknown until immutable artifact assembly: the exact current Hub/Core commit,
  Web npm support/UI-contract coordinates, and TUI/TUI-kit Hub Git revision.
  Record and verify them at execution time; a closed source ticket alone is not
  consumable-artifact proof.
- Fixed ownership decision: the Workspaces parent owns the only Hub process,
  starts it once, launches client entrypoints sequentially through Hub package
  commands, and stops it after final evidence. Any client process lifecycle
  defect exposed under that existing model is routed to its owning package and
  blocks this ticket.
- Rails conventions are not implicated by this Lua/Ruby/Rust/TypeScript
  integration repository. General conventions apply: readable over clever,
  framework/library and universal filesystem/process primitives first,
  minimal dependencies, and cold paths without compatibility scaffolding.

## Risks and mitigations

- **False integration through composed summaries:** require one shared data
  directory and raw correlated package/client/entity/Git evidence, not a report
  that concatenates two isolated runs.
- **Test harness becomes a cross-repo framework:** keep orchestration local and
  scenario-specific; consume narrow repository-owned client profiles rather
  than embedding Web/TUI internals.
- **Hand-authored client actions:** derive Web actions from rendered controls and
  TUI actions from realized hit-map identity. Daemon requests are permitted only
  for fixture setup and independent state/oracle reads, never as substitutes for
  required user actions.
- **Mutable or masked dependencies:** require exact commits, lockfiles, registry
  tarball integrity/hashes, explicit paths, clean extracted package trees, and
  source graph scans. Reject sibling discovery and local overrides.
- **Collision fixture destroys user data:** all resources live under the short
  harness-owned temporary root; snapshot exact targets before negative actions
  and remove only harness-owned resources during cleanup.
- **Timing race mislabeled success:** wait on exact package health, action
  request/result correlation, entity identity/state/sequence, filesystem Git
  facts, and child exit with bounded diagnostics.
- **Rerender hides broken reconciliation:** count surface requests and fail if a
  lifecycle transition relies on another render, list request, or polling path.
- **Duplicate authority:** assert Workspaces persists only exact session UUID
  references and reads lifecycle/Git truth from Hub. Do not add cache fields or
  cleanup authority.
- **Stale visible-copy parser:** region oracles use stable authored/materialized
  node identity and structured action metadata, never heading punctuation.
- **Cleanup masks the original failure:** retain the first error, collect bounded
  logs/state, then stop/reap only harness-owned processes; cleanup failures are
  additive evidence.
- **Upstream defect repaired locally:** stop, create a focused owner-repository
  ticket, add a dependency edge, and preserve the failing immutable command.

## Vault gaps worth capturing

- The repository-routing source omitted the already-authoritative
  `botster-workspaces` charter. This is confirmed Project Pipelines metadata
  drift and should be captured/fixed by that workflow owner, not in this repo.
- If the shared-Hub consumer profiles establish a reusable pattern for
  cross-client package coexistence and shared durable truth, capture it only
  after both dependencies merge and the final run succeeds.
- If installed first-party runnable packages conflict over ownership or cleanup
  in one Hub, capture the precise package-supervision invariant after the owner
  fix is proven.
- No convention conflict is present in this Plan. No vault note is created yet;
  these are evidence-dependent candidates rather than established durable
  knowledge.

Every implementation line must trace to this shared-stack proof, a required
loaded convention, or cleanup made necessary by the harness itself.
