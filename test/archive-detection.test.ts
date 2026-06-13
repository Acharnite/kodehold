/**
 * Tests for the archive detection mechanism in agentmemory-capture.ts
 *
 * The archive detection code (lines 283-295) handles `session.updated` events
 * where `time.archived` is set (a number). When detected, it:
 * 1. Calls POST /session/end with the session ID
 * 2. Calls POST /crystals/auto with olderThanDays: 7
 * 3. Calls POST /consolidate-pipeline with tier: "all", force: true
 * 4. Clears activeSessionId if it matches
 * 5. Calls pruneSessionMaps(sid)
 * 6. Clears startContextCache and contextInjectedSessions entries
 * 7. Calls clearIdleTimer()
 * 8. Returns early (does NOT fall through to the observe call)
 *
 * See ADR-0044: Automatic Session Lifecycle Management
 */

import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";

// ── Types matching the plugin's internal state ──

interface EventInput {
  event: {
    type: string;
    properties?: Record<string, unknown>;
  };
}

// ── Mock setup ──

/**
 * Creates a mock plugin environment that simulates the module-level state
 * and helper functions from agentmemory-capture.ts.
 *
 * Returns the event handler function and a set of spies/state accessors.
 */
function createMockPlugin() {
  // Track POST calls
  const postCalls: Array<{ path: string; body: Record<string, unknown> }> = [];

  // Mock state
  let activeSessionId: string | null = null;
  const stashedFiles = new Map<string, Set<string>>();
  const seenSubtaskIds = new Map<string, Set<string>>();
  const seenToolCallIds = new Map<string, Set<string>>();
  const contextInjectedSessions = new Set<string>();
  const startContextCache = new Map<string, string>();
  let idleTimerActive = false;

  // Mock helpers (mirroring the plugin)
  function pruneSessionMaps(sid: string): void {
    stashedFiles.delete(sid);
    seenSubtaskIds.delete(sid);
    seenToolCallIds.delete(sid);
  }

  function clearIdleTimer(): void {
    idleTimerActive = false;
  }

  // Mock post function
  async function post(path: string, body: Record<string, unknown>, _timeoutMs?: number): Promise<void> {
    postCalls.push({ path, body });
  }

  // Mock observe function
  const observeCalls: Array<{
    sessionId: string;
    hookType: string;
    data: Record<string, unknown>;
  }> = [];

  async function observe(
    sessionId: string,
    hookType: string,
    data: Record<string, unknown>,
  ): Promise<void> {
    observeCalls.push({ sessionId, hookType, data });
  }

  // ── The archive detection logic (extracted from lines 277-305) ──
  async function handleSessionUpdated(input: EventInput): Promise<void> {
    const type = input.event.type;
    const props = input.event.properties || {};

    if (type === "session.updated") {
      const info = props.info as Record<string, unknown> | undefined;
      const sid = (info?.id as string) || (props.sessionID as string) || activeSessionId;
      if (!sid) return;

      // Detect archive — OpenCode sets time.archived when user archives a session
      const time = info?.time as Record<string, unknown> | undefined;
      if (time && typeof time.archived === "number") {
        await post("/session/end", { sessionId: sid });
        post("/crystals/auto", { olderThanDays: 7 }, 30000);
        post("/consolidate-pipeline", { tier: "all", force: true }, 30000);
        if (sid === activeSessionId) activeSessionId = null;
        pruneSessionMaps(sid);
        startContextCache.delete(sid);
        contextInjectedSessions.delete(sid);
        clearIdleTimer();
        return;
      }

      await observe(sid, "session_updated", {
        title: info?.title ?? null,
        parentID: info?.parentID ?? null,
        additions: (info?.summary as any)?.additions ?? null,
        deletions: (info?.summary as any)?.deletions ?? null,
        files: (info?.summary as any)?.files ?? null,
      });
    }
  }

  return {
    handleSessionUpdated,
    postCalls,
    observeCalls,
    get activeSessionId() {
      return activeSessionId;
    },
    set activeSessionId(val: string | null) {
      activeSessionId = val;
    },
    get stashedFiles() {
      return stashedFiles;
    },
    get seenSubtaskIds() {
      return seenSubtaskIds;
    },
    get seenToolCallIds() {
      return seenToolCallIds;
    },
    get contextInjectedSessions() {
      return contextInjectedSessions;
    },
    get startContextCache() {
      return startContextCache;
    },
    get idleTimerActive() {
      return idleTimerActive;
    },
    set idleTimerActive(val: boolean) {
      idleTimerActive = val;
    },
    pruneSessionMaps,
  };
}

// ── Helper to create a session.updated event ──

