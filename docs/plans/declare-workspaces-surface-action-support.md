# Declare Workspaces surface action support

## Target and context loaded

- Target repository: `trybotster/botster-workspaces`.
- Target ID: `tgt_71266a8d976d4535902ffed09c18a7ba`.
- Ticket: `ticket_1785295905_406600`.
- Repository charter: [[botster-workspaces-playbook]].
- Role context: [[planner-playbook]], [[botster-planner-playbook]],
  [[botster-architecture]], [[cli-patterns]], and [[spa-patterns]].
- Package/runtime surface guidance: [[botster-package-reviewer-playbook]],
  [[botster-package-verifier-playbook]], and
  [[botster-runtime-verifier-playbook]].
- Workspaces and package constraints:
  [[workspaces are semantic groupings by purpose not by branch]],
  [[botster workspace records are plugin owned references not hub authority]],
  [[botster plugin entities are canonical for plugin-owned dynamic state]],
  [[botster package manifests and lockfiles should declare capabilities and provenance]],
  and [[botster hub gravity must be watched before it becomes the new monolith]].
- Targeted runtime/test constraints:
  [[botster package manifest validation requires hub compiled core revision]],
  [[device botster cli cannot validate hub package manifests]],
  [[plugin owned actions execute in plugin worker vms]],
  [[plugin supervisor invocation wraps plugin owned action execution]],
  [[plugin capability tests must validate against real lua runtime table not injected stubs]],
  [[plugin surface registration uses injected global not require]],
  [[plugin surface handlers must validate against hub locked uinode contract]],
  [[conformance helpers must dispatch the action id read from the rendered node]],
  [[fixture driven acceptance smoke tests can prove first party package plumbing]],
  and [[plugin tests must prove worker boundaries not hub leakage]].
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
  Project Pipelines package/plugin path or workflow policy; Project Pipelines
  is only the delivery mechanism.
- Repository context inspected: current `origin/main` versions of
  `README.md`, `botster-package.json`, `plugin.lua`, `script/test`,
  `script/hub_acceptance_smoke`, `script/validate_ui_node_contract`,
  `test/plugin_runtime_test.lua`, the workspace contract fixture, prior
  `docs/plans/*.md`, recent history, and worktree status.
- Exact Hub seam inspected: current `botster-hub` `origin/main` package
  surface DTO/projection, `PackageSurfaceOperation`, daemon
  `plugin_surface_action`, and Hub-owned contract-matrix fixtures.
- Baseline: an isolated export of Workspaces `origin/main` passed
  `script/test`.

## Resolved product decision

The ticket's `spawn_default_session_action` wording predates the merged
contextual-workspace cold switch. Human answer
`question_1785344200_451405` authorizes this run to:

- declare `supports: ["render", "action"]` on the sole `workspaces` surface;
- prove the current `create_workspace_action` and replacement
  `spawn_session_action` / `botster_workspaces.spawn`;
- never restore, alias, or present `spawn_default_session_action` as a
  supported runtime path.

## Scope

1. Refresh the run branch onto current Workspaces main before editing. The run
   worktree was created at `d4dcf3b`, while the required contextual-workspace
   implementation is already merged on `origin/main` at `dc092fc` or later.
2. Change only the sole `workspaces` descriptor's operation declaration from
   `["render"]` to `["render", "action"]`.
3. Tighten repository conformance assertions so the exact single surface
   descriptor is preserved apart from its required operation list.
4. Extend the real current-Hub smoke to assert the installed package projects
   the exact `["render", "action"]` operations before exercising the existing
   create and atomic spawn actions through `plugin_surface_action`.

## Non-scope

- No workspace schema, persistence, membership, lifecycle, or entity change.
- No Lua handler, action envelope, surface tree, presentation, form, atomic
  spawn workflow, capability grant, or navigation change.
- No compatibility alias or fallback for `spawn_default_session_action`.
- No Hub, Core, UI-contract, Web, TUI, TUI-kit, or Project Pipelines source
  change.
- No renderer proof beyond the unchanged owner-authored surface; this is a
  manifest/admission prerequisite, not a UI change.
- No adjacent documentation cleanup or broad manifest refactor.

## Ownership boundaries and dependencies

- `botster-workspaces` owns its package manifest and the registered
  `workspaces` surface/action handlers. This run changes only that manifest
  declaration and its repository-owned conformance proof.
- `botster-hub` owns package parsing, operation projection/admission, daemon
  dispatch, and plugin-worker execution. It is an acceptance environment, not
  a changed repository.
- Hub ticket `ticket_1785294387_531161` is downstream of this prerequisite.
  This run must validate against the current merged Hub before strict
  enforcement lands; it does not depend on or implement that Hub ticket.
- There is no cross-repository implementation dependency to register.

