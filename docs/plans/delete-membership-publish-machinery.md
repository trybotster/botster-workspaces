# Premise: delete the membership publish machinery (rule 6)

Status: proposal, 2026-09-28. Its own request after the { hub_id, session_id }
rekey (943d062) lands. Binding rules: /private/tmp/botster-regrowth-rules-20260928.md.

## What exists (plugin.lua, about 30 sites)

1. A durable sequence key `membership_entity_seq` in plugin_db.
2. Range reservation: every membership mutation adds a CAS write of
   `membership_entity_seq` to its plugin_db batch and numbers its frames
   `last+1 … last+N` (`commit_membership_batch`, `build_reserved_frames`).
3. Publish retry: every frame whose `entity_publish` result is not ok is
   published once more with the same sequence (`publish_membership_frames`).
4. Delivery reporting: every mutation result carries `membership_delivery`
   (`published` / `degraded` / `none`), `membership_publish`, and
   `membership_reserved_seqs` (`with_membership_delivery`).
5. Provider CAS loop: the snapshot provider reads the sequence, lists the
   index, re-reads the sequence, retries on any change, and CAS-allocates one
   sequence for the snapshot (`membership_entity_provider`).

## What each guards against, and whether it was observed

| Item | Guards against | Observed? |
|---|---|---|
| 1, 2, 5 | The Hub's `entity_publish` contract: the package owns a strictly increasing `snapshot_seq` per family, and a snapshot must not roll a subscriber back. | No incident. It exists because the Hub API demands package-owned sequence numbers. |
| 3 | A transient `entity_publish` failure. | No. `entity_publish` is a synchronous in-process call. The only evidence was the deleted fake suite, which injected a throw (inventory E9-E14). |
| 4 | A caller needs to know that a committed mutation was not published. | No caller reads these fields. The Web and the TUI read the entity family, not the tool result. |

## Proposal

Plugin side (this repo), with no Hub change:
- Delete 3 (retry) and 4 (delivery fields). A failed publish is logged once
  through `botster.log.warn`. Subscribers recover through the Hub's own
  provider resync, which already exists (`resync_scheduled`).

Hub side (for the plugin platform owner; it is not this repo's decision):
- The Hub assigns `snapshot_seq` itself on `entity_publish` and on the provider
  snapshot, per family, in its own order. The package stops numbering frames.
- Then the plugin deletes 1, 2, and 5: the sequence key, the range
  reservation, and the provider CAS loop. The provider becomes "list the
  index, return the rows".
- The Hub's pending window (W=16), `pending_gap`, and `stale_sequence` /
  `duplicate_sequence` refusals exist only because packages number frames.
  With Hub-owned numbering they go too. This matches the H9/H11 simplification
  direction in /private/tmp/botster-scope-audit-20260928.md.

Nothing replaces them. The H14 `events_dropped` marker mentioned by the
orchestrator is not on botster-hub main at 2026-09-28; this proposal does not
depend on it.

## Test plan

- Kit specs that remain: membership_spec "publish upsert and remove frames"
  (frame order, row shape, snapshot first).
- Delete the delivery-field assertions (M13 `membership_delivery = "none"`).
- The package-side deletion is a pure removal: the full `script/test` must stay green.
