import '../../l10n/l10n.dart';
import '../widgets/status_pill.dart';

/// The one-line meaning of each pill state, used by the Home legend and the
/// Sync hub so they never disagree.
String statusSentence(
  AppLocalizations l,
  SyncStatusKind kind, {
  int pending = 0,
}) => switch (kind) {
  SyncStatusKind.online => l.statusOnlineSentence,
  SyncStatusKind.offline => l.statusOfflineSentence,
  SyncStatusKind.syncing => l.statusSyncingSentence(pending),
};