## Assumptions and unknowns

- `["render", "action"]` is the canonical order used by the current exact Hub
  contract and conformance fixtures.
- "No other first-party surface declaration" means the merged Workspaces
  package keeps exactly one surface, `workspaces`; navigation and every other
  descriptor field remain byte-for-byte unchanged.
- The exact acceptance Hub revision may advance before Implement/Verify. Record
  the Hub checkout SHA and its locked dependency provenance used to build the
  tested binaries; do not use the stale local Hub checkout or the device
  `botster` CLI as manifest evidence.
- The current Hub does not yet strictly reject undeclared action operations.
  Passing manifest validation, observing the projected operation list, and
  dispatching both real actions is intentional prerequisite proof.

## Affected surfaces and files

- `botster-package.json`
  - change the sole `workspaces` surface `supports` list to
    `["render", "action"]`.
- `script/test`
  - assert the complete single surface descriptor, including the new exact
    operation list, so no second surface or unrelated descriptor field can
    drift.
- `script/hub_acceptance_smoke`
  - assert the installed/enabled package projects the sole Workspaces surface
    with exact render/action support before the existing real create and spawn
    action sequence.
- `docs/plans/declare-workspaces-surface-action-support.md`
  - this reviewable Plan-stage artifact.

`plugin.lua`, workspace fixtures/domain docs, UI validation, and renderer code
are intentionally unaffected.

## Implementation sequence

1. Integrate current `origin/main` without overwriting the user-owned worktree
   changes in `.gitignore`, `.env`, or `mise.local.toml`.
2. Make the one manifest operation-list edit.
3. Replace the narrow render-only static assertion with an exact descriptor
   assertion that protects the ticket's no-other-surface-change boundary.
4. Add the exact installed-package operation assertion to the current real-Hub
   smoke. Reuse its existing `plugin_surface_action` create and atomic spawn
   calls; do not duplicate handlers or add a synthetic path.
5. Run the repository and exact-Hub gates below, inspect the final diff for
   only ticket-traceable lines, and record binary/source provenance.

## Risks

- Implementing against the stale run worktree would modify the removed
  repository-bound product and could accidentally resurrect
  `spawn_default_session_action`.
- A static JSON assertion alone would not prove the exact Hub accepts and
  projects the operation declaration.
- A mocked or direct Lua handler call would not prove daemon dispatch through
  the plugin-worker boundary.
- A Hub binary built from a stale checkout could validate a different schema
  or omit the production action path.
- The spawn half of the existing smoke requires its documented isolated Hub
  setup with an enabled Git target and an effective session template.
- Broadening the manifest test into fixture/schema changes would create
  unrelated churn and weaken the surgical scope.

## Acceptance checks and downstream proof

Repository checks:

```sh
script/test
git diff --check
git diff --stat origin/main
git diff origin/main -- botster-package.json script/test script/hub_acceptance_smoke
```

Required assertions:

- `botster-package.json` contains exactly one surface, `workspaces`, with the
  unchanged id/kind/title/description/icon/category and exact
  `supports: ["render", "action"]`.
- Navigation, capabilities, entrypoints, workspace contract fixtures, schema,
  `plugin.lua`, and UI trees are unchanged.
- The repository fast test passes from the refreshed main baseline.

Real packaged Hub gate:

```sh
script/hub_acceptance_smoke <isolated-current-hub.sock> [workspace-name]
```

The acceptance environment must use a freshly built current merged Hub and
session worker with a fresh data directory, enabled Git spawn target, and
effective session template. Record the Hub SHA and locked worker/dependency
provenance. The smoke must prove:

- local-path install, enable, and reload of this checkout succeed;
- the daemon package projection exposes only `workspaces` and reports exact
  render/action support;
- `create_workspace_action` returns a structured result through the real
  `plugin_surface_action` daemon request and plugin worker;
- the rendered current spawn action dispatches
  `spawn_session_action` / `botster_workspaces.spawn` through the same real
  path and completes the existing atomic Hub spawn/persistence assertions;
- no removed default-session action or compatibility path is present.

No Web/TUI downstream run is required: the ticket changes no UiNode or renderer
behavior, and the Workspaces charter's downstream generic-consumer proof is
conditional on UI changes. The exact Hub/plugin-worker path is the production
entry point changed by this manifest admission prerequisite.

## Vault gaps worth capturing

- No new Workspaces architecture note is required; the loaded package,
  worker-boundary, and cold-switch notes already cover the decision.
- The installed Botster Stack Delivery prompt still omits
  `botster-workspaces` from its displayed inline routing map even though the
  prior routing ticket is closed. Verify the standalone Project Pipelines
  package source versus installed state before capturing or filing this as
  durable workflow drift; do not broaden this repository run.
