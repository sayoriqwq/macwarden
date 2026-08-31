# Macwarden domain context

Macwarden records immutable observations of mutable host state and the real transitions that connect them.

## Scope

A Scope is the stable question under observation. It is independent of App boundaries, current values, implementations, tasks, and software versions. Facts belong to separate Scopes when they can change independently and have independent readback boundaries.

## Observation

```text
Observation = ObservationId + ScopeId + Context + State
```

An Observation is an evidence-backed state node at one time boundary. It is immutable and may exist without a Transition, such as an initial inventory or later verification.

Context records when, why, and from what evidence the State entered the authority. It attributes observed, reported, sourced, inferred, and unknown claims.

State records only what was true at that boundary. It does not contain the reason for changing, the process used, or recovery instructions.

## Transition

```text
Transition
  = TransitionId
  + Before: ObservationId[]
  + Reason
  + Change
  + After: ObservationId[]
```

A Transition is one real migration edge. It may connect Observations from multiple Scopes. Before and After reference the same Observation structure; After contains only results established or changed by the Transition.

Reason explains why the previous state was left. Change records what actually happened between the boundaries, including affected targets, consequential operations, readbacks, temporary or durable effects, retained materials, evidence, and relevant provenance. Change is historical evidence, not a replay or recovery program.

## Authority

The authority is append-only. Existing identities and payloads cannot be replaced. A capture is an operation that validates and appends records; it is not a persisted domain object.

Macwarden does not infer a current state from record order. Current host work starts with fresh readback. Revert and recovery are new work that may append another Transition; they are not fields in the model.
