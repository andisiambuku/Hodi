import 'dart:convert';

enum SummaryKind { synced, nothing, network, server, local, interrupted }

/// What a sync run did, stored as data so the history can be shown in the
/// nurse's language whenever it is read (not frozen in the language that was
/// active when the sync ran).
class SyncSummary {
  const SyncSummary(
    this.kind, {
    this.sent = 0,
    this.received = 0,
    this.merged = 0,
    this.review = 0,
  });

  final SummaryKind kind;
  final int sent;
  final int received;
  final int merged;
  final int review;

  /// Stored in `sync_log.summary`.
  String encode() => jsonEncode({
    'k': kind.name,
    if (sent > 0) 's': sent,
    if (received > 0) 'r': received,
    if (merged > 0) 'm': merged,
    if (review > 0) 'v': review,
  });

  /// Null for text that isn't ours (older rows, tests): show it as is.
  static SyncSummary? parse(String raw) {
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return null;
      final kind = SummaryKind.values.asNameMap()[j['k']];
      if (kind == null) return null;
      return SyncSummary(
        kind,
        sent: (j['s'] as int?) ?? 0,
        received: (j['r'] as int?) ?? 0,
        merged: (j['m'] as int?) ?? 0,
        review: (j['v'] as int?) ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// English, for logs and tests. The UI localizes with the l10n helpers.
  String get english {
    switch (kind) {
      case SummaryKind.nothing:
        return 'Nothing new to sync';
      case SummaryKind.network:
        return "Couldn't reach the server. Will retry.";
      case SummaryKind.server:
        return "Server didn't respond. Will retry.";
      case SummaryKind.local:
        return 'Something went wrong on this phone. Will retry.';
      case SummaryKind.interrupted:
        return 'Sync was interrupted. Will retry.';
      case SummaryKind.synced:
        final changes = '$sent change${sent == 1 ? '' : 's'}';
        final extras = [
          if (merged > 0) '$merged merged',
          if (review > 0) '$review to review',
        ];
        return ['$changes sent, $received received', ...extras].join(', ');
    }
  }
}
