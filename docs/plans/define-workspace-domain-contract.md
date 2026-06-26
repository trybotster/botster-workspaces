# Define workspace domain model and capability contracts

## Context loaded

- Pipeline ticket: `ticket_1782431962_158133`, "Define workspace domain model and capability contracts".
- Current run: `run_1782438026_477685`, Plan step sequence 3 after Plan Review returned `changes_required`.
- Prior blocking review finding: dependency ticket `ticket_1782431962_346949` was registered and closed, but scaffold commit `f6917db` was not an ancestor of the run's original `origin/main`.
- Human answer to `question_1782438459_509801`: keep these new-repo tickets main-rooted; merge/reconcile the scaffold branch to `main`, then restart or refresh this run from fresh `main`.
- Resolution in this Plan pass: fetched `origin`, observed `origin/main` move to `c7f6f21`, verified `f6917db` is now an ancestor of `origin/main`, and fast-forwarded this run branch to `origin/main`.
- Current checkout now contains the required scaffold: `plugin.lua`, `botster-package.json`, and `script/test`.
- Required vault context read: [[planner-playbook]], [[botster-planner-playbook]], [[botster-architecture]], [[cli-patterns]], [[spa-patterns]], [[plan review must verify unmerged unregistered ticket dependencies]], [[plan review must validate cited file paths exist in target repo]], [[plan steps need reviewable plan artifacts]], [[botster plugin entities are canonical for plugin-owned dynamic state]], [[botster package manifests and lockfiles should declare capabilities and provenance]], [[botster plugin runtime data must not live in the plugin source tree]], [[workspaces are semantic groupings by purpose not by branch]], [[workspace as first-class concept bundles agent session persistence and single PTY]], and [[botster packages should enforce core hub cli plugin provider boundaries]].

## Base prerequisite

Do not implement this ticket on a bare README-only base. This run has now been refreshed to the main-rooted scaffold base, so implementation can extend the existing scaffold files.

Reason: this ticket must extend the existing package scaffold instead of re-authoring `plugin.lua`, `botster-package.json`, or `script/test` on a parallel branch.

## Scope

- Define the first contract for plugin-owned workspace records.
- Define local repo references as metadata and capability inputs, not as direct host filesystem reads.
- Define spawn target references as hub-owned identifiers consumed through declared capabilities.
- Define session grouping as workspace-to-session references, with the hub retaining actual process/session authority.
- Define default session templates as plugin-owned records used to request hub-owned spawns.
- Define workspace settings as plugin-owned settings records, with package configuration remaining manifest-level package metadata.
- Update the package README and add contract docs beside the plugin package.
- Extend `script/test` as the repo-approved test harness for this scaffold.
- Add contract fixtures or structured examples that tests can validate.

## Non-scope

- No Project Pipelines implementation.
- No new Project Pipelines UI, MCP tools, gates, findings, or run behavior.
- No hub storage migration.
- No direct writes to hub package registry, admitted spawn target records, or session manifests.
- No direct host filesystem access outside approved hub capabilities.
- No broad Botster core, Lua runtime, TUI, SPA, or hub refactor.
- No cloud sync, collaboration, or operator workbench behavior.

## Domain contract

Workspace records are plugin-owned state persisted through `plugin.db` under the plugin runtime data namespace, not under the plugin source tree.

Minimum workspace fields:

- `id`: stable plugin-owned workspace id, example `ws_001`.
- `name`: human label, unique among active workspaces.
- `purpose`: semantic grouping reason; this is the primary workspace meaning.
- `status`: `active`, `archived`, or `deleted`.
- `local_repo_ref`: plugin-owned reference object, not a raw filesystem grant.
- `spawn_target_ref`: hub-owned target reference by id.
- `session_group`: plugin-owned grouping of hub session references.
- `default_session_template_id`: optional plugin-owned template reference.
- `settings`: plugin-owned settings object.
- `created_at` and `updated_at`: contract timestamps.

Local repo reference fields:

- `id`
- `display_name`
- `repo_capability_ref`
- `default_branch`
- `relative_worktree_hint`

Spawn target reference fields:

- `target_id`
- `label`
- `kind`
- `capability_ref`

Session group fields:

- `workspace_id`
- `session_refs`, each with `session_uuid`, `role`, `spawned_from_template_id`, and `status`

Default session template fields:

- `id`
- `name`
- `spawn_target_ref`
- `command_profile`
- `initial_prompt_template`
- `environment_policy`
- `enabled`

Workspace settings fields:

- `workspace_id`
- `default_repo_ref_id`
- `default_spawn_target_id`
- `default_session_template_id`
- `archive_policy`

## Ownership and capabilities

Plugin-owned state:

- Workspace records.
- Local repo reference metadata.
- Spawn target reference metadata.
- Session group records.
- Default session templates.
- Workspace settings.
- Workspace entity read models published through plugin-owned entity frames.

Hub-owned authority:

- Package install, provenance, lock metadata, and enablement.
- Admitted spawn target records and spawn authorization.
- Actual process and PTY lifecycle.
- Actual session UUIDs, terminal transport, scrollback, and recovery.
- Scoped filesystem capability enforcement.

`botster-package.json` capability declarations should move from the scaffold's empty `capabilities: []` to explicit requested capabilities for the contract surface:

