enum SyncState { synced, pending, syncing, failed, conflict }

enum ChangeOp { added, edited, deleted }

enum OutboxStatus { queued, inFlight, acked, failed }

enum SyncRunResult { done, merged, failed }

enum ConflictKind {
  /// Both edited the same field; the newer remote value was kept and the
  /// nurse's value is stored here.
  replaced,

  /// Both edited different fields; both edits were kept. A notice, not a
  /// problem. `resolved` means "dismissed".
  merged,

  /// Same clinical field, the nurse's value was newer and was kept
  /// automatically. Clinical values never change without being surfaced.
  localKept,

  /// The record was deleted elsewhere but the nurse had edited it, so it was
  /// kept (re-created) for review.
  deletedRemotely,
}
