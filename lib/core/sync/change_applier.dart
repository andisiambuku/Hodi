import '../network/api_client.dart';

class ApplyOutcome {
  const ApplyOutcome({this.merged = false, this.conflicts = 0});

  /// Local and remote edits to different fields were both kept.
  final bool merged;

  /// Conflict cards raised (replaced / kept / deleted-elsewhere).
  final int conflicts;

  static const plain = ApplyOutcome();
}

/// Applies one change from the server to the local database.
abstract class ChangeApplier {
  Future<ApplyOutcome> apply(RemoteChange change);
}
