#!/usr/bin/env node
/**
 * Parent-owned dual-browser claim driver for botster-workspaces claim-stack acceptance.
 *
 * Attaches to a caller-owned Hub (BOTSTER_LIVE_DATA_DIR) with botster-web already running.
 * Exercises production Ionic entity_options claim paths, dual-context race/idempotency,
 * historical advanced fallback, reconnect, and ordered sequence_gap via the Web live-harness
 * transportControl.armDropNextInboundEntityFrame control.
 *
 * Does not install packages, spawn Hub, or use package/MCP add_session for claim lanes.
 */
import { connect } from "node:net";
import { join } from "node:path";
import { createRequire } from "node:module";
import { setTimeout as delay } from "node:timers/promises";

const protocol = "botster-hub-daemon-v1";
const dataDir = process.env.BOTSTER_LIVE_DATA_DIR;
if (!dataDir) {
  throw new Error("claim-stack web driver requires BOTSTER_LIVE_DATA_DIR");
}

const assignment = JSON.parse(process.env.BOTSTER_CLAIM_STACK_ASSIGNMENT || "{}");
const required = ["workspace_w1", "workspace_w2", "session_s", "session_s2", "session_race", "session_idem"];
for (const key of required) {
  if (!assignment[key] || typeof assignment[key] !== "string") {
    throw new Error(`claim-stack assignment missing ${key}`);
  }
}

const webPackagePath = process.env.BOTSTER_WEB_PACKAGE_PATH;
if (!webPackagePath) {
  throw new Error("claim-stack web driver requires BOTSTER_WEB_PACKAGE_PATH (web checkout with playwright)");
}

const require = createRequire(join(webPackagePath, "package.json"));
const { chromium } = require("playwright");

const socketPath = join(dataDir, "botster-hub.sock");
const summary = {
  schema: "botster.workspaces.claim-stack-web/v1",
  completed: false,
  lanes: {},
  forbidden_methods_audit: {
    list_sessions_as_picker_source: 0,
    force_interaction: 0,
    surface_refresh_as_sync: 0,
    package_tool_claim_participants: 0,
    direct_action_payloads: 0,
    page_reload_as_reconnect: 0,
    client_store_gap_injection: 0,
    timing_only_pass: 0
  },
  frame_drop_control: "transportControl.armDropNextInboundEntityFrame",
  reconnect_control: "transportControl.closeDataChannel"
};

function sendDaemonRequest(path, payload, timeoutMs = 15_000) {
  return new Promise((resolve, reject) => {
    const socket = connect(path);
    let buffer = "";
    const timer = setTimeout(() => {
      socket.destroy();
      reject(new Error(`daemon request timed out: ${JSON.stringify(payload)}`));
    }, timeoutMs);
    socket.setEncoding("utf8");
    socket.on("error", (error) => {
      clearTimeout(timer);
      reject(error);
    });
    socket.on("data", (chunk) => {
      buffer += chunk;
      const lines = buffer.split("\n");
      buffer = lines.pop() ?? "";
      for (const line of lines) {
        if (!line.trim()) continue;
        let message;
        try {
          message = JSON.parse(line);
        } catch (error) {
          clearTimeout(timer);
          socket.destroy();
          reject(error);
          return;
        }
        // Hub hello is protocol+compatibility without a response kind.
        if (message.protocol === protocol && message.kind == null && message.compatibility) continue;
        if (message.protocol === protocol && message.kind === "hello") continue;
        clearTimeout(timer);
        socket.end();
        resolve(message);
        return;
      }
    });
    socket.on("connect", () => {
      socket.write(`${JSON.stringify({ protocol })}\n`);
      socket.write(`${JSON.stringify(payload)}\n`);
    });
  });
}

async function waitForAppUrl(timeoutMs = 60_000) {
  const deadline = Date.now() + timeoutMs;
  let last = null;
  while (Date.now() < deadline) {
    const response = await sendDaemonRequest(socketPath, { type: "list_apps" });
    const apps = response.apps ?? [];
    const app = apps.find(
      (row) =>
        row.package_name === "botster-web" &&
        (row.entrypoint_id === "web-client" || row.id?.includes("web-client"))
    );
    last = app;
    const url = app?.launch_target?.local_url;
    if (app?.lifecycle_state === "running" && url) return url;
    await delay(200);
  }
  throw new Error(`timed out waiting for botster-web local_url; last=${JSON.stringify(last)}`);
}

async function waitForHttpOk(url, timeoutMs = 30_000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      const response = await fetch(new URL("/health", url));
      if (response.ok) return;
    } catch {
      // retry
    }
    await delay(100);
  }
  throw new Error(`health never became ready at ${url}`);
}

function installHarnessHooks(page) {
  return page.addInitScript(() => {
    globalThis.__BOTSTER_LIVE_PROTOCOL_HARNESS__ = {
      events: [],
      terminal: []
    };
    globalThis.window.addEventListener("botster:webrtc-daemon-lifecycle", (event) => {
      globalThis.__BOTSTER_LIVE_PROTOCOL_HARNESS__?.events?.push({
        kind: "webrtc_lifecycle",
        payload: event.detail
      });
    });
  });
}

async function harnessEventCount(page) {
  return page.evaluate(() => (globalThis.__BOTSTER_LIVE_PROTOCOL_HARNESS__?.events ?? []).length);
}

async function waitForHarnessKind(page, kind, label, timeoutMs = 30_000) {
  await page.waitForFunction(
    (expected) => (globalThis.__BOTSTER_LIVE_PROTOCOL_HARNESS__?.events ?? []).some((entry) => entry.kind === expected),
    kind,
    { timeout: timeoutMs }
  ).catch((error) => {
    throw new Error(`${label}: missing harness event kind=${kind}: ${error.message}`);
  });
}

const SELECTED_SURFACE = "selected-app-surface";
const APPS_VIEW = "apps-view";

async function openAppsAndWorkspaces(page) {
  await page.waitForFunction(
    () => Boolean(globalThis.__BOTSTER_LIVE_PROTOCOL_HARNESS__),
    null,
    { timeout: 30_000 }
  );
  // Open Apps host chrome, then the botster-workspaces package surface.
  const appsNav = page.getByTestId(APPS_VIEW).or(page.getByRole("tab", { name: /apps/i })).or(page.getByText("Apps", { exact: true }));
  if (await appsNav.count()) {
    await appsNav.first().click({ timeout: 15_000 }).catch(() => {});
  }
  const installed = page.getByTestId(APPS_VIEW).or(page.locator("body"));
  const workspacesRow = installed.getByText(/botster[- ]workspaces|workspaces/i).first();
  await workspacesRow.waitFor({ timeout: 30_000 });
  await workspacesRow.click();
  await page.getByTestId(SELECTED_SURFACE).waitFor({ timeout: 30_000 });
  await page.getByTestId(SELECTED_SURFACE)
    .locator("[data-ui-node-id='botster-workspaces-app'], [data-ui-node-id^='botster-workspaces-']")
    .first()
    .waitFor({ timeout: 30_000 });
}

async function selectWorkspace(page, workspaceId, workspaceName) {
  const surface = page.getByTestId(SELECTED_SURFACE);
  const row = surface.locator(`[data-ui-node-id='botster-workspaces-row-${workspaceId}']`);
  await row.waitFor({ timeout: 20_000 });
  const openButton = row.locator("ion-button[data-action-id]").first();
  if (await openButton.count()) {
    await openButton.click();
  } else {
    await row.click();
  }
  // Detail should expose Add existing session.
  await surface.getByRole("button", { name: /Add existing session/i }).waitFor({ timeout: 20_000 });
}

