---
name: mw-capture
description: 'Capture verified host state when a request starts with "mw: capture", or when `mw-recall` has completed authorized host work and needs to close the loop.'
---

# Macwarden capture

Use this skill to append evidence-backed records to the configured authority. Host mutation is a separate authorized step.

## Process

1. **Establish authority.** Run `macwarden path`, then `macwarden list`. Show only the records that you may reuse or must connect through a Transition. If the authority is Git-backed, resolve every pre-existing change in its affected paths before writing; pause when any remains unexplained. **Complete when:** `path` and `list` succeed, every reused or referenced selector has been shown, and pre-existing authority changes are understood.

2. **Distill evidence.** Give each Observation one stable Scope, a Context that attributes when and how it was established, and State facts confirmed by readback. Mark unsupported facts `unknown`; classify claims in Context as observed, reported, sourced, or inferred. Give each Transition one Reason, the actual Change, and Before/After Observation IDs. Put only results established or changed by the Transition in After; use standalone Observations for simultaneous facts whose causality is unknown. Reuse an unchanged existing Before record. Without trustworthy Before evidence, capture the new Observation only. **Complete when:** every State fact has evidence, every important claim has attribution, and every Transition crosses its Scopes without invented causality.

3. **Build the draft.** Use [observation.md](references/observation.md) for standalone evidence and [transition.md](references/transition.md) for a change. Replace every placeholder. Write Context, State, Reason, and Change in the user's language; preserve IDs, paths, commands, option names, and quoted source text verbatim. For additional Scopes, repeat the template's Observation block and add each ID to the matching Before or After list. **Complete when:** the draft contains only canonical records, every required field is filled, and no placeholder remains.

4. **Capture and verify.** Run `macwarden capture <draft.md>`. For each returned selector, run `macwarden show`; when capture reports a possible immutable-record conflict, show that selector before any retry. For a Git-backed authority, commit only the verified new records and confirm the affected paths are clean. For an unversioned authority, report that fact. **Complete when:** capture reports `no changes` or every new selector is shown and matches the evidence, and version-history status is reported.

Return the new Observation and Transition selectors plus a concise statement of what was recorded. Keep authority and current readback as the source of truth; perform host mutation only in its separately authorized work.
