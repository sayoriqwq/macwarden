---
name: mw-recall
description: 'Recall Macwarden history when a request starts with "mw: recall", then use that evidence to answer the question or guide explicitly authorized host work.'
---

# Macwarden recall

Observations are historical state nodes. A Transition's Change records what happened; derive current state from fresh readback rather than treating Change as an executable plan.

## Process

1. **Form the query.** Use the text after `mw: recall`. If it is empty, use the current request's explicit question or modification target; when neither is present, ask one concise clarification and stop. **Complete when:** one retrieval question or one explicitly authorized modification target is written down, or the clarification request has been sent.

2. **Establish authority.** Run `macwarden path` and `macwarden list`. Choose the smallest plausible record set, then use `macwarden show` to read the target selectors and follow each relevant Transition's Before/After references. Broaden the set only when the current records cannot answer the query. **Complete when:** the relevant evidence graph is present, or the missing selector or evidence is named.

3. **Branch by intent.** For retrieval, render a concise audit view in the user's language: lead with the conclusion, align Before and After by Scope, then report Reason, actual Change, standalone facts, unknowns, and supporting selectors. For modification, enter the branch only when the request explicitly authorizes host work; read back the host first, derive a current patch from the target Observation and relevant Transitions, and verify the result. **Complete when:** the retrieval answer cites its supporting selectors, or the authorized host result is verified against fresh readback.

4. **Close the loop.** When authorized work establishes new host state, invoke the model-invoked `mw-capture` Skill; the original `mw: recall` request supplies capture authority. For read-only retrieval or work that establishes no new state, return the audit result without a capture. **Complete when:** every new state change has passed `mw-capture` verification, or the read-only result is delivered without a capture.

Use the configured authority and Agent-native semantic selection. Keep the audit view transient; authority remains the canonical record store.
