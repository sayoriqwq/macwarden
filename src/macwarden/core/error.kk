module macwarden/core/error

pub type domain-error
  InvalidRecordId
  InvalidScopeId
  BlankContext
  BlankState
  BlankReason
  BlankChange
  StructuralHeading
  MalformedRecord
  MalformedReference
  EmptyCapture
  EmptyBefore
  EmptyAfter
  DuplicateRecord(selector : string)
  DuplicateAuthorityRecord(selector : string)
  RecordConflict(selector : string)
  RecordIdentityMismatch(selector : string)
  MissingRecord(selector : string)
  MissingObservation(id : string)
  MalformedLegacyScopeLog(scope : string)
  LegacyScopeMismatch(scope : string)

pub fun render-error(err : domain-error) : string
  match err
    InvalidRecordId -> "record ID must be nonblank and file-safe"
    InvalidScopeId -> "scope ID must be nonblank and file-safe"
    BlankContext -> "Context body must be nonblank"
    BlankState -> "State body must be nonblank"
    BlankReason -> "Reason body must be nonblank"
    BlankChange -> "Change body must be nonblank"
    StructuralHeading -> "body contains a reserved structural line"
    MalformedRecord -> "malformed Macwarden record"
    MalformedReference -> "observation references must use '- ID', one per line"
    EmptyCapture -> "capture draft must contain at least one record"
    EmptyBefore -> "Transition Before must contain at least one Observation ID"
    EmptyAfter -> "Transition After must contain at least one Observation ID"
    DuplicateRecord(selector) -> "duplicate record in capture draft: " ++ selector
    DuplicateAuthorityRecord(selector) -> "duplicate authority record: " ++ selector
    RecordConflict(selector) -> "append-only record conflict: " ++ selector
    RecordIdentityMismatch(selector) -> "record identity does not match its path: " ++ selector
    MissingRecord(selector) -> "record does not exist: " ++ selector
    MissingObservation(id) -> "Transition references a missing Observation: " ++ id
    MalformedLegacyScopeLog(scope) -> "malformed legacy ScopeLog: " ++ scope
    LegacyScopeMismatch(scope) -> "legacy ScopeLog identity does not match its path: " ++ scope
