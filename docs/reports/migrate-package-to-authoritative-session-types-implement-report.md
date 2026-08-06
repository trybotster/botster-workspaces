# Implementation report — migrate Workspaces to authoritative session types

## Routing

- Ticket: `ticket_1785984128_479155`, "Workspaces: migrate package to authoritative session types".
- Target: `tgt_71266a8d976d4535902ffed09c18a7ba` → `trybotster/botster-workspaces`. Resolved from the ticket target, not from the process working directory; the run worktree remote is `https://github.com/trybotster/botster-workspaces.git`.
- Run: `run_1786035894_642389`, step `botster_stack_implement`, branch `project-pipelines/ticket_1785984128_479155`, base `main` at `7587c7f`.
- Approved plan: `docs/plans/migrate-package-to-authoritative-session-types.md`, artifact `artifact_1786037699_726580` at plan commit `72e2544`, approved by `review_1786038162_269267`. It supersedes `artifact_1786036783_774551` and the cancelled run `run_1785987292_480836`.
- Implementation commit: `64b9e99`. PR [#15](https://github.com/trybotster/botster-workspaces/pull/15), linked as `pr_1786039501_692188`.

## Guidance applied

Repository charter: [[botster-workspaces-playbook]]. Role overlays: [[implementer-playbook]], [[botster-implementer-playbook]]. Workflow policy: [[project-pipelines-playbook]] via [[implement gate must verify committed work and pr link before review]], [[implementation artifacts must match actual git state]], [[implementation steps must persist report artifacts for review]], [[pipeline vault checklists must cite exact resolvable note titles]], and [[project pipelines mcp create calls can time out after committing]].

Targeted notes that constrained the change:

- [[cold turkey migrations eliminate dual code paths and version suffixes]] — no alias, no dual key, no dual capability table, no fallback decoder.
- [[plugin capability tests must validate against real lua runtime table not injected stubs]] — the fake Lua boundary is not evidence; the real installed-package Hub path is the proof.
- [[a regression test must be shown to go red with the fix reverted]] — every new negative assertion was ablated.
- [[stdin fed lua harnesses can print assertion failures while exiting zero]] — the Lua harness is executed as a file and the existing `BOTSTER_WORKSPACES_INJECT_FAILURE` gate proves nonzero status crosses the shell boundary.
- [[botster package manifests and lockfiles should declare capabilities and provenance]] — the capability scope is the migration's load-bearing declaration.
- [[plugin ui action ids are a two site change and hub fails closed on unregistered ids]] — action ids and their registered descriptors are unchanged; only the request field moved.
- [[workspace session templates are hub owned capabilities callable from lua workers]] and [[session template override sources use package device repo explicit precedence]] — both describe the superseded vocabulary as current; recorded as vault gaps below.

## Files changed

| Path | Change |
| --- | --- |
| `botster-package.json` | Capability scope `session_template_managed_git_spawn` → `session_type_managed_git_spawn`. |
| `plugin.lua` | `session_types_for_target` replaces `templates_for_target`; calls `botster.capabilities.session_types`; consumes only `session_type_id`; spawn request, MCP schema, form field name, error codes, locals renamed. |
| `test/fixtures/workspaces/contract.json` | New scope, `session_types.ensure_worktree_and_spawn`, `session_type_api`, `session_type_request_field`. |
| `test/plugin_runtime_test.lua` | Fake boundary exposes only `session_types` and returns fully qualified rows; exact managed-request assertion; `template_id` rejection; three frozen keys assert `obsolete_field`; action-adapter forwarding test. |
| `script/test` | New required/contract/fixture assertions; scoped cold-cut token audit with exact allowlist; frozen-key presence assertion; scanned-file list extended to both renamed fixture trees. |
| `script/test-hub-flow` | Renamed fixture path/constant and enabled package name. |
| `script/hub_acceptance_smoke` | Protocol-6 `DaemonCompatibilityRequirement` handshake; Hub-emitted compatibility assertions; qualified `session_type_id` selection; `/session` entity session-type assertion; `template_id` negative control. |
| `script/shared_stack_acceptance` | `SESSION_TYPE_ID` / `OWNER_SESSION_TYPE_ID`; `.botster/session-types.json` with required descriptor fields; renamed fixture path and package name; `session_type_id` in driver cases and collision proof. |
| `test/fixtures/session-type-package/**` | Renamed from `session-template-package`; package `botster-workspaces-acceptance-session-type`; `session_types` manifest key with `label`/`role`/`interaction`/`traits`/`lifecycle`. |
| `test/fixtures/shared-stack-owner-session-type/**` | Renamed from `shared-stack-owner-template`; package `botster-workspaces-shared-stack-owner-session-type`; same manifest shape. |
| `README.md`, `docs/capabilities.md`, `docs/workspace-domain.md` | Current session-type vocabulary; Hub ownership of descriptor taxonomy, source precedence, and editability stated explicitly. |

Deliberately unchanged, per plan non-scope:

- The authored `botster-workspaces-spawn-template` node id. It is presentation identity, not a request field; both first-party drivers key on the field *name*. The field it carries is now `session_type_id`.
- `OBSOLETE_FIELDS` keys `default_session_template`, `default_session_template_id`, `default_session_template_refs`. These are frozen pre-production create arguments that must keep producing `obsolete_field`.
- The UiNode `item_template` / `empty_template` primitives, which are unrelated framework vocabulary.

## Ownership boundaries preserved

Workspaces still owns only grouping records, membership, plugin-owned persistence, owner-authored UiNode surfaces, and the decision to request a spawn before recording the returned UUID. Every session-type fact this change touches is *consumed*, never authored: the fully qualified `session_type_id`, the `role` / `interaction` / `traits` / `lifecycle` taxonomy, source precedence, editability, and admission all remain Hub-owned. The package still invokes exactly one privileged mutation, `session_types.ensure_worktree_and_spawn`, and still supplies no session id, cwd, repository path, worktree path, or base ref. No session-type rows are duplicated into `plugin.db` and no competing entity family is published.

The `.botster/session-types.json` file written by `script/shared_stack_acceptance` is a Hub-format repo fixture created by this repository's own harness, not a Workspaces-owned format.

## Cross-repository dependencies and separately routed work

No source outside `trybotster/botster-workspaces` was edited and no PR was opened against another repository. The upstream dependency `ticket_1785970233_236046` (botster-hub) is closed and merged at `8a60bd58`.

Renaming the spawn request field `template_id` → `session_type_id` deterministically breaks two first-party drivers that key on the field name. Both are registered against their owning repositories:

- `ticket_1786036326_597046` (botster-tui) — driver rename at `crates/botster-tui/src/app.rs:3893`, plus un-skip and proof of all three `script/test-live-hub` Workspaces profiles. Blocked on this ticket **and** `ticket_1785976581_841608`.
- `ticket_1786036336_442121` (botster-web) — driver rename at `scripts/workspaces-shared-hub-browser-helpers.mjs:69` and `scripts/workspaces-shared-hub-browser-smoke.mjs:135`, plus the stale repo fixture at `-smoke.mjs:152-154`. Blocked on this ticket.

## Deviations from plan

1. **Cold-cut audit allowlist is exact keys plus line-marked negative controls.** The plan said to allowlist only the three exact `OBSOLETE_FIELDS` keys. But the plan's own acceptance check 2 requires a `template_id` negative control in the real smoke and in the Lua test, which necessarily names the token inside audited files. The audit therefore also skips lines carrying the literal marker `cold-cut negative control`. Four lines are exempt in total, each of which asserts the token is *rejected*. `script/test` itself is excluded from the audit because it defines the forbidden literals; its own vocabulary is covered by explicit assertions instead. Proven load-bearing: reintroducing a live `session_templates` mention in `docs/capabilities.md` fails the audit.

2. **`script/shared_stack_acceptance` session-type id is now fully qualified.** `TEMPLATE_ID` was the bare `"shared-stack"`; `SESSION_TYPE_ID` is `"workspaces-shared-stack/shared-stack"`. Effective rows have always been qualified as `<source name>/<id>` (repo sources are named for their admitted target), so the bare value could never have matched a rendered select option. The lane has never been executed, so this was a latent defect rather than a regression; it is corrected here because the plan requires passing through the id `session_types.list` returns.

3. **Added one Lua action-adapter test** invoking `spawn_session_action` with values keyed by the authored form node ids, asserting the selected session type reaches the capability unchanged. Not itemized in the plan; it covers the exact node-id-to-field seam that the two downstream drivers depend on.

4. **`script/test-hub-flow` added to the cold-cut audit file list** (but not to the leak-pattern scan, which it would fail on its `@example.invalid` Git fixture address). It is an active harness that names fixture package ids, so leaving it unaudited would have permitted a surviving alias.

No plan acceptance check was weakened, and no scope was dropped. The plan's committed acceptance checks remain accurate; deviations 1–4 add or sharpen guards rather than replacing them.

## Tests and downstream proof

Provenance of the runtime used for every real-Hub result:

- Hub `botster-hub` `8a60bd58841179f8b1fd4040d9362d18ea244230`, verified clean (`git status --porcelain --untracked-files=all` empty) and an ancestor of `origin/main`. Built `--release --locked`; `sha256 322e032e0e73ca90d28d711516e24f8491228d4b5a004bf672fea10032c0c640`.
- Session worker `botster-core` `33ebcd98d19031d23e91b03d8da0ee3f8d1410d4` — the revision Hub's `Cargo.lock` pins — verified clean, built `--release --locked`; `sha256 9cdb1fd2fa6d268d4692b326ae2792f3ac75f4d496ef8f46d4b0728a8b7504e4`.

| Gate | Command | Result |
| --- | --- | --- |
| 1. Local | `./script/test` | ok (`test/plugin_runtime_test.lua: ok`, `script/test: ok`). Baseline was green at `72e2544`. |
| 1. UI contract | `BOTSTER_UI_CONTRACT_PATH=<hub>/crates/botster-ui-contract script/validate_ui_node_contract` | ok |
| 3. Published contract | clean temp npm consumer, `npm install @trybotster/hub-test-support@0.1.24` | `verifyPackageAssets() → {ok:true,failures:[]}`; `protocol botster-hub-daemon-v1`; `protocol_version 6`; `conformance_fixture_revision 31`; `required_features` includes `session_type_entity_subscriptions`; daemon protocol TypeScript has `session_types` / `session_type_id` / `resolved_session_type` and **0** `session_template` occurrences. Lock integrity `sha512-n0/DDMw5PmnFdxp54dk4Y4pdAM0VfotQblBnamqkViwbmJgmSS7ZrAFPskzOcVZ70hHgJdfHaH4UwArwP0DvXw==`, registry-resolved, no tarball or local override. |
| 4/5. Real package path and runtime truth | `BOTSTER_HUB_BIN=… BOTSTER_SESSION_WORKER_BIN=… ./script/test-hub-flow` | ok. `script/hub_acceptance_smoke: ok protocol_version=6 conformance_fixture_revision=31 target_id=workspaces-acceptance session_type_id=botster-workspaces-acceptance-session-type/workspace-acceptance session_id=d2b890ec-… spawn_action_id=botster_workspaces.open_spawn` |
| 6. Final audit | `git diff --check`; `git status --short`; scoped token sweep | No whitespace errors; clean tree after commit; every surviving match is a frozen `OBSOLETE_FIELDS` key, a marked negative control, or the audit's own definition in `script/test`. |

`script/test-hub-flow` passing is the ticket's central proof, not a formality: `botster-hub packages enable botster-workspaces` succeeding on a protocol-6 Hub is only possible with the migrated scope, the effective session-type list is produced by the real worker `capabilities_table`, and the fully qualified id is selected from that list and passed through unchanged.

### Negative controls, each demonstrated red against pre-change behavior

| Ablation | Observed failure |
| --- | --- |
| Re-accept `template_id` in the spawn field allowlist | `lua test/plugin_runtime_test.lua` exit 1 at the superseded-field rejection |
| Delete `default_session_template_refs` from `OBSOLETE_FIELDS` | `lua …` exit 1; `./script/test` exit 1 on the frozen-key presence assertion |
| Restore the bare-`id` fallback in the list projection | `lua …` exit 1 — the option value is no longer the qualified Hub id |
| Reintroduce a live `session_templates` mention in `docs/capabilities.md` | `./script/test` exit 1: `docs/capabilities.md retains superseded session-template vocabulary session_templates` |
| Fixture manifest reverts to the `session_templates` key | `./script/test` exit 1: `must not declare a superseded session_templates manifest key` |
| Revert the capability scope in manifest **and** contract together | `./script/test` exit 1: `botster-package.json retains superseded session-template vocabulary session_template_` |
| **Real Hub** — restore the pre-protocol-6 compatibility block | `script/test-hub-flow` exit 1: `daemon closed before hello`. Confirms the handshake repair is on the critical path. |
| **Real Hub** — restore the legacy capability scope | `script/test-hub-flow` exit 1: `package botster-workspaces denied for enable: UngrantedCapability(Capability { surface: SessionActions, scope: Some("session_template_managed_git_spawn") })`. This is the ticket's stated root cause, reproduced and then removed. |

### Unproven at merge — by design, owned elsewhere

Neither item below is a gate on this ticket, and neither was weakened, skipped, or reported as passing. Both become runnable only after this ticket closes, because both owner tickets carry blocking dependency edges back onto it.

- **Generic-consumer profile.** `script/test-hub-flow shared-stack validate-inputs …` and `shared-stack run …`. The script is migrated by this change, but `verify_contract_provenance!` requires both clients pinned to the supplied Hub, and botster-web `origin/main` (`9753297`) pins `@trybotster/hub-test-support` 0.1.21 while botster-tui `origin/main` (`fe03a90`) pins Hub rev `e8febabf`. Unblocked by **`ticket_1786036336_442121`** and **`ticket_1786036326_597046`**.
- **botster-tui live-hub lanes.** All three `script/test-live-hub workspaces` profiles — `installed-driver`, `plumbing`, `lifecycle`. Owned by **`ticket_1786036326_597046`**. These need two independent conditions: this ticket landing so the granted scope is declared, and botster-tui repinning to protocol 6 so `ensure_compatible`'s exact protocol equality is satisfiable. A lane still failing after this merges is not automatically a Workspaces defect.

## Unverified behavior and residual risk

- The two lanes above are unverified at merge. That is intended and registered, not a silent gap.
- The `SESSION_TYPE_ID` correction in `script/shared_stack_acceptance` is reasoned from Hub source (`source_session_type_id` = `<source_name>/<id>`, repo `source_name` = `target_id`), not executed, because the shared-stack profile cannot run today.
- The smoke's `template_id` negative control asserts rejection and unchanged membership, and the Lua test additionally proves zero capability calls. The smoke does not separately assert that no Git worktree was created by the rejected request; the plugin returns before any capability call, so no Git path is reachable.
- Real-Hub evidence comes from a single macOS run per gate. No CI exists in this repository; `script/test` is the repository-owned local gate.
- The published-artifact check proves public contract bytes only. Live Hub and session-worker provenance is recorded separately above.

## Missing vault guidance discovered

1. **Superseded notes.** [[workspace session templates are hub owned capabilities callable from lua workers]] and [[session template override sources use package device repo explicit precedence]] both describe `session_templates`, `template_id`, and `spawn_session_template` as current. The real-Hub path is now proven, so a superseding note is warranted: preserve the ownership boundary while recording `session_types`, the fully qualified `session_type_id`, the required `role` / `interaction` / `lifecycle` descriptor fields, source precedence and editability, and real-worker capability proof.
2. **Stale normalization claim.** The same note still says workspace plugins "can normalize legacy `default_session_template_id` into `default_session_template_refs`". This repository cold-cut those to rejected `OBSOLETE_FIELDS` under the five-field record. Resolution is to supersede the note, not soften the reduced schema.
3. **New gotcha, now confirmed by ablation.** A Botster daemon client's `DaemonHello.compatibility` is `#[serde(default)]` at the field level but strict inside `DaemonCompatibilityRequirement`, so a *stale-but-present* block fails the handshake (`daemon closed before hello`) while omitting the block entirely succeeds. Nothing in the vault records this asymmetry, and the failure reads as a package defect rather than a client-harness defect.
4. **New convention candidate.** A cold-cut token audit needs an exact allowlist for frozen rejection vocabulary *and* an explicit marker for negative controls, because a cold cut that must prove the old token is rejected necessarily writes that token in an audited file. A bare substring audit invites deleting the very keys it should protect.
5. **New convention candidate.** When a package rename breaks first-party consumers that key on a request field name, the owner work belongs in separate tickets rather than folded into mid-flight ones — folding recreates circular dependencies. Related: a ticket that must stay open until a dependent proves something is a deadlock whenever that dependent carries a blocking edge back.
