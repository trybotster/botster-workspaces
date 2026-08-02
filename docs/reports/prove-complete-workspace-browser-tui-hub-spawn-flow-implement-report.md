# Complete Workspaces browser, TUI, and Hub spawn flow — Implement report

## Target and applied guidance

- Target repository: `trybotster/botster-workspaces`.
- Target ID: `tgt_71266a8d976d4535902ffed09c18a7ba`.
- Ticket/run: `ticket_1785192726_335558` / `run_1785602425_939731`.
- Repository charter: [[botster-workspaces-playbook]], authorized by human
  answer `question_1785602485_811365` because the supplied routing map omitted
  this admitted target.
- Role/workflow playbooks: [[implementer-playbook]],
  [[botster-implementer-playbook]], and [[project-pipelines-playbook]]. The
  Project Pipelines playbook constrained routing, dependency, checklist,
  artifact, gate, and handoff evidence; no Project Pipelines source was edited.
- Architecture and surface notes: [[botster-architecture]], [[cli-patterns]],
  [[spa-patterns]], [[workspaces are semantic groupings by purpose not by branch]],
  [[botster workspace records are plugin owned references not hub authority]],
  [[botster plugin entities are canonical for plugin-owned dynamic state]],
  [[workspace session templates are hub owned capabilities callable from lua workers]],
  [[device hub owns admitted spawn targets not ambient repo cwd]],
  [[runtime client acceptance must render delivered snapshots through real registry]],
  [[renderer acceptance tests must drive real frame backend]],
  [[conformance helpers must dispatch the action id read from the rendered node]],
  [[conformance harnesses gate on deterministic invariants not timing]],
  [[acceptance harness region oracles must key on node identity not concatenated text]],
  [[external client hub tests use subprocess spawned hub test support]],
  [[botster web generated protocol drift checks need explicit hub artifact paths]],
  [[hub generated protocol changes are a four site release chain]],
  [[botster core contract surface needs consumer proof]],
  [[botster package surface semantics live in ui contract while hub owns admission]],
  [[a regression test must be shown to go red with the fix reverted]],
  [[botster plugins need headless real-runtime test harnesses]],
  [[live hub proof records distinct hub and locked core binary provenance]],
  [[implementation artifacts must match actual git state]],
  [[implementation deviations must resync committed plan acceptance checks]],
  [[implement gate must verify committed work and pr link before review]],
  [[implementation steps must persist report artifacts for review]], and
  [[pipeline vault checklists must cite exact resolvable note titles]].
- Convention conflicts: none. Rails conventions do not apply to this
  shell/Ruby acceptance surface. The implementation uses readable,
  standard-library filesystem/process/JSON primitives and adds no dependency.

## Files changed

- `README.md` documents the immutable-input manifest, one-Hub rule, commands,
  proof boundary, and evidence ledger.
- `script/validate_shared_stack_inputs` validates absolute executable/package
  inputs, exact clean Git revisions, contract coordinates, and artifact hashes.
- `script/shared_stack_acceptance` owns the isolated Hub, admitted Git fixture,
  package lifecycle, real Web/TUI sequencing, collision/deletion oracles,
  provenance checks, raw evidence, cleanup, and final summary.
- `script/test-hub-flow` exposes explicit `shared-stack validate-inputs` and
  `shared-stack run` profiles without changing the default owner smoke.
- `script/test` adds fast contract and negative provenance coverage for the new
  opt-in profile.
- `script/hub_acceptance_smoke` preserves the first Hub exit status and isolates
  its supporting owner smoke from the shared product scenario.
- `test/fixtures/shared-stack-owner-template/botster-package.json`,
  `plugin.lua`, and `bin/session.sh` provide a qualified, lifecycle-bound owner
  fixture used only for the supporting smoke.
- `docs/plans/prove-complete-workspace-browser-tui-hub-spawn-flow.md` records the
  approved plan, resolved consumer interfaces, separately routed producer
  repair, acceptance ledger, and vault gaps.
- This report records Implement evidence and assumptions.

The separately routed repair merged `plugin.lua`,
`test/plugin_runtime_test.lua`, and
`docs/plans/preserve-hub-managed-git-collision-identity.md` into canonical
Workspaces `main`; those are consumed inputs, not parent implementation edits.

## Ownership boundaries and routed dependencies

The change stays inside the Workspaces charter: it orchestrates and asserts the
product-shaped scenario, owns the temporary fixture and semantic grouping
oracles, and delegates Git/session/package authority to Hub. It does not add
Web/TUI behavior, forge client actions, modify UI contracts, implement managed
Git policy, or move lifecycle truth into Workspaces. Web actions are emitted by
the installed production renderer/transport driver; TUI actions pass through
the installed binary's keyboard focus and realized hit map.

Cross-repository work remained separately routed and was consumed only after
merge:

- Web driver `ticket_1785602852_464676` at
  `99fff571b022e5e06535759c6ffe61926600d07a`.
- TUI driver `ticket_1785602853_851250` at
  `4faa221da665e001a8802c4ecad50ea1f1077812`.
- Workspaces semantic-action producer/consumer follow-ups recorded in the
  parent dependency graph.
