---
name: mw-capture
description: 'Use when a request begins with "mw: capture", or when `mw-recall` closes verified host work, to append evidence-backed Observations and Transitions to Macwarden.'
---

# Macwarden capture

`mw: capture` authorizes writes to Macwarden for the current task or conversation.

## Process

1. **Establish authority.** Run `macwarden path`, read `macwarden capture --help`, then use `macwarden list` and the smallest necessary `macwarden show` calls. Stop on unexplained Git changes in the affected authority paths. **Complete when:** the authority and relevant existing records are known.

2. **Distill evidence.** An Observation contains one stable Scope, Context that attributes when and how the observation was established, and readback-confirmed State facts. Mark unsupported facts `unknown`; distinguish observed, reported, sourced, and inferred claims in Context. A Transition records one Reason, the actual Change, and Before/After Observation IDs. After contains only observations established or changed by that Transition; simultaneous facts with unknown causality are standalone Observations. Reuse an existing Before record with unchanged canonical content. Without trustworthy Before evidence, capture only the new Observation. **Complete when:** every State is factual, every important assertion is attributed, and the Transition can cross all affected Scopes without inventing causality.

3. **Build one draft.** Copy [observation.md](references/observation.md) for standalone evidence or [transition.md](references/transition.md) for a change. Patch every placeholder. Write Context, State, Reason, and Change in the user's language; preserve IDs, paths, commands, option names, and quoted source text verbatim. For additional Scopes, repeat the same Observation record block and add its ID to Before or After. Do not introduce another schema. **Complete when:** one draft contains every required canonical record and no placeholder remains.

4. **Capture and verify.** Run `macwarden capture <draft.md>`, then `macwarden show` every returned selector. If the authority is Git-backed, commit only the new records after verification and confirm those paths are clean; otherwise report that no version history exists. **Complete when:** canonical records match the evidence and the write is committed or explicitly reported unversioned.

Return the new Observation and Transition selectors plus a concise statement of what was recorded. Do not search old conversations. Host mutation requires its own explicit instruction.
