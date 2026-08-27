---
name: mw-recall
description: 'Use only when a user request begins with "mw: recall" to retrieve and apply relevant state from authoritative Macwarden ScopeLogs.'
---

# Macwarden recall

## Process

1. **Form the query.** Use suffix text after `mw: recall` as the primary query and the current request or conversation as secondary context. With no suffix, use the current request or conversation directly. **Complete when:** one concrete retrieval question or supplied modification instruction is explicit.

2. **Select narrowly.** Read `macwarden --help`, run `macwarden list`, and semantically choose the smallest plausible candidate set from the stable Scope IDs. Read those complete logs with `macwarden show`; broaden only when the first candidates cannot answer. **Complete when:** the selected ScopeLogs answer the query or establish exactly what is absent.

3. **Use the recall.** For retrieval alone, return only relevant current State, Reasons, constraints, and Scope identities. For a concrete modification instruction, cooperate on that instruction under the recalled constraints. Keep work within supplied authority and current context; when required information is absent, name it and return control. **Complete when:** the request is answered from the logs or the authorized modification is verified.

4. **Close verified transitions.** If the authorized work produced verified new host state, invoke the model-invoked `mw-capture` Skill. That Skill is the single source of truth for capture; the original `mw: recall` instruction supplies write authority without a second prefix. **Complete when:** its canonical verification criterion succeeds.

Recall uses Agent-native semantic choice over full ScopeLogs. Its retrieval boundary is the configured authority; external research and infrastructure indexing require separate work.