- `plugin_db`: persist workspace records, templates, session group references, and settings.
- `entities`: publish workspace, repo reference, spawn target reference, template, and settings read models.
- `surfaces`: expose workspace app/settings descriptors already present in the scaffold.
- `spawn_targets:read`: list or validate hub-owned spawn target references.
- `sessions:read`: resolve hub-owned session references for grouping.
- `process:spawn`: request sessions from default templates through hub-owned spawn authority.
- `filesystem:scoped_repo`: resolve approved repo references without direct host filesystem traversal.

If current Botster manifest schema does not support one of these exact names, implementation should use the nearest existing schema-supported capability name and document the mapping in the contract doc. Do not add unvalidated capability strings silently.

## Affected surfaces and files

Expected work after the base prerequisite is fixed:

- `botster-package.json`: add explicit capability declarations required by the workspace contract.
- `plugin.lua`: keep the package entrypoint minimal unless a contract fixture/provider is needed; do not add runtime product behavior beyond contract scaffolding.
- `README.md`: summarize contract docs, state the plugin/hub authority boundary, and document `script/test`.
- `docs/workspace-domain.md`: authoritative workspace domain contract.
- `docs/capabilities.md`: explicit plugin-state versus hub-authority capability contract, if not folded into `docs/workspace-domain.md`.
- `test/fixtures/workspaces/*.json` or `tests/fixtures/workspaces/*.json`: PII-free contract fixtures if the test harness needs structured inputs.
- `script/test`: extend the existing Ruby harness from the scaffold branch.
- This plan artifact: `docs/plans/define-workspace-domain-contract.md`.

## Assumptions and unknowns

Assumptions:

- The scaffold dependency branch is the intended base for this ticket.
- `script/test` from the scaffold branch is the repo-approved harness for this package.
- This ticket is intentionally contract/scaffold-level, not a runtime feature implementation.
- Workspace identity follows semantic purpose, not branch identity.
- Plugin-owned records can be represented as contract fixtures before runtime CRUD functions exist.

Unknowns:

- Exact capability names supported by the current Botster package manifest schema.
- Whether `plugin.db` migration files are already supported in this package scaffold, or whether the first pass should keep persistence as a documented contract plus fixtures.

## Contract tests

Use `script/test`.

Required create tests:

- Creating a workspace with `name`, `purpose`, `local_repo_ref`, and `spawn_target_ref` yields a workspace record with generated `id`, `active` status, timestamps, empty `session_group.session_refs`, and default settings.
- Creating a workspace without `name`, without `purpose`, without `local_repo_ref`, or without `spawn_target_ref` fails with a contract error.
- Creating a second active workspace with the same `name` fails.

Required list tests:

- Listing workspaces returns active workspaces sorted by name or explicit position, with archived/deleted visibility documented.
- List rows include only read-model fields and do not expose raw host filesystem paths.
- List rows include plugin-owned entity family identifiers if entity fixtures are present.

Required show tests:

- Showing a workspace by id returns the full workspace record, local repo reference metadata, spawn target reference metadata, session group, default template reference, and settings.
- Showing an unknown id returns a not-found contract error.

Required update tests:

- Updating `name`, `purpose`, `local_repo_ref`, `spawn_target_ref`, `default_session_template_id`, and settings patches only allowed plugin-owned fields.
- Updating hub-owned fields such as actual session process state is rejected.
- Updating to a duplicate active name fails.
- Updating session group references accepts only session reference metadata and does not claim hub session ownership.

Required delete/archive tests:

- Deleting a workspace marks it `deleted` or archives it according to the documented contract.
- Deleted workspaces are excluded from default list behavior.
- Delete does not delete hub sessions, package records, spawn targets, repos, or host filesystem content.

Required capability and negative tests:

- Contract fixtures require the manifest capabilities named in this plan.
- No Project Pipelines implementation files or identifiers are introduced.
- No direct host filesystem APIs are used in docs, fixtures, or plugin scaffolding outside capability descriptions.
- PII scan rejects absolute home paths, email addresses, session ids, secrets, tokens, passwords, and API keys in docs and fixtures.

## Risks

- Implementing before the scaffold dependency is in the base will create a divergent copy of the package scaffold.
- Capability names may drift from the current manifest schema; implementation must validate against the compiled Botster package schema.
- Tests that only assert markdown existence will not satisfy the ticket; tests must validate concrete CRUD contract examples and negative constraints.
- Raw local paths in examples would violate the no-PII requirement and the path-neutral plan convention.
- Adding runtime CRUD/MCP behavior could overrun a contract-only ticket.

## Acceptance checks

- `git merge-base --is-ancestor f6917db origin/main` passes, and this run branch is based on refreshed `origin/main`.
- `botster-package.json`, `plugin.lua`, and `script/test` exist before implementation begins.
- `script/test` passes after contract docs and fixtures are added.
- `script/test` includes create/list/show/update/delete contract coverage.
- `script/test` includes negative checks for no Project Pipelines implementation, no unapproved host filesystem access, and no PII.
- Docs define workspace records, local repo references, spawn target references, session grouping, default session templates, workspace settings, and plugin/hub ownership boundaries.
- Manifest capability declarations match documented capability usage.

## Vault gaps worth capturing

- If this shape holds after implementation, capture a durable note for "botster-workspaces records are plugin-owned while spawn/session/repo authority stays hub-capability-owned".
- If another newly scaffolded plugin ticket hits the same issue, capture a convention that contract-only plugin tickets still need a committed `docs/plans/` artifact and an executable scaffold harness before Plan Review.