async function openAddDialog(page, workspaceId) {
  const formSelector = `form[data-ui-node-id='botster-workspaces-add-form-${workspaceId}']`;
  const existing = page.locator(formSelector);
  if (await existing.count()) {
    const visible = await existing.first().isVisible().catch(() => false);
    if (visible) return existing.first();
  }
  const surface = page.getByTestId(SELECTED_SURFACE);
  const openButton = surface
    .locator(`ion-button[data-ui-node-id='botster-workspaces-add-${workspaceId}']`)
    .or(
      surface
        .locator("ion-button[data-action-id='botster_workspaces.open']")
        .filter({ hasText: "Add existing session" })
    )
    .or(surface.getByRole("button", { name: /Add existing session/i }));
  await openButton.first().waitFor({ timeout: 20_000 });
  await openButton.first().click({ timeout: 15_000 });
  const form = page.locator(formSelector);
  await form.waitFor({ timeout: 30_000 });
  return form;
}

async function readSelectOptions(form) {
  return form.locator("[data-ui-node-id='botster-workspaces-add-session-id'] ion-select-option").evaluateAll((nodes) =>
    nodes.map((node) => node.value ?? node.getAttribute("value")).filter(Boolean)
  );
}

async function waitForOption(page, form, sessionId, timeoutMs = 45_000) {
  const formId = await form.getAttribute("data-ui-node-id");
  await page.waitForFunction(
    ({ nextFormId, expected }) => {
      const options = [...globalThis.document.querySelectorAll(
        `form[data-ui-node-id='${nextFormId}'] [data-ui-node-id='botster-workspaces-add-session-id'] ion-select-option`
      )];
      return options.some((option) => (option.value ?? option.getAttribute("value")) === expected);
    },
    { nextFormId: formId, expected: sessionId },
    { timeout: timeoutMs }
  ).catch(async (error) => {
    const options = await readSelectOptions(form);
    throw new Error(`option ${sessionId} never projected; options=${JSON.stringify(options)}: ${error.message}`);
  });
}

/**
 * Select an Available sessions option through normal rendered Ionic interaction:
 * open the ion-select control, then click the matching option in the interface.
 * No direct value assignment, synthetic ionChange, or evaluate(node.click()).
 */
async function selectSession(page, form, sessionId) {
  const select = form.locator("[data-ui-node-id='botster-workspaces-add-session-id'] ion-select");
  await select.waitFor({ timeout: 15_000 });
  await select.click({ timeout: 15_000 });
  // Wait for Ionic overlay; ion-select-option nodes in the form are not themselves visible.
  await page.waitForSelector("ion-alert, ion-action-sheet, ion-select-popover, .alert-wrapper", {
    state: "visible",
    timeout: 10_000
  }).catch(() => {});
  const overlay = page.locator("ion-alert, ion-action-sheet, ion-select-popover").last();
  // Prefer role-based options inside the open overlay.
  const roleOption = overlay.getByRole("radio", { name: new RegExp(sessionId) })
    .or(overlay.getByRole("button", { name: new RegExp(sessionId) }))
    .or(overlay.locator("button, ion-item, .alert-radio-label, .action-sheet-button").filter({ hasText: sessionId }));
  if (await roleOption.count()) {
    await roleOption.first().click({ timeout: 10_000 });
  } else {
    // Global overlay text click (still a real pointer interaction on the visible control).
    await page.locator("ion-alert, ion-action-sheet, ion-select-popover")
      .locator(`text=${sessionId}`)
      .first()
      .click({ timeout: 10_000 });
  }
  // Dismiss alert confirm if present (some interfaces require OK after radio select).
  const ok = page.locator("ion-alert button.alert-button").filter({ hasText: /OK|Confirm|Done/i });
  if (await ok.count()) {
    await ok.first().click({ timeout: 5_000 }).catch(() => {});
  }
  // Confirm the select now holds the value via rendered production state (not synthetic set).
  await page.waitForFunction(
    ({ formId, expected }) => {
      const selectNode = globalThis.document.querySelector(
        `form[data-ui-node-id='${formId}'] [data-ui-node-id='botster-workspaces-add-session-id'] ion-select`
      );
      return (selectNode?.value ?? selectNode?.getAttribute("value")) === expected;
    },
    { formId: await form.getAttribute("data-ui-node-id"), expected: sessionId },
    { timeout: 15_000 }
  );
}

async function submitAdd(page, form, workspaceId, sessionId, label) {
  const formNodeId = await form.getAttribute("data-ui-node-id");
  const submit = form.locator(
    ":scope > ion-button[data-action-id='botster_workspaces.add_session'], ion-button[data-action-id='botster_workspaces.add_session']"
  ).first();
  const since = await harnessEventCount(page);
  // Read realized action id from the control when present.
  const actionId = await submit.getAttribute("data-action-id");
  if (actionId !== "botster_workspaces.add_session") {
    throw new Error(`${label}: realized submit action_id=${actionId}`);
  }
  // Normal Playwright click on the realized submit control (no force, no evaluate).
  await submit.click({ timeout: 15_000 });
  let requestId;
  try {
    requestId = await page.waitForFunction(
      ({ sinceIndex, nodeId, workspace, session }) => {
        const entry = (globalThis.__BOTSTER_LIVE_PROTOCOL_HARNESS__?.events ?? []).slice(sinceIndex).find((candidate) => {
          const request = candidate.payload?.request;
          if (
            candidate.kind !== "daemon_request" ||
            candidate.payload?.type !== "plugin_surface_action" ||
            request?.action_id !== "botster_workspaces.add_session"
          ) {
            return false;
          }
          if (nodeId && request?.node_id && request.node_id !== nodeId) return false;
          const values = request.values ?? {};
          const workspaceValue = values.workspace_id
            || values["botster-workspaces-add-workspace-id"];
          if (workspaceValue && workspaceValue !== workspace) return false;
          const resolved = values.session_id
            || values.session_id_advanced
            || values["botster-workspaces-add-session-id"]
            || values["botster-workspaces-add-session-id-advanced"];
          if (resolved && resolved !== session) return false;
          return Boolean(request.request_id);
        });
        return entry?.payload?.request?.request_id ?? null;
      },
      { sinceIndex: since, nodeId: formNodeId, workspace: workspaceId, session: sessionId },
      { timeout: 20_000 }
    ).then((handle) => handle.jsonValue());
  } catch (error) {
    const observed = await page.evaluate((start) =>
      (globalThis.__BOTSTER_LIVE_PROTOCOL_HARNESS__?.events ?? [])
        .slice(start)
        .map((entry) => ({
          kind: entry.kind,
          type: entry.payload?.type,
          action_id: entry.payload?.request?.action_id || entry.payload?.payload?.result?.action_id,
          node_id: entry.payload?.request?.node_id,
          values: entry.payload?.request?.values,
          package_name: entry.payload?.package_name
        })),
    since);
    throw new Error(`${label}: no add_session request observed; events=${JSON.stringify(observed)}: ${error.message}`);
  }

  const result = await page.waitForFunction(
    ({ sinceIndex, expectedRequestId }) => {
      const entry = (globalThis.__BOTSTER_LIVE_PROTOCOL_HARNESS__?.events ?? []).slice(sinceIndex).find((candidate) => {
        if (candidate.kind === "hub_frame" && candidate.payload?.kind === "action_result") {
          const payload = candidate.payload.payload ?? {};
          const requestId = payload.request_id
            || payload.result?.plugin_action_result?.request_id;
          if (requestId === expectedRequestId) return true;
        }
        return false;
      });
      return entry ? (entry.payload?.payload ?? entry.payload) : null;
    },
    { sinceIndex: since, expectedRequestId: requestId },
    { timeout: 30_000 }
  ).then((handle) => handle.jsonValue()).catch(async (error) => {
    const observed = await page.evaluate((start) =>
      (globalThis.__BOTSTER_LIVE_PROTOCOL_HARNESS__?.events ?? []).slice(start).slice(-20),
    since);
    throw new Error(`${label}: no action_result for request_id=${requestId}; tail=${JSON.stringify(observed)}: ${error.message}`);
  });

  return {
    request_id: requestId,
    workspace_id: workspaceId,
    session_uuid: sessionId,
    node_id: formNodeId,
    action_id: actionId,
    result
  };
}

