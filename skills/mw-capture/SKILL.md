---
name: mw-capture
description: 'Use when a user request begins with "mw: capture", or when the `mw-recall` Skill invokes verified-transition closure, to distill current context into the authoritative Macwarden ScopeLog.'
---

# Macwarden capture

`mw: capture` is authority to write Macwarden from the current task or conversation.

## Process

1. **Establish authority.** Run `macwarden path`. If setup is missing, return its setup instruction and stop. Read `macwarden capture --help` before constructing the write. **Complete when:** the authority path is known and the current capture contract is loaded.

2. **Select the Scope.** Treat suffix text after `mw: capture` as a scope hint and inspect that ScopeLog first when it exists. Without a hint, run `macwarden list`, choose from the stable IDs, and use `macwarden show` only on the smallest plausible logs. Choose a stable business question rather than a task or component list. **Complete when:** one exact existing Scope ID or one stable new ID accounts for the context.

3. **Distill current evidence.** Bound evidence to the current task or conversation. Produce a self-contained current State and, for an existing Scope, one nonblank core Reason. For a new Scope, preserve a trustworthy Before State plus Reason plus After State when all three are available; otherwise record only the current State. Ask only when missing or conflicting evidence would materially change the Scope or recorded truth. **Complete when:** every body is supported by available context and the State stands alone for a later reader.

4. **Capture and verify.** Write the selected bodies to temporary Markdown files, invoke `macwarden capture` according to the help just read, then read the affected log with `macwarden show`. Limit changes to temporary inputs and the configured ScopeLog. **Complete when:** the canonical log contains the intended current State; otherwise report the mismatch without claiming success.

5. **Report.** Return the Scope identity, whether it was initialized or appended, and a concise statement of the recorded current State. The process is complete only at the verification criterion above.

The evidence boundary excludes old-conversation scans and external research. Host changes require their own explicit instruction; this Skill records context rather than creating host state.
