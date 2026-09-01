---
name: mw-recall
description: 'Use only when a request begins with "mw: recall" to retrieve Macwarden Observations and Transitions and apply their evidence to current work.'
---

# Macwarden recall

## Process

1. **Form the query.** Use suffix text after `mw: recall`, falling back to the current request. **Complete when:** one retrieval question or authorized modification is explicit.

2. **Select narrowly.** Read `macwarden --help`, run `macwarden list`, and choose the smallest plausible record selectors. Use `macwarden show` to follow Transition Before/After references; broaden only when those records cannot answer. Selection is Agent judgment, not a Core query. **Complete when:** the relevant evidence graph is present or the missing record is identified.

3. **Use the evidence.** Observations are historical facts, not an automatically computed current state. For retrieval, render a concise audit view in the user's language: lead with the conclusion, align Before and After by Scope, then report Reason, actual Change, standalone facts, unknowns, and supporting selectors. This transient view is not authority. For modification, read back the host first, then derive a current patch from the target Observation and relevant Transitions; never replay Change as a command stream. **Complete when:** the question is answered or the authorized host result is verified.

4. **Close the loop.** When authorized work establishes new host state, invoke the model-invoked `mw-capture` Skill. The original `mw: recall` request supplies capture authority. **Complete when:** the new canonical records pass that Skill's verification criterion.

Recall uses the configured authority and Agent-native semantic choice. It does not add an index or external retrieval system.