- Workspaces typed-collision repair `ticket_1785625579_666761` /
  `run_1785625592_402690`, merged by PR #13 at
  `5668dd78052f821600db28fbc459f3df9114f234`.
- Project Pipelines routing metadata follow-up
  `ticket_1785626117_842560` remains outside this repository.

The unrelated open Hub descendant-bound-identity work is not a dependency;
this surface uses valid literal per-reference control identity.

## Deviations from the approved plan

- The final Hub input is `fab44c5de7b28a8756268608662d2b870efb001a`,
  selected because it is the exact merged revision consumed by both client
  contract graphs. This is stricter than choosing a newer unrelated Hub head.
- The supporting owner smoke runs before the product scenario. Its qualified
  fixture is then disabled and Workspaces reloaded so both clients see exactly
  one producer-authored session template. This preserves the one-Hub rule while
  preventing the support fixture from making target-first selection ambiguous.
- The first full run exposed Workspaces reading `ManagedGitError.code` while Hub
  serializes `kind`. The parent oracle was not weakened: the failure was
  preserved, separately routed, ablated/proved in the owner repository, merged,
  and canonical `main` was merged back before final acceptance.
- Verification found that an evidence summary also needed the parent harness's
  own clean revision. The harness now fails closed on a dirty checkout and
  serializes `artifacts.shared_stack_harness`.

There is no scope or architecture waiver.

## Tests and downstream proof

Repository checks run during implementation:

- `script/test` passed after each harness correction and after the
  self-provenance addition.
- Ruby syntax checks for the new/changed Ruby scripts passed.
- `git diff --check` passed.
- `BOTSTER_UI_CONTRACT_PATH=/private/tmp/botster-shared-stack-source.f5YiJB/botster-hub/crates/botster-ui-contract script/validate_ui_node_contract`
  is the final explicit generated-contract drift gate.

Downstream-shaped runtime history:

- `/private/tmp/botster-workspaces-shared-stack-evidence-13924bb` proved one-Hub
  package setup, the real Web cold flow, and all three real TUI keyboard cases,
  then intentionally stopped on the typed-collision producer defect.
- `/private/tmp/botster-workspaces-shared-stack-evidence-c085959-parent-44e6f76/summary.json`
  passed the complete scenario against the committed owner repair.
- `/private/tmp/botster-workspaces-shared-stack-evidence-verify-c085959-parent-0ca3844-1785628371-escalated/summary.json`
  independently passed the complete scenario and records a clean parent
  harness revision. It proves one Hub/data directory, four browser cases,
  three TUI sessions, exactly one owner for every successful session,
  `branch_in_use` and `path_collision` with unchanged membership/Hub sessions/
  Git/foreign resources, grouping-only deletion, Core UI absence, and exact Hub
  contract provenance.

The authoritative final gate runs only after this report-bearing commit is
clean, with Workspaces set to that commit (which contains canonical repair merge
`5668dd7`). Its exact revision, command, evidence directory, hashes, client
ledgers, and result are persisted as a Project Pipelines artifact. This
intentional artifact placement avoids editing this report after the run and
thereby invalidating the clean harness revision recorded by the summary.

Immutable final inputs are Core/worker
`5846fc776d31e2b6c98a8d932f50a31078743901`, Hub
`fab44c5de7b28a8756268608662d2b870efb001a`, Web
`99fff571b022e5e06535759c6ffe61926600d07a`, TUI
`4faa221da665e001a8802c4ecad50ea1f1077812`, TUI-kit
`3bf8ae81d3e716b196fae8e4a7560dd5fc5c2e69`, and
`@trybotster/ui-contract@0.2.0` with exact Hub-produced bytes.

## Assumptions, unverified behavior, and residual risk

- `ManagedGitError.kind` at the pinned Hub revision is authoritative;
  Workspaces deliberately projects it into its established public
  `error.code` result field.
- The installed Web/TUI drivers' structured ledgers are supporting evidence;
  parent assertions against live Hub/plugin/Git state remain the independent
  oracle.
- At report freeze, the only unverified behavior is the final replay against the
  clean report-bearing parent commit containing canonical Workspaces main. A
  failed replay blocks the gate and must be routed without weakening an oracle.
- The acceptance harness is opt-in because it requires several immutable
  repository/build artifacts and a real browser/PTY. The fast suite proves its
  interface and fail-closed validation, not the expensive runtime behavior.
- Evidence lives under a private temporary directory and is not a release
  artifact. Project Pipelines stores its durable coordinates and assertions.

## Missing vault guidance

- The Implement routing table omitted `botster-workspaces` even though an exact
  authoritative charter exists. Human guidance resolved this run; durable
  workflow repair is separately routed as `ticket_1785626117_842560`.
- No loaded atomic note states that semantic-action-only selection is valid only
  when the producer guarantees exactly one realized match and every consumer
  fails closed on zero or multiple matches. The Web and TUI drivers rely on and
  prove that invariant. It should be captured through the vault workflow after
  final acceptance.
- The collision repair also exposed a reusable typed-error adapter gotcha:
  consumers must preserve the producer's serialized discriminator field name
  (`kind` here), rather than assuming a generic `code` property.

No vault file was written from this repository-scoped run.
