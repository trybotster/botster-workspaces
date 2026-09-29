-- Stands in for botster-orchestrator as the producer of session_spawned.
-- The kit cannot spawn a real session, so this fixture emits the event that
-- botster-orchestrator emits after a successful spawn. Only the producer is
-- a stand-in; the event plane, the subscription, and botster-workspaces are real.
return botster.register({ tools = { {
  name = "producer.emit",
  description = "Emit botster-orchestrator.session_spawned.",
  handler = "emit",
  input_schema = { type = "object" },
  call = function(args)
    return botster.events.emit({ name = "session_spawned", payload = args })
  end,
} } })