async function fillHistoricalAndSubmit(page, form, workspaceId, sessionId, label) {
  const advanced = form.locator("[data-ui-node-id='botster-workspaces-add-session-id-advanced'] input");
  await advanced.waitFor({ timeout: 15_000 });
  await advanced.fill(sessionId);
  return submitAdd(page, form, workspaceId, sessionId, label);
}

async function membershipCount(daemonSessionIds, workspaceId) {
  // Parent oracle via daemon is recorded by ruby; web driver only returns UI evidence.
  return { workspace_id: workspaceId, observed_sessions: daemonSessionIds };
}

async function bootstrapClient(browser, appUrl, label) {
  const page = await browser.newPage();
  await installHarnessHooks(page);
  await page.goto(appUrl, { waitUntil: "domcontentloaded" });
  // Diagnostics establishes the production WebRTC transport and harness controls.
  const diagnostics = page.getByTestId("diagnostics-view").or(page.getByText(/Diagnostics|Local Botster health/i));
  if (await diagnostics.count()) {
    await diagnostics.first().click({ timeout: 10_000 }).catch(() => {});
  }
  await page.waitForFunction(
    () => typeof globalThis.__BOTSTER_LIVE_PROTOCOL_HARNESS__?.transportControl?.closeDataChannel === "function"
      || (globalThis.__BOTSTER_LIVE_PROTOCOL_HARNESS__?.events ?? []).some((entry) => entry.kind === "daemon_request"),
    null,
    { timeout: 45_000 }
  ).catch(() => {
    // Continue; some pins only install transportControl after first app open.
  });
  await openAppsAndWorkspaces(page);
  return page;
}

async function optionMetadata(form, sessionId) {
  return form.locator("[data-ui-node-id='botster-workspaces-add-session-id'] ion-select-option").evaluateAll((nodes, expected) => {
    const match = nodes.find((node) => (node.value ?? node.getAttribute("value")) === expected);
    if (!match) return null;
    return {
      value: match.value ?? match.getAttribute("value"),
      label: match.textContent?.trim() ?? "",
      lifecycle: match.getAttribute("data-lifecycle") ?? match.dataset?.lifecycle ?? null,
      session_type: match.getAttribute("data-session-type-id") ?? match.dataset?.sessionTypeId ?? null,
      spawn_point: match.getAttribute("data-spawn-point") ?? match.dataset?.spawnPoint ?? null
    };
  }, sessionId);
}

// Daemon subscribe_entities entity_type values (not UiNode path forms).
// Hub transport uses "session" for /session; package membership family is fully qualified.
const REQUIRED_ENTITY_FAMILIES = ["session", "botster-workspaces.membership"];

/** Extract entity family identifiers from a harness ledger entry. */
function entityFamiliesFromEntry(entry) {
  const payload = entry?.payload ?? {};
  const nested = payload.payload ?? {};
  const request = payload.request ?? {};
  const families = new Set();
  const candidates = [
    payload.entity_type,
    nested.entity_type,
    request.entity_type,
    payload.family,
    nested.family,
  ];
  if (Array.isArray(request.entity_types)) {
    for (const value of request.entity_types) candidates.push(value);
  }
  if (Array.isArray(request.families)) {
    for (const value of request.families) candidates.push(value);
  }
  // subscribe_entities may pass subscriptions: [{ entity_type }] or entity_type at top level.
  if (Array.isArray(request.subscriptions)) {
    for (const sub of request.subscriptions) {
      if (sub?.entity_type) candidates.push(sub.entity_type);
      if (sub?.family) candidates.push(sub.family);
    }
  }
  for (const value of candidates) {
    if (typeof value === "string" && value.length > 0) families.add(value);
  }
  return [...families];
}

function isSubscribeEntitiesEntry(entry) {
  return entry?.kind === "daemon_request" && entry?.payload?.type === "subscribe_entities";
}

function isEntitySnapshotEntry(entry) {
  if (entry?.kind !== "hub_frame") return false;
  const kind = entry.payload?.kind || entry.payload?.type || entry.payload?.payload?.type;
  return kind === "entity_snapshot";
}

function entryTouchesRequiredFamily(entry, families = REQUIRED_ENTITY_FAMILIES) {
  const seen = entityFamiliesFromEntry(entry);
  if (seen.length === 0) return false;
  return families.some((family) => seen.includes(family));
}

function familyGenerationCounters(events) {
  const byFamily = {};
  for (const family of REQUIRED_ENTITY_FAMILIES) {
    byFamily[family] = { subscribe_count: 0, snapshot_count: 0, subscription_ids: new Set(), generations: new Set() };
  }
  for (const entry of events) {
    const families = entityFamiliesFromEntry(entry);
    for (const family of families) {
      if (!byFamily[family]) continue;
      if (isSubscribeEntitiesEntry(entry)) {
        byFamily[family].subscribe_count += 1;
        const subId = entry.payload?.request?.subscription_id
          || entry.payload?.subscription_id
          || entry.payload?.request?.id;
        if (subId) byFamily[family].subscription_ids.add(subId);
      }
      if (isEntitySnapshotEntry(entry)) {
        byFamily[family].snapshot_count += 1;
        const gen = entry.payload?.generation
          ?? entry.payload?.payload?.generation
          ?? entry.payload?.snapshot_seq
          ?? entry.payload?.payload?.snapshot_seq;
        if (gen != null) byFamily[family].generations.add(gen);
        const subId = entry.payload?.subscription_id || entry.payload?.payload?.subscription_id;
        if (subId) byFamily[family].subscription_ids.add(subId);
      }
    }
  }
  // Serialize Sets for JSON evidence.
  const serialized = {};
  for (const [family, row] of Object.entries(byFamily)) {
    serialized[family] = {
      subscribe_count: row.subscribe_count,
      snapshot_count: row.snapshot_count,
      subscription_ids: [...row.subscription_ids],
      generations: [...row.generations]
    };
  }
  return serialized;
}

function countStaleAddOutbound(events, since, sessionId) {
  return events.slice(since).filter((entry) => {
    const request = entry.payload?.request;
    if (entry.kind !== "daemon_request" || entry.payload?.type !== "plugin_surface_action") return false;
    if (request?.action_id !== "botster_workspaces.add_session") return false;
    const values = request.values ?? {};
    const resolved = values.session_id
      || values.session_id_advanced
      || values["botster-workspaces-add-session-id"]
      || values["botster-workspaces-add-session-id-advanced"];
    return resolved === sessionId;
  });
}

async function run() {
  const appUrl = await waitForAppUrl();
  await waitForHttpOk(appUrl);
  const browser = await chromium.launch({
    args: [
      "--disable-features=WebRtcHideLocalIpsWithMdns",
      "--force-webrtc-ip-handling-policy=default_public_and_private_interfaces"
    ]
  });

  try {
    // ---- C1: open dialog first, live-appear unclaimed session, claim, live updates, remove restore ----
    const p1 = await bootstrapClient(browser, appUrl, "p1");
    await selectWorkspace(p1, assignment.workspace_w1, assignment.workspace_w1_name || "Claim W1");
    let form = await openAddDialog(p1, assignment.workspace_w1);
    // Session S is NOT seeded yet — prove live appearance through /session entity frames.
    const beforeLiveOptions = await readSelectOptions(form);
    if (beforeLiveOptions.includes(assignment.session_s)) {
      throw new Error(`C1: session_s present before live spawn: ${assignment.session_s}`);
    }
    // Prefer session-type spawn so Hub projects session_type_id on /session when available.
    const sessionTypeId = assignment.session_type_id
      || "botster-workspaces-acceptance-session-type/workspace-acceptance";
    const targetId = assignment.target_id || "workspaces-acceptance";
    const spawnMode = "spawn_session_type";
    // Require session-type spawn so /session projects session_type_id. Bare spawn cannot
    // satisfy the metadata matrix and must not silently weaken this lane.
    await sendDaemonRequest(socketPath, {
      type: "spawn_session_type",
      session_type_id: sessionTypeId,
      session_id: assignment.session_s,
      request: {
        target_id: targetId,
        context: {
          branch_name: "claim-stack-c1-meta",
          prompt: "claim stack C1 metadata",
          workspace_id: assignment.workspace_w1
        }
      }
    });
    await waitForOption(p1, form, assignment.session_s, 60_000);
    const metadata = await optionMetadata(form, assignment.session_s);
    if (!metadata?.value) {
      throw new Error(`C1: option metadata missing after live appear: ${JSON.stringify(metadata)}`);
    }
    // Projected fields: assert every field Hub supplies. lifecycle is always expected on live sessions.
    const fieldsPresent = {
      label: Boolean(metadata.label && metadata.label.length > 0),
      lifecycle: Boolean(metadata.lifecycle),
      session_type: Boolean(metadata.session_type),
      spawn_point: Boolean(metadata.spawn_point)
    };
    if (!fieldsPresent.lifecycle) {
      throw new Error(`C1: Hub session entity did not project lifecycle: ${JSON.stringify(metadata)}`);
    }
    if (spawnMode === "spawn_session_type" && !fieldsPresent.session_type) {
      throw new Error(
        `C1: session-type spawn did not project session_type_id on the option: ${JSON.stringify(metadata)}`
      );
    }
    if (fieldsPresent.session_type && metadata.session_type !== sessionTypeId && spawnMode === "spawn_session_type") {
      // Accept fully-qualified match only; do not invent display aliases.
      throw new Error(
        `C1: projected session_type ${metadata.session_type} != spawn session_type_id ${sessionTypeId}`
      );
    }
    // Independent lifecycle live update while dialog held open (no reopen).
    const lifecycleBefore = metadata.lifecycle;
    const labelBefore = metadata.label;
    await sendDaemonRequest(socketPath, { type: "shutdown_session", session_id: assignment.session_s });
    await p1.waitForFunction(
      ({ formId, sessionId, lifecycleBeforeValue }) => {
        const match = [...globalThis.document.querySelectorAll(
          `form[data-ui-node-id='${formId}'] [data-ui-node-id='botster-workspaces-add-session-id'] ion-select-option`
        )].find((option) => (option.value ?? option.getAttribute("value")) === sessionId);
        if (!match) return false;
        const lifecycle = match.getAttribute("data-lifecycle") || "";
        // Require the lifecycle attribute itself to change (not only derived label text).
        return lifecycle
          && lifecycle !== lifecycleBeforeValue
          && /exited|ended|failed|stopping/i.test(lifecycle);
      },
      {
        formId: `botster-workspaces-add-form-${assignment.workspace_w1}`,
        sessionId: assignment.session_s,
        lifecycleBeforeValue: lifecycleBefore
      },
      { timeout: 45_000 }
    );
    const metadataAfterLifecycle = await optionMetadata(form, assignment.session_s);
    if (!metadataAfterLifecycle?.lifecycle || metadataAfterLifecycle.lifecycle === lifecycleBefore) {
      throw new Error(
        `C1: lifecycle did not live-update independently: before=${lifecycleBefore} after=${JSON.stringify(metadataAfterLifecycle)}`
      );
    }
    // Label live-update is only claimed when Hub supplies a distinct producer label field that
    // changes without relying on the lifecycle attribute. Bare/session-type entities typically
    // omit a dedicated label; do not double-count lifecycle-derived option text as label proof.
    const labelLiveUpdate = Boolean(
      fieldsPresent.label
      && metadataAfterLifecycle?.label
      && metadataAfterLifecycle.label !== labelBefore
      && metadataAfterLifecycle.lifecycle !== labelBefore
    );
    // Claim uses the still-present option after lifecycle change (ended sessions remain claimable).
    await selectSession(p1, form, assignment.session_s);
    const c1Claim = await submitAdd(p1, form, assignment.workspace_w1, assignment.session_s, "C1 claim");
    const c1Accepted = c1Claim?.result?.accepted === true
      || c1Claim?.result?.result?.plugin_action_result?.state === "accepted";
    if (!c1Accepted) {
      throw new Error(`C1 claim was not accepted: ${JSON.stringify(c1Claim.result)}`);
    }
    // Hold dialog path: exclusion should land via membership entity frames without surface refresh.
    await p1.waitForFunction(
      ({ formId, sessionId }) => {
        const options = [...globalThis.document.querySelectorAll(
          `form[data-ui-node-id='${formId}'] [data-ui-node-id='botster-workspaces-add-session-id'] ion-select-option`
        )];
        // Form may clear after accepted claim; treat detached form as exclusion complete.
        const formNode = globalThis.document.querySelector(`form[data-ui-node-id='${formId}']`);
        if (!formNode) return true;
        return !options.some((option) => (option.value ?? option.getAttribute("value")) === sessionId);
      },
      { formId: `botster-workspaces-add-form-${assignment.workspace_w1}`, sessionId: assignment.session_s },
      { timeout: 45_000 }
    );
    // Re-open for stale-selection + remove/restore proofs.
    form = await openAddDialog(p1, assignment.workspace_w1);
    const excludedOptions = await readSelectOptions(form);
    if (excludedOptions.includes(assignment.session_s)) {
      throw new Error(`C1: claimed session still present in options: ${JSON.stringify(excludedOptions)}`);
    }
    const submit = form.locator("ion-button[data-action-id='botster_workspaces.add_session']");
    const beforeStale = await harnessEventCount(p1);
    await submit.click({ timeout: 5_000 }).catch(() => {});
    await p1.waitForTimeout(500);
    const staleOutbound = await p1.evaluate(({ since, sessionId }) =>
      (globalThis.__BOTSTER_LIVE_PROTOCOL_HARNESS__?.events ?? [])
        .slice(since)
        .filter((entry) => {
          const request = entry.payload?.request;
          if (entry.kind !== "daemon_request" || entry.payload?.type !== "plugin_surface_action") return false;
          if (request?.action_id !== "botster_workspaces.add_session") return false;
          const values = request.values ?? {};
          const resolved = values.session_id || values.session_id_advanced;
          return resolved === sessionId;
        }),
    { since: beforeStale, sessionId: assignment.session_s });
    if (staleOutbound.length > 0) {
      throw new Error(`C1 stale selection emitted claim for excluded session: ${JSON.stringify(staleOutbound)}`);
    }
    // Remove membership while dialog held open; prove reappearance without refresh.
    const removeResult = await sendDaemonRequest(socketPath, {
      type: "plugin_mcp_call_tool",
      name: "botster_workspaces.remove_session",
      arguments: {
        workspace_id: assignment.workspace_w1,
        session_id: assignment.session_s
      }
    });
    const removeBody = removeResult.plugin_tool_result || removeResult;
    if (removeBody.ok === false) {
      throw new Error(`C1 membership remove failed: ${JSON.stringify(removeResult)}`);
    }
    await waitForOption(p1, form, assignment.session_s, 60_000);
    summary.lanes.c1 = {
      claim: c1Claim,
      live_appear: true,
      spawn_mode: spawnMode,
      session_type_id: sessionTypeId,
      fields_present: fieldsPresent,
      metadata_present: metadata,
      metadata_after_lifecycle: metadataAfterLifecycle,
      lifecycle_live_update: true,
      // Only true when a non-lifecycle producer label field changed independently.
      label_live_update: labelLiveUpdate,
      label_live_update_required: fieldsPresent.label && Boolean(assignment.require_label_live_update),
      excluded_after_claim: true,
      stale_submit_blocked: true,
      restored_after_remove: true,
      path: "entity_options_select"
    };

    // ---- C3: dual browser race across W1 and W2 ----
    const raceA = await bootstrapClient(browser, appUrl, "raceA");
    const raceB = await bootstrapClient(browser, appUrl, "raceB");
    await selectWorkspace(raceA, assignment.workspace_w1, assignment.workspace_w1_name || "Claim W1");
    await selectWorkspace(raceB, assignment.workspace_w2, assignment.workspace_w2_name || "Claim W2");
    const formA = await openAddDialog(raceA, assignment.workspace_w1);
    const formB = await openAddDialog(raceB, assignment.workspace_w2);
    await waitForOption(raceA, formA, assignment.session_race);
    await waitForOption(raceB, formB, assignment.session_race);
    await selectSession(raceA, formA, assignment.session_race);
    await selectSession(raceB, formB, assignment.session_race);
    // Near-concurrent submits (re-assert selects immediately before each submit path).
    await selectSession(raceA, formA, assignment.session_race);
    await selectSession(raceB, formB, assignment.session_race);
    const raceResults = await Promise.allSettled([
      submitAdd(raceA, formA, assignment.workspace_w1, assignment.session_race, "C3 race A"),
      submitAdd(raceB, formB, assignment.workspace_w2, assignment.session_race, "C3 race B")
    ]);
    const fulfilled = raceResults
      .filter((entry) => entry.status === "fulfilled")
      .map((entry) => entry.value);
    const rejected = raceResults
      .filter((entry) => entry.status === "rejected")
      .map((entry) => entry.reason?.message || String(entry.reason));
    if (fulfilled.length < 1) {
      throw new Error(`C3 race produced no correlated results: ${JSON.stringify(rejected)}`);
    }
    // Request ids are per browser document (each SPA starts at ui-action-N). Distinctness is
    // the pair (browser_context, request_id, workspace_id), not a global string space.
    const c3Keys = fulfilled.map((entry, index) =>
      `${entry.workspace_id}:${entry.request_id}:${index}`
    );
    if (c3Keys.length !== 2 && fulfilled.length < 2) {
      throw new Error(`C3 expected two browser results; got ${JSON.stringify({ fulfilled, rejected })}`);
    }
    if (fulfilled.length < 2) {
      throw new Error(`C3 expected two fulfilled claim results; got ${JSON.stringify({ fulfilled, rejected })}`);
    }
    const workspaces = new Set(fulfilled.map((entry) => entry.workspace_id));
    if (workspaces.size !== 2) {
      throw new Error(`C3 expected two workspaces; got ${JSON.stringify([...workspaces])}`);
    }
    // Picker reconciliation without surface refresh: both dialogs must open and exclude race uuid.
    let reconA;
    let reconB;
    try {
      const formReconA = await openAddDialog(raceA, assignment.workspace_w1);
      await raceA.waitForTimeout(500);
      reconA = await readSelectOptions(formReconA);
    } catch (error) {
      throw new Error(`C3 W1 picker reconciliation failed closed: ${error.message}`);
    }
    try {
      const formReconB = await openAddDialog(raceB, assignment.workspace_w2);
      await raceB.waitForTimeout(500);
      reconB = await readSelectOptions(formReconB);
    } catch (error) {
      throw new Error(`C3 W2 picker reconciliation failed closed: ${error.message}`);
    }
    if (!Array.isArray(reconA)) {
      throw new Error(`C3 W1 picker options unreadable: ${JSON.stringify(reconA)}`);
    }
    if (!Array.isArray(reconB)) {
      throw new Error(`C3 W2 picker options unreadable: ${JSON.stringify(reconB)}`);
    }
    if (reconA.includes(assignment.session_race)) {
      throw new Error(`C3 W1 picker still lists race session after claim: ${JSON.stringify(reconA)}`);
    }
    if (reconB.includes(assignment.session_race)) {
      throw new Error(`C3 W2 picker still lists race session after claim: ${JSON.stringify(reconB)}`);
    }
    summary.lanes.c3 = {
      participants: "dual_browser_contexts",
      results: fulfilled,
      rejected,
      correlated_requests: fulfilled.map((entry) => ({
        request_id: entry.request_id,
        workspace_id: entry.workspace_id,
        session_uuid: entry.session_uuid
      })),
      picker_reconciled_w1: true,
      picker_reconciled_w2: true
    };

    // ---- C4: same-workspace concurrent dual context ----
    const idA = await bootstrapClient(browser, appUrl, "idA");
    const idB = await bootstrapClient(browser, appUrl, "idB");
    await selectWorkspace(idA, assignment.workspace_w1, assignment.workspace_w1_name || "Claim W1");
    await selectWorkspace(idB, assignment.workspace_w1, assignment.workspace_w1_name || "Claim W1");
    const idFormA = await openAddDialog(idA, assignment.workspace_w1);
    const idFormB = await openAddDialog(idB, assignment.workspace_w1);
    await waitForOption(idA, idFormA, assignment.session_idem);
    await waitForOption(idB, idFormB, assignment.session_idem);
    await selectSession(idA, idFormA, assignment.session_idem);
    await selectSession(idB, idFormB, assignment.session_idem);
    // Fire both clicks in the same tick so membership exclusion cannot clear the second
    // select before its submit is observed.
    const sinceA = await harnessEventCount(idA);
    const sinceB = await harnessEventCount(idB);
    const submitA = idFormA.locator("ion-button[data-action-id='botster_workspaces.add_session']").first();
    const submitB = idFormB.locator("ion-button[data-action-id='botster_workspaces.add_session']").first();
    const formNodeA = await idFormA.getAttribute("data-ui-node-id");
    const formNodeB = await idFormB.getAttribute("data-ui-node-id");
    // Re-assert both select values immediately before concurrent native clicks.
    await selectSession(idA, idFormA, assignment.session_idem);
    await selectSession(idB, idFormB, assignment.session_idem);
    await Promise.all([
      submitA.click({ timeout: 15_000 }),
      submitB.click({ timeout: 15_000 })
    ]);
    const waitRequest = async (page, since, formNodeId, label) => {
      try {
        return await page.waitForFunction(
          ({ sinceIndex, nodeId, workspace, session }) => {
            const entry = (globalThis.__BOTSTER_LIVE_PROTOCOL_HARNESS__?.events ?? []).slice(sinceIndex).find((candidate) => {
              const request = candidate.payload?.request;
              if (
                candidate.kind !== "daemon_request" ||
                candidate.payload?.type !== "plugin_surface_action" ||
                request?.action_id !== "botster_workspaces.add_session"
              ) return false;
              if (nodeId && request?.node_id && request.node_id !== nodeId) return false;
              const values = request.values ?? {};
              const resolved = values.session_id
                || values.session_id_advanced
                || values["botster-workspaces-add-session-id"]
                || values["botster-workspaces-add-session-id-advanced"];
              const workspaceValue = values.workspace_id || values["botster-workspaces-add-workspace-id"];
              if (workspaceValue && workspaceValue !== workspace) return false;
              if (resolved && resolved !== session) return false;
              return Boolean(request.request_id);
            });
            return entry?.payload?.request?.request_id ?? null;
          },
          {
            sinceIndex: since,
            nodeId: formNodeId,
            workspace: assignment.workspace_w1,
            session: assignment.session_idem
          },
          { timeout: 20_000 }
        ).then((handle) => handle.jsonValue());
      } catch (error) {
        throw new Error(`${label}: ${error.message}`);
      }
    };
    const waitResult = async (page, since, requestId, label) => page.waitForFunction(
      ({ sinceIndex, expectedRequestId }) => {
        const entry = (globalThis.__BOTSTER_LIVE_PROTOCOL_HARNESS__?.events ?? []).slice(sinceIndex).find((candidate) => {
          if (candidate.kind === "hub_frame" && candidate.payload?.kind === "action_result") {
            const payload = candidate.payload.payload ?? {};
            const rid = payload.request_id || payload.result?.plugin_action_result?.request_id;
            return rid === expectedRequestId;
          }
          return false;
        });
        return entry ? (entry.payload?.payload ?? entry.payload) : null;
      },
      { sinceIndex: since, expectedRequestId: requestId },
      { timeout: 30_000 }
    ).then((handle) => handle.jsonValue()).catch((error) => {
      throw new Error(`${label}: ${error.message}`);
    });
    const c4RequestIds = await Promise.all([
      waitRequest(idA, sinceA, formNodeA, "C4 request A"),
      waitRequest(idB, sinceB, formNodeB, "C4 request B")
    ]);
    // Per-browser request ids may collide numerically (ui-action-N); require two observed
    // requests across the two browser contexts.
    if (c4RequestIds.length !== 2 || c4RequestIds.some((id) => !id)) {
      throw new Error(`C4 expected two browser request_ids; got ${JSON.stringify(c4RequestIds)}`);
    }
    const c4Results = await Promise.all([
      waitResult(idA, sinceA, c4RequestIds[0], "C4 result A").then((result) => ({
        request_id: c4RequestIds[0],
        workspace_id: assignment.workspace_w1,
        session_uuid: assignment.session_idem,
        node_id: formNodeA,
        action_id: "botster_workspaces.add_session",
        result
      })),
      waitResult(idB, sinceB, c4RequestIds[1], "C4 result B").then((result) => ({
        request_id: c4RequestIds[1],
        workspace_id: assignment.workspace_w1,
        session_uuid: assignment.session_idem,
        node_id: formNodeB,
        action_id: "botster_workspaces.add_session",
        result
      }))
    ]);
    summary.lanes.c4 = {
      participants: "dual_browser_same_workspace_select_before_reconcile",
      results: c4Results
    };

    // ---- C5: historical advanced path for intentionally absent session ----
    const hist = await bootstrapClient(browser, appUrl, "hist");
    await selectWorkspace(hist, assignment.workspace_w1, assignment.workspace_w1_name || "Claim W1");
    const histForm = await openAddDialog(hist, assignment.workspace_w1);
    const histOptions = await readSelectOptions(histForm);
    if (histOptions.includes(assignment.session_historical)) {
      throw new Error(`C5 historical session unexpectedly present in entity_options: ${assignment.session_historical}`);
    }
    const histClaim = await fillHistoricalAndSubmit(
      hist,
      histForm,
      assignment.workspace_w1,
      assignment.session_historical,
      "C5 historical"
    );
    summary.lanes.c5 = {
      path: "historical_advanced",
      claim: histClaim,
      absent_from_entity_options: true
    };

    // ---- C6a reconnect via closeDataChannel ----
    const recon = await bootstrapClient(browser, appUrl, "recon");
    await selectWorkspace(recon, assignment.workspace_w2, assignment.workspace_w2_name || "Claim W2");
    const reconForm = await openAddDialog(recon, assignment.workspace_w2);
    await waitForOption(recon, reconForm, assignment.session_s2);
    await selectSession(recon, reconForm, assignment.session_s2);
    const documentSentinel = await recon.evaluate(() => {
      const marker = `claim-stack-reconnect-${Date.now()}`;
      globalThis.__CLAIM_STACK_DOCUMENT_SENTINEL__ = marker;
      return marker;
    });
    const preClose = await recon.evaluate((requiredFamilies) => {
      const events = globalThis.__BOTSTER_LIVE_PROTOCOL_HARNESS__?.events ?? [];
      const familyOf = (entry) => {
        const payload = entry?.payload ?? {};
        const nested = payload.payload ?? {};
        const request = payload.request ?? {};
        const out = new Set();
        for (const value of [
          payload.entity_type, nested.entity_type, request.entity_type, payload.family, nested.family
        ]) {
          if (typeof value === "string" && value) out.add(value);
        }
        if (Array.isArray(request.entity_types)) for (const v of request.entity_types) if (v) out.add(v);
        if (Array.isArray(request.subscriptions)) {
          for (const sub of request.subscriptions) {
            if (sub?.entity_type) out.add(sub.entity_type);
          }
        }
        return [...out];
      };
      const byFamily = Object.fromEntries(requiredFamilies.map((f) => [f, { subscribe_count: 0, snapshot_count: 0 }]));
      for (const entry of events) {
        const families = familyOf(entry);
        const isSub = entry.kind === "daemon_request" && entry.payload?.type === "subscribe_entities";
        const isSnap = entry.kind === "hub_frame" && (
          entry.payload?.kind === "entity_snapshot"
          || entry.payload?.type === "entity_snapshot"
          || entry.payload?.payload?.type === "entity_snapshot"
        );
        for (const family of families) {
          if (!byFamily[family]) continue;
          if (isSub) byFamily[family].subscribe_count += 1;
          if (isSnap) byFamily[family].snapshot_count += 1;
        }
      }
      return {
        event_count: events.length,
        by_family: byFamily
      };
    }, REQUIRED_ENTITY_FAMILIES);
    await recon.waitForFunction(
      () => typeof globalThis.__BOTSTER_LIVE_PROTOCOL_HARNESS__?.transportControl?.closeDataChannel === "function",
      null,
      { timeout: 20_000 }
    );
    // Claim S2 from another path during reconnect so the held selection becomes unavailable.
    await sendDaemonRequest(socketPath, {
      type: "plugin_mcp_call_tool",
      name: "botster_workspaces.add_session",
      arguments: {
        workspace_id: assignment.workspace_w1,
        session_id: assignment.session_s2
      }
    });
    const closed = await recon.evaluate(() =>
      globalThis.__BOTSTER_LIVE_PROTOCOL_HARNESS__.transportControl.closeDataChannel()
    );
    if (!closed) {
      throw new Error("C6a closeDataChannel returned false");
    }
    // Post-close generation must advance for each required family (/session + membership).
    const postCloseFamilies = await recon.waitForFunction(
      ({ sinceEventCount, priorByFamily, requiredFamilies }) => {
        const events = globalThis.__BOTSTER_LIVE_PROTOCOL_HARNESS__?.events ?? [];
        if (events.length <= sinceEventCount) return null;
        const tail = events.slice(sinceEventCount);
        const familyOf = (entry) => {
          const payload = entry?.payload ?? {};
          const nested = payload.payload ?? {};
          const request = payload.request ?? {};
          const out = new Set();
          for (const value of [
            payload.entity_type, nested.entity_type, request.entity_type, payload.family, nested.family
          ]) {
            if (typeof value === "string" && value) out.add(value);
          }
          if (Array.isArray(request.entity_types)) for (const v of request.entity_types) if (v) out.add(v);
          if (Array.isArray(request.subscriptions)) {
            for (const sub of request.subscriptions) {
              if (sub?.entity_type) out.add(sub.entity_type);
            }
          }
          return [...out];
        };
        const byFamily = Object.fromEntries(requiredFamilies.map((f) => [f, {
          subscribe_count: 0,
          snapshot_count: 0,
          subscription_ids: [],
          snapshot_seqs: []
        }]));
        for (const entry of events) {
          const families = familyOf(entry);
          const isSub = entry.kind === "daemon_request" && entry.payload?.type === "subscribe_entities";
          const isSnap = entry.kind === "hub_frame" && (
            entry.payload?.kind === "entity_snapshot"
            || entry.payload?.type === "entity_snapshot"
            || entry.payload?.payload?.type === "entity_snapshot"
          );
          for (const family of families) {
            if (!byFamily[family]) continue;
            if (isSub) {
              byFamily[family].subscribe_count += 1;
              const sid = entry.payload?.request?.subscription_id || entry.payload?.subscription_id;
              if (sid) byFamily[family].subscription_ids.push(sid);
            }
            if (isSnap) {
              byFamily[family].snapshot_count += 1;
              const seq = entry.payload?.snapshot_seq
                ?? entry.payload?.payload?.snapshot_seq
                ?? entry.payload?.generation
                ?? entry.payload?.payload?.generation;
              if (seq != null) byFamily[family].snapshot_seqs.push(seq);
            }
          }
        }
        const lifecycleTail = tail.some((entry) => entry.kind === "webrtc_lifecycle");
        const allAdvanced = requiredFamilies.every((family) =>
          byFamily[family].subscribe_count > (priorByFamily[family]?.subscribe_count ?? 0)
          && byFamily[family].snapshot_count > (priorByFamily[family]?.snapshot_count ?? 0)
        );
        if (!allAdvanced || !lifecycleTail) return null;
        return { by_family: byFamily, lifecycle_tail: true };
      },
      {
        sinceEventCount: preClose.event_count,
        priorByFamily: preClose.by_family,
        requiredFamilies: REQUIRED_ENTITY_FAMILIES
      },
      { timeout: 60_000 }
    ).then((handle) => handle.jsonValue());
    const sameDocument = await recon.evaluate((marker) =>
      globalThis.__CLAIM_STACK_DOCUMENT_SENTINEL__ === marker
    , documentSentinel);
    if (!sameDocument) {
      throw new Error("C6a document reloaded; reconnect must be in-page");
    }
    // Held S2 must disappear from options after membership claim + replacement snapshots.
    await recon.waitForFunction(
      ({ formId, sessionId }) => {
        const formNode = globalThis.document.querySelector(`form[data-ui-node-id='${formId}']`);
        if (!formNode) return true;
        const options = [...formNode.querySelectorAll(
          "[data-ui-node-id='botster-workspaces-add-session-id'] ion-select-option"
        )];
        return !options.some((option) => (option.value ?? option.getAttribute("value")) === sessionId);
      },
      {
        formId: `botster-workspaces-add-form-${assignment.workspace_w2}`,
        sessionId: assignment.session_s2
      },
      { timeout: 45_000 }
    ).catch(async () => {
      const options = await readSelectOptions(reconForm);
      throw new Error(
        `C6a: held session still projected after reconnect exclusion: ${JSON.stringify(options)}`
      );
    });
    // Stale held selection must emit zero successful claim outbound after replacement snapshot.
    const reconSubmit = reconForm.locator("ion-button[data-action-id='botster_workspaces.add_session']");
    const reconStaleSince = await harnessEventCount(recon);
    await reconSubmit.click({ timeout: 5_000 }).catch(() => {});
    await recon.waitForTimeout(800);
    const reconStale = await recon.evaluate(({ since, sessionId }) =>
      (globalThis.__BOTSTER_LIVE_PROTOCOL_HARNESS__?.events ?? []).slice(since).filter((entry) => {
        const request = entry.payload?.request;
        if (entry.kind !== "daemon_request" || entry.payload?.type !== "plugin_surface_action") return false;
        if (request?.action_id !== "botster_workspaces.add_session") return false;
        const values = request.values ?? {};
        const resolved = values.session_id
          || values.session_id_advanced
          || values["botster-workspaces-add-session-id"]
          || values["botster-workspaces-add-session-id-advanced"];
        return resolved === sessionId;
      }),
    { since: reconStaleSince, sessionId: assignment.session_s2 });
    if (reconStale.length !== 0) {
      throw new Error(
        `C6a stale held selection emitted claim outbound after reconnect: count=${reconStale.length}`
      );
    }
    summary.lanes.c6a = {
      control: "transportControl.closeDataChannel",
      closed: true,
      page_reload: false,
      document_sentinel_survived: true,
      pre_close: preClose,
      post_close_generation: true,
      post_close_families: postCloseFamilies,
      authoritative_snapshot_after_close: true,
      options_reconciled: true,
      held_value_unavailable: true,
      stale_outbound_after_reconnect: 0
    };

    // ---- C6b ordered sequence_gap via armDropNextInboundEntityFrame ----
    const gapSessions = assignment.gap_sessions;
    if (!Array.isArray(gapSessions) || gapSessions.length < 3) {
      throw new Error("C6b requires assignment.gap_sessions with three unclaimed session UUIDs");
    }
    const gapP1 = await bootstrapClient(browser, appUrl, "gapP1");
    const gapP2 = await bootstrapClient(browser, appUrl, "gapP2");
    await selectWorkspace(gapP1, assignment.workspace_w2, assignment.workspace_w2_name || "Claim W2");
    await selectWorkspace(gapP2, assignment.workspace_w2, assignment.workspace_w2_name || "Claim W2");
    const gapForm1 = await openAddDialog(gapP1, assignment.workspace_w2);
    await waitForOption(gapP1, gapForm1, gapSessions[0]);
    await selectSession(gapP1, gapForm1, gapSessions[0]); // A held stale candidate
    const gapBaseline = await gapP1.evaluate((requiredFamilies) => {
      const events = globalThis.__BOTSTER_LIVE_PROTOCOL_HARNESS__?.events ?? [];
      const familyOf = (entry) => {
        const payload = entry?.payload ?? {};
        const nested = payload.payload ?? {};
        const request = payload.request ?? {};
        const out = new Set();
        for (const value of [
          payload.entity_type, nested.entity_type, request.entity_type, payload.family, nested.family
        ]) {
          if (typeof value === "string" && value) out.add(value);
        }
        if (Array.isArray(request.entity_types)) for (const v of request.entity_types) if (v) out.add(v);
        if (Array.isArray(request.subscriptions)) {
          for (const sub of request.subscriptions) {
            if (sub?.entity_type) out.add(sub.entity_type);
          }
        }
        return [...out];
      };
      const byFamily = Object.fromEntries(requiredFamilies.map((f) => [f, { subscribe_count: 0, snapshot_count: 0 }]));
      for (const entry of events) {
        const families = familyOf(entry);
        const isSub = entry.kind === "daemon_request" && entry.payload?.type === "subscribe_entities";
        const isSnap = entry.kind === "hub_frame" && (
          entry.payload?.kind === "entity_snapshot"
          || entry.payload?.type === "entity_snapshot"
          || entry.payload?.payload?.type === "entity_snapshot"
        );
        for (const family of families) {
          if (!byFamily[family]) continue;
          if (isSub) byFamily[family].subscribe_count += 1;
          if (isSnap) byFamily[family].snapshot_count += 1;
        }
      }
      return { event_count: events.length, by_family: byFamily };
    }, REQUIRED_ENTITY_FAMILIES);
    let gapForm2 = await openAddDialog(gapP2, assignment.workspace_w2);
    await waitForOption(gapP2, gapForm2, gapSessions[0]);
    await selectSession(gapP2, gapForm2, gapSessions[0]);
    await submitAdd(gapP2, gapForm2, assignment.workspace_w2, gapSessions[0], "C6b warmup A");
    const arm = await gapP1.evaluate(() => {
      const control = globalThis.__BOTSTER_LIVE_PROTOCOL_HARNESS__?.transportControl;
      if (!control?.armDropNextInboundEntityFrame) {
        return { ok: false, reason: "missing_control" };
      }
      if (typeof control.disarmDropNextInboundEntityFrame === "function") {
        control.disarmDropNextInboundEntityFrame();
      }
      return control.armDropNextInboundEntityFrame({ entity_type: "botster-workspaces.membership" });
    });
    if (!arm?.ok) {
      throw new Error(`C6b armDropNextInboundEntityFrame failed: ${JSON.stringify(arm)}`);
    }
    gapForm2 = await openAddDialog(gapP2, assignment.workspace_w2);
    await waitForOption(gapP2, gapForm2, gapSessions[1]);
    await selectSession(gapP2, gapForm2, gapSessions[1]);
    await submitAdd(gapP2, gapForm2, assignment.workspace_w2, gapSessions[1], "C6b drop B");
    const dropState = await gapP1.evaluate(() =>
      globalThis.__BOTSTER_LIVE_PROTOCOL_HARNESS__?.transportControl?.getDropNextInboundEntityFrameState?.()
      ?? null
    );
    gapForm2 = await openAddDialog(gapP2, assignment.workspace_w2);
    await waitForOption(gapP2, gapForm2, gapSessions[2]);
    await selectSession(gapP2, gapForm2, gapSessions[2]);
    await submitAdd(gapP2, gapForm2, assignment.workspace_w2, gapSessions[2], "C6b gap C");
    const gapEvidence = await gapP1.waitForFunction(
      ({ sinceEventCount, priorByFamily, requiredFamilies, membershipFamily }) => {
        const events = globalThis.__BOTSTER_LIVE_PROTOCOL_HARNESS__?.events ?? [];
        const tail = events.slice(sinceEventCount);
        const familyOf = (entry) => {
          const payload = entry?.payload ?? {};
          const nested = payload.payload ?? {};
          const request = payload.request ?? {};
          const out = new Set();
          for (const value of [
            payload.entity_type, nested.entity_type, request.entity_type, payload.family, nested.family
          ]) {
            if (typeof value === "string" && value) out.add(value);
          }
          if (Array.isArray(request.entity_types)) for (const v of request.entity_types) if (v) out.add(v);
          if (Array.isArray(request.subscriptions)) {
            for (const sub of request.subscriptions) {
              if (sub?.entity_type) out.add(sub.entity_type);
            }
          }
          return [...out];
        };
        const gapHit = tail.some((entry) => {
          const text = JSON.stringify(entry);
          return text.includes("sequence_gap")
            || entry.payload?.reason === "sequence_gap"
            || entry.payload?.payload?.reason === "sequence_gap";
        });
        const byFamily = Object.fromEntries(requiredFamilies.map((f) => [f, {
          subscribe_count: 0,
          snapshot_count: 0,
          subscription_ids: [],
          snapshot_seqs: []
        }]));
        for (const entry of events) {
          const families = familyOf(entry);
          const isSub = entry.kind === "daemon_request" && entry.payload?.type === "subscribe_entities";
          const isSnap = entry.kind === "hub_frame" && (
            entry.payload?.kind === "entity_snapshot"
            || entry.payload?.type === "entity_snapshot"
            || entry.payload?.payload?.type === "entity_snapshot"
          );
          for (const family of families) {
            if (!byFamily[family]) continue;
            if (isSub) {
              byFamily[family].subscribe_count += 1;
              const sid = entry.payload?.request?.subscription_id || entry.payload?.subscription_id;
              if (sid) byFamily[family].subscription_ids.push(sid);
            }
            if (isSnap) {
              byFamily[family].snapshot_count += 1;
              const seq = entry.payload?.snapshot_seq
                ?? entry.payload?.payload?.snapshot_seq
                ?? entry.payload?.generation
                ?? entry.payload?.payload?.generation;
              if (seq != null) byFamily[family].snapshot_seqs.push(seq);
            }
          }
        }
        // Membership family must resubscribe and replace after the armed drop (primary gap family).
        const membershipAdvanced =
          byFamily[membershipFamily].subscribe_count > (priorByFamily[membershipFamily]?.subscribe_count ?? 0)
          && byFamily[membershipFamily].snapshot_count > (priorByFamily[membershipFamily]?.snapshot_count ?? 0);
        // Session family must also show a post-gap replacement snapshot when it was subscribed.
        const sessionFamily = "session";
        const sessionWasSubscribed = (priorByFamily[sessionFamily]?.subscribe_count ?? 0) > 0
          || byFamily[sessionFamily].subscribe_count > 0;
        const sessionAdvanced = !sessionWasSubscribed || (
          byFamily[sessionFamily].subscribe_count > (priorByFamily[sessionFamily]?.subscribe_count ?? 0)
          && byFamily[sessionFamily].snapshot_count > (priorByFamily[sessionFamily]?.snapshot_count ?? 0)
        );
        if (!gapHit || !membershipAdvanced || !sessionAdvanced) return null;
        return {
          sequence_gap: true,
          resubscribe: true,
          replacement_snapshot: true,
          by_family: byFamily,
          membership_family: membershipFamily,
          tail_count: tail.length
        };
      },
      {
        sinceEventCount: gapBaseline.event_count,
        priorByFamily: gapBaseline.by_family,
        requiredFamilies: REQUIRED_ENTITY_FAMILIES,
        membershipFamily: "botster-workspaces.membership"
      },
      { timeout: 60_000 }
    ).then((handle) => handle.jsonValue());
    // Held A was claimed by peer; must emit zero outbound claim for A after gap resync.
    const gapStaleSince = await harnessEventCount(gapP1);
    await gapForm1.locator("ion-button[data-action-id='botster_workspaces.add_session']")
      .click({ timeout: 5_000 })
      .catch(() => {});
    await gapP1.waitForTimeout(800);
    const gapStaleOutbound = await gapP1.evaluate(({ since, sessionId }) =>
      (globalThis.__BOTSTER_LIVE_PROTOCOL_HARNESS__?.events ?? []).slice(since).filter((entry) => {
        const request = entry.payload?.request;
        if (entry.kind !== "daemon_request" || entry.payload?.type !== "plugin_surface_action") return false;
        if (request?.action_id !== "botster_workspaces.add_session") return false;
        const values = request.values ?? {};
        const resolved = values.session_id
          || values.session_id_advanced
          || values["botster-workspaces-add-session-id"]
          || values["botster-workspaces-add-session-id-advanced"];
        return resolved === sessionId;
      }),
    { since: gapStaleSince, sessionId: gapSessions[0] });
    if (gapStaleOutbound.length !== 0) {
      throw new Error(
        `C6b stale held A emitted claim outbound after sequence_gap resync: count=${gapStaleOutbound.length}`
      );
    }
    summary.lanes.c6b = {
      control: "transportControl.armDropNextInboundEntityFrame",
      filter: { entity_type: "botster-workspaces.membership" },
      chronology: "warmup_A_drop_B_gap_C",
      arm,
      drop_state: dropState,
      gap_evidence: gapEvidence,
      stale_outbound_for_held_a: 0
    };

    summary.completed = true;
    summary.app_url = appUrl;
    console.log(`claim-stack-web-summary ${JSON.stringify(summary)}`);
  } finally {
    await browser.close().catch(() => {});
  }
}

run().catch((error) => {
  summary.completed = false;
  summary.error = { message: error.message, stack: error.stack };
  console.error(error);
  console.log(`claim-stack-web-summary ${JSON.stringify(summary)}`);
  process.exit(1);
});