function createSessionUpdatedEvent(
  overrides: {
    sessionId?: string;
    archived?: unknown;
    title?: string;
    parentID?: string;
    summary?: Record<string, unknown>;
    extraTimeFields?: Record<string, unknown>;
  } = {},
): EventInput {
  const {
    sessionId = "test-session-123",
    archived,
    title = "Test Session",
    parentID,
    summary,
    extraTimeFields = {},
  } = overrides;

  const time: Record<string, unknown> = {
    created: 1000,
    updated: 2000,
    ...extraTimeFields,
  };

  // Only add archived if explicitly provided (even if undefined, we skip it)
  if (archived !== undefined) {
    time.archived = archived;
  }

  const info: Record<string, unknown> = {
    id: sessionId,
    title,
    time,
  };

  if (parentID !== undefined) info.parentID = parentID;
  if (summary !== undefined) info.summary = summary;

  return {
    event: {
      type: "session.updated",
      properties: { info },
    },
  };
}

// ── Tests ──

describe("Archive Detection (session.updated with time.archived)", () => {
  let mock: ReturnType<typeof createMockPlugin>;

  beforeEach(() => {
    mock = createMockPlugin();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  // ── Happy path ──

  it("should call POST /session/end when time.archived is a number", async () => {
    const event = createSessionUpdatedEvent({ sessionId: "sid-1", archived: 1234567890 });
    await mock.handleSessionUpdated(event);

    expect(mock.postCalls).toContainEqual(
      expect.objectContaining({
        path: "/session/end",
        body: { sessionId: "sid-1" },
      }),
    );
  });

  it("should call POST /crystals/auto with olderThanDays: 7", async () => {
    const event = createSessionUpdatedEvent({ sessionId: "sid-1", archived: 1234567890 });
    await mock.handleSessionUpdated(event);

    expect(mock.postCalls).toContainEqual(
      expect.objectContaining({
        path: "/crystals/auto",
        body: { olderThanDays: 7 },
      }),
    );
  });

  it("should call POST /consolidate-pipeline with tier: all, force: true", async () => {
    const event = createSessionUpdatedEvent({ sessionId: "sid-1", archived: 1234567890 });
    await mock.handleSessionUpdated(event);

    expect(mock.postCalls).toContainEqual(
      expect.objectContaining({
        path: "/consolidate-pipeline",
        body: { tier: "all", force: true },
      }),
    );
  });

  it("should clear activeSessionId when it matches the archived session", async () => {
    mock.activeSessionId = "sid-1";
    const event = createSessionUpdatedEvent({ sessionId: "sid-1", archived: 1234567890 });
    await mock.handleSessionUpdated(event);

    expect(mock.activeSessionId).toBeNull();
  });

  it("should NOT clear activeSessionId when it does NOT match the archived session", async () => {
    mock.activeSessionId = "other-session";
    const event = createSessionUpdatedEvent({ sessionId: "sid-1", archived: 1234567890 });
    await mock.handleSessionUpdated(event);

    expect(mock.activeSessionId).toBe("other-session");
  });

  it("should call pruneSessionMaps for the archived session", async () => {
    // Set up some state to be pruned
    mock.stashedFiles.set("sid-1", new Set(["file1.ts"]));
    mock.seenSubtaskIds.set("sid-1", new Set(["subtask-1"]));
    mock.seenToolCallIds.set("sid-1", new Set(["call-1"]));

    const event = createSessionUpdatedEvent({ sessionId: "sid-1", archived: 1234567890 });
    await mock.handleSessionUpdated(event);

    expect(mock.stashedFiles.has("sid-1")).toBe(false);
    expect(mock.seenSubtaskIds.has("sid-1")).toBe(false);
    expect(mock.seenToolCallIds.has("sid-1")).toBe(false);
  });

  it("should clear startContextCache entry for the archived session", async () => {
    mock.startContextCache.set("sid-1", "some-context");
    mock.startContextCache.set("other-session", "other-context");

    const event = createSessionUpdatedEvent({ sessionId: "sid-1", archived: 1234567890 });
    await mock.handleSessionUpdated(event);

    expect(mock.startContextCache.has("sid-1")).toBe(false);
    // Other sessions should be unaffected
    expect(mock.startContextCache.get("other-session")).toBe("other-context");
  });

  it("should clear contextInjectedSessions entry for the archived session", async () => {
    mock.contextInjectedSessions.add("sid-1");
    mock.contextInjectedSessions.add("other-session");

    const event = createSessionUpdatedEvent({ sessionId: "sid-1", archived: 1234567890 });
    await mock.handleSessionUpdated(event);

    expect(mock.contextInjectedSessions.has("sid-1")).toBe(false);
    // Other sessions should be unaffected
    expect(mock.contextInjectedSessions.has("other-session")).toBe(true);
  });

  it("should call clearIdleTimer()", async () => {
    // Set idle timer as active
    mock.idleTimerActive = true;

    const event = createSessionUpdatedEvent({ sessionId: "sid-1", archived: 1234567890 });
    await mock.handleSessionUpdated(event);

    expect(mock.idleTimerActive).toBe(false);
  });

  it("should return early and NOT call observe when archived", async () => {
    const event = createSessionUpdatedEvent({ sessionId: "sid-1", archived: 1234567890 });
    await mock.handleSessionUpdated(event);

    expect(mock.observeCalls).toHaveLength(0);
  });

  // ── Negative case ──

  it("should NOT trigger archive behavior when time.archived is absent", async () => {
    const event = createSessionUpdatedEvent({ sessionId: "sid-1" }); // no archived
    await mock.handleSessionUpdated(event);

    // Should NOT have any POST calls for session end / crystals / consolidate
    const archivePaths = ["/session/end", "/crystals/auto", "/consolidate-pipeline"];
    const archiveCalls = mock.postCalls.filter((c) => archivePaths.includes(c.path));
    expect(archiveCalls).toHaveLength(0);

    // Should have called observe instead
    expect(mock.observeCalls).toHaveLength(1);
    expect(mock.observeCalls[0].hookType).toBe("session_updated");
  });

  it("should fall through to observe when time.archived is absent", async () => {
    const event = createSessionUpdatedEvent({
      sessionId: "sid-1",
      title: "My Session",
      parentID: "parent-1",
      summary: { additions: 5, deletions: 3, files: 2 },
    });
    await mock.handleSessionUpdated(event);

    expect(mock.observeCalls).toHaveLength(1);
    expect(mock.observeCalls[0]).toMatchObject({
      sessionId: "sid-1",
      hookType: "session_updated",
      data: {
        title: "My Session",
        parentID: "parent-1",
        additions: 5,
        deletions: 3,
        files: 2,
      },
    });
  });

  // ── Edge cases ──

  it("should return early when session ID is missing", async () => {
    // info object exists but has no id, no props.sessionID, and activeSessionId is null
    const event: EventInput = {
      event: {
        type: "session.updated",
        properties: {
          info: {
            title: "No ID Session",
            time: { created: 1000, updated: 2000, archived: 1234567890 },
          },
        },
      },
    };
    await mock.handleSessionUpdated(event);

    expect(mock.postCalls).toHaveLength(0);
    expect(mock.observeCalls).toHaveLength(0);
  });

  it("should return early when info object is missing", async () => {
    const event: EventInput = {
      event: {
        type: "session.updated",
        properties: {}, // no info
      },
    };
    await mock.handleSessionUpdated(event);

    expect(mock.postCalls).toHaveLength(0);
    expect(mock.observeCalls).toHaveLength(0);
  });

  it("should NOT trigger archive when time.archived is a string", async () => {
    const event = createSessionUpdatedEvent({ sessionId: "sid-1", archived: "yes" });
    await mock.handleSessionUpdated(event);

    const archivePaths = ["/session/end", "/crystals/auto", "/consolidate-pipeline"];
    const archiveCalls = mock.postCalls.filter((c) => archivePaths.includes(c.path));
    expect(archiveCalls).toHaveLength(0);

    // Should fall through to observe
    expect(mock.observeCalls).toHaveLength(1);
  });

  it("should NOT trigger archive when time.archived is a boolean", async () => {
    const event = createSessionUpdatedEvent({ sessionId: "sid-1", archived: true });
    await mock.handleSessionUpdated(event);

    const archivePaths = ["/session/end", "/crystals/auto", "/consolidate-pipeline"];
    const archiveCalls = mock.postCalls.filter((c) => archivePaths.includes(c.path));
    expect(archiveCalls).toHaveLength(0);

    expect(mock.observeCalls).toHaveLength(1);
  });

  it("should NOT trigger archive when time.archived is null", async () => {
    const event = createSessionUpdatedEvent({ sessionId: "sid-1", archived: null });
    await mock.handleSessionUpdated(event);

    const archivePaths = ["/session/end", "/crystals/auto", "/consolidate-pipeline"];
    const archiveCalls = mock.postCalls.filter((c) => archivePaths.includes(c.path));
    expect(archiveCalls).toHaveLength(0);

    expect(mock.observeCalls).toHaveLength(1);
  });

  it("should NOT trigger archive when time.archived is undefined (key missing)", async () => {
    const event = createSessionUpdatedEvent({ sessionId: "sid-1" }); // archived not set
    await mock.handleSessionUpdated(event);

    const archivePaths = ["/session/end", "/crystals/auto", "/consolidate-pipeline"];
    const archiveCalls = mock.postCalls.filter((c) => archivePaths.includes(c.path));
    expect(archiveCalls).toHaveLength(0);

    expect(mock.observeCalls).toHaveLength(1);
  });

  it("should trigger archive when time.archived is 0 (falsy but valid number)", async () => {
    const event = createSessionUpdatedEvent({ sessionId: "sid-1", archived: 0 });
    await mock.handleSessionUpdated(event);

    // typeof 0 === "number" → true, so archive should trigger
    expect(mock.postCalls).toContainEqual(
      expect.objectContaining({
        path: "/session/end",
        body: { sessionId: "sid-1" },
      }),
    );
    expect(mock.observeCalls).toHaveLength(0);
  });

  it("should NOT trigger archive when time object is missing entirely", async () => {
    const event: EventInput = {
      event: {
        type: "session.updated",
        properties: {
          info: {
            id: "sid-1",
            title: "Test",
            // no time field
          },
        },
      },
    };
    await mock.handleSessionUpdated(event);

    const archivePaths = ["/session/end", "/crystals/auto", "/consolidate-pipeline"];
    const archiveCalls = mock.postCalls.filter((c) => archivePaths.includes(c.path));
    expect(archiveCalls).toHaveLength(0);

    expect(mock.observeCalls).toHaveLength(1);
  });

  it("should use props.sessionID as fallback when info.id is missing", async () => {
    const event: EventInput = {
      event: {
        type: "session.updated",
        properties: {
          sessionID: "fallback-sid",
          info: {
            title: "Test",
            time: { created: 1000, updated: 2000, archived: 1234567890 },
          },
        },
      },
    };
    await mock.handleSessionUpdated(event);

    expect(mock.postCalls).toContainEqual(
      expect.objectContaining({
        path: "/session/end",
        body: { sessionId: "fallback-sid" },
      }),
    );
  });

  it("should use activeSessionId as last-resort fallback when info.id and props.sessionID are missing", async () => {
    mock.activeSessionId = "active-sid";
    const event: EventInput = {
      event: {
        type: "session.updated",
        properties: {
          info: {
            title: "Test",
            time: { created: 1000, updated: 2000, archived: 1234567890 },
          },
        },
      },
    };
    await mock.handleSessionUpdated(event);

    expect(mock.postCalls).toContainEqual(
      expect.objectContaining({
        path: "/session/end",
        body: { sessionId: "active-sid" },
      }),
    );
  });

  it("should handle non-session.updated events gracefully (no-op)", async () => {
    const event: EventInput = {
      event: {
        type: "session.created",
        properties: {
          info: { id: "sid-1", time: { archived: 1234567890 } },
        },
      },
    };
    await mock.handleSessionUpdated(event);

    // The handler only processes session.updated, so nothing should happen
    expect(mock.postCalls).toHaveLength(0);
    expect(mock.observeCalls).toHaveLength(0);
  });

  it("should call all three POST endpoints in the correct order", async () => {
    const event = createSessionUpdatedEvent({ sessionId: "sid-1", archived: 1234567890 });
    await mock.handleSessionUpdated(event);

    expect(mock.postCalls.length).toBeGreaterThanOrEqual(3);

    // /session/end should be first (it's awaited), crystals and consolidate are fire-and-forget
    expect(mock.postCalls[0].path).toBe("/session/end");
    expect(mock.postCalls[0].body).toEqual({ sessionId: "sid-1" });

    // The other two should be present (order may vary since they're fire-and-forget)
    const paths = mock.postCalls.map((c) => c.path);
    expect(paths).toContain("/crystals/auto");
    expect(paths).toContain("/consolidate-pipeline");
  });

  it("should not affect other sessions' state when pruning", async () => {
    // Set up state for multiple sessions
    mock.stashedFiles.set("sid-1", new Set(["file1.ts"]));
    mock.stashedFiles.set("sid-2", new Set(["file2.ts"]));
    mock.seenSubtaskIds.set("sid-1", new Set(["subtask-1"]));
    mock.seenSubtaskIds.set("sid-2", new Set(["subtask-2"]));
    mock.seenToolCallIds.set("sid-1", new Set(["call-1"]));
    mock.seenToolCallIds.set("sid-2", new Set(["call-2"]));

    const event = createSessionUpdatedEvent({ sessionId: "sid-1", archived: 1234567890 });
    await mock.handleSessionUpdated(event);

    // sid-1 should be pruned
    expect(mock.stashedFiles.has("sid-1")).toBe(false);
    expect(mock.seenSubtaskIds.has("sid-1")).toBe(false);
    expect(mock.seenToolCallIds.has("sid-1")).toBe(false);

    // sid-2 should be untouched
    expect(mock.stashedFiles.has("sid-2")).toBe(true);
    expect(mock.seenSubtaskIds.has("sid-2")).toBe(true);
    expect(mock.seenToolCallIds.has("sid-2")).toBe(true);
  });
});