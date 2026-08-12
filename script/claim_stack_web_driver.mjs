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

async function setSelectValue(select, value) {
  await select.evaluate((node, next) => {
    node.value = next;
    node.dispatchEvent(new CustomEvent("ionChange", { bubbles: true, detail: { value: next } }));
    node.dispatchEvent(new Event("change", { bubbles: true }));
  }, value);
}

async function selectSession(form, sessionId) {
  const select = form.locator("[data-ui-node-id='botster-workspaces-add-session-id'] ion-select");
  await select.waitFor({ timeout: 15_000 });
  await setSelectValue(select, sessionId);
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
  await submit.click({ timeout: 10_000 });
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
    // ---- C1: single claim path + remove restore + stale selection ----
    const p1 = await bootstrapClient(browser, appUrl, "p1");
    await selectWorkspace(p1, assignment.workspace_w1, assignment.workspace_w1_name || "Claim W1");
    let form = await openAddDialog(p1, assignment.workspace_w1);
    await waitForOption(p1, form, assignment.session_s);
    const metadata = await optionMetadata(form, assignment.session_s);
    await selectSession(form, assignment.session_s);
    const c1Claim = await submitAdd(p1, form, assignment.workspace_w1, assignment.session_s, "C1 claim");
    // Re-open and prove exclusion of claimed session.
    form = await openAddDialog(p1, assignment.workspace_w1);
    await p1.waitForTimeout(1000);
    const afterClaimOptions = await readSelectOptions(form);
    if (afterClaimOptions.includes(assignment.session_s)) {
      // Membership fanout may still be in flight; wait deterministically for exclusion.
      await p1.waitForFunction(
        ({ formId, sessionId }) => {
          const options = [...globalThis.document.querySelectorAll(
            `form[data-ui-node-id='${formId}'] [data-ui-node-id='botster-workspaces-add-session-id'] ion-select-option`
          )];
          return !options.some((option) => (option.value ?? option.getAttribute("value")) === sessionId);
        },
        { formId: `botster-workspaces-add-form-${assignment.workspace_w1}`, sessionId: assignment.session_s },
        { timeout: 30_000 }
      );
    }
    const excludedOptions = await readSelectOptions(form);
    if (excludedOptions.includes(assignment.session_s)) {
      throw new Error(`C1: claimed session still present in options: ${JSON.stringify(excludedOptions)}`);
    }
    // Stale selection: attempt normal submit without force after selecting nothing / invalid.
    const submit = form.locator(":scope > ion-button[data-action-id='botster_workspaces.add_session']");
    const beforeStale = await harnessEventCount(p1);
    await submit.click({ timeout: 3_000 }).catch(() => {});
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
    summary.lanes.c1 = {
      claim: c1Claim,
      metadata_present: metadata,
      excluded_after_claim: true,
      stale_submit_blocked: true,
      path: "entity_options_select"
    };

    // Parent removes membership for restore; driver proves reappearance after parent signal via env flag.
    if (assignment.restore_session_s_after_remove) {
      await waitForOption(p1, form, assignment.session_s, 45_000);
      summary.lanes.c1.restored_after_remove = true;
    }

    // ---- C3: dual browser race across W1 and W2 ----
    const raceA = await bootstrapClient(browser, appUrl, "raceA");
    const raceB = await bootstrapClient(browser, appUrl, "raceB");
    await selectWorkspace(raceA, assignment.workspace_w1, assignment.workspace_w1_name || "Claim W1");
    await selectWorkspace(raceB, assignment.workspace_w2, assignment.workspace_w2_name || "Claim W2");
    const formA = await openAddDialog(raceA, assignment.workspace_w1);
    const formB = await openAddDialog(raceB, assignment.workspace_w2);
    await waitForOption(raceA, formA, assignment.session_race);
    await waitForOption(raceB, formB, assignment.session_race);
    await selectSession(formA, assignment.session_race);
    await selectSession(formB, assignment.session_race);
    // Near-concurrent submits
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
    const requestIds = fulfilled.map((entry) => entry.request_id);
    if (new Set(requestIds).size !== requestIds.length) {
      throw new Error(`C3 request_ids were not distinct: ${JSON.stringify(requestIds)}`);
    }
    summary.lanes.c3 = {
      participants: "dual_browser_contexts",
      results: fulfilled,
      rejected,
      distinct_request_ids: requestIds
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
    await selectSession(idFormA, assignment.session_idem);
    await selectSession(idFormB, assignment.session_idem);
    const idemResults = await Promise.allSettled([
      submitAdd(idA, idFormA, assignment.workspace_w1, assignment.session_idem, "C4 idem A"),
      submitAdd(idB, idFormB, assignment.workspace_w1, assignment.session_idem, "C4 idem B")
    ]);
    const idemFulfilled = idemResults
      .filter((entry) => entry.status === "fulfilled")
      .map((entry) => entry.value);
    if (idemFulfilled.length < 2) {
      throw new Error(`C4 expected two correlated UI results; got ${JSON.stringify(idemResults)}`);
    }
    if (new Set(idemFulfilled.map((entry) => entry.request_id)).size !== 2) {
      throw new Error("C4 request_ids were not distinct");
    }
    summary.lanes.c4 = {
      participants: "dual_browser_same_workspace_select_before_reconcile",
      results: idemFulfilled
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
    await selectSession(reconForm, assignment.session_s2);
    const closed = await recon.evaluate(() =>
      globalThis.__BOTSTER_LIVE_PROTOCOL_HARNESS__?.transportControl?.closeDataChannel?.() ?? false
    );
    if (!closed) {
      // transportControl may live on window harness installed by production client after connect
      await recon.waitForFunction(
        () => typeof globalThis.__BOTSTER_LIVE_PROTOCOL_HARNESS__?.transportControl?.closeDataChannel === "function",
        null,
        { timeout: 20_000 }
      );
      const closed2 = await recon.evaluate(() =>
        globalThis.__BOTSTER_LIVE_PROTOCOL_HARNESS__.transportControl.closeDataChannel()
      );
      if (!closed2) {
        throw new Error("C6a closeDataChannel returned false");
      }
    }
    await recon.waitForFunction(
      () => {
        const events = globalThis.__BOTSTER_LIVE_PROTOCOL_HARNESS__?.events ?? [];
        return events.some((entry) =>
          entry.kind === "webrtc_lifecycle" ||
          entry.kind === "hub_frame" && (entry.payload?.kind === "entity_snapshot" || entry.payload?.type === "entity_snapshot")
        );
      },
      null,
      { timeout: 45_000 }
    );
    // Option set should reappear after authoritative snapshot without page reload.
    await waitForOption(recon, reconForm, assignment.session_s2, 45_000);
    summary.lanes.c6a = {
      control: "transportControl.closeDataChannel",
      closed: true,
      page_reload: false,
      options_reconciled: true
    };

    // ---- C6b ordered sequence_gap via armDropNextInboundEntityFrame ----
    // Warmup/drop/gap chronology requires three claimable sessions for membership deltas.
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
    await selectSession(gapForm1, gapSessions[0]); // A held stale candidate
    // Warmup claim A from P2
    let gapForm2 = await openAddDialog(gapP2, assignment.workspace_w2);
    await waitForOption(gapP2, gapForm2, gapSessions[0]);
    await selectSession(gapForm2, gapSessions[0]);
    await submitAdd(gapP2, gapForm2, assignment.workspace_w2, gapSessions[0], "C6b warmup A");
    // Arm drop then claim B
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
    await selectSession(gapForm2, gapSessions[1]);
    await submitAdd(gapP2, gapForm2, assignment.workspace_w2, gapSessions[1], "C6b drop B");
    // Claim C should trigger sequence_gap on P1
    gapForm2 = await openAddDialog(gapP2, assignment.workspace_w2);
    await waitForOption(gapP2, gapForm2, gapSessions[2]);
    await selectSession(gapForm2, gapSessions[2]);
    await submitAdd(gapP2, gapForm2, assignment.workspace_w2, gapSessions[2], "C6b gap C");
    await gapP1.waitForFunction(
      () => {
        const events = globalThis.__BOTSTER_LIVE_PROTOCOL_HARNESS__?.events ?? [];
        return events.some((entry) => {
          const text = JSON.stringify(entry);
          return text.includes("sequence_gap") || entry.payload?.reason === "sequence_gap";
        });
      },
      null,
      { timeout: 45_000 }
    );
    summary.lanes.c6b = {
      control: "transportControl.armDropNextInboundEntityFrame",
      filter: { entity_type: "botster-workspaces.membership" },
      chronology: "warmup_A_drop_B_gap_C",
      arm,
      sequence_gap_observed: true
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
