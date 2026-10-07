import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hodi/core/sync/sync_progress.dart';
import 'package:hodi/core/sync/sync_status.dart';
import 'package:hodi/core/widgets/status_pill.dart';

class _Online extends IsOnlineNotifier {
  _Online(this.v);
  final bool v;
  @override
  bool build() => v;
}

ProviderContainer containerWith({required bool online, int sendable = 0}) {
  final c = ProviderContainer(
    overrides: [
      isOnlineProvider.overrideWith(() => _Online(online)),
      sendableCountProvider.overrideWithValue(AsyncData(sendable)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('offline wins, even with unsent work', () {
    final c = containerWith(online: false, sendable: 3);
    expect(c.read(syncStatusProvider), SyncStatusKind.offline);
  });

  test('online with nothing to send → Online', () {
    expect(
      containerWith(online: true).read(syncStatusProvider),
      SyncStatusKind.online,
    );
  });

  test('online with unsent changes → Syncing', () {
    expect(
      containerWith(online: true, sendable: 2).read(syncStatusProvider),
      SyncStatusKind.syncing,
    );
  });

  test('a running sync → Syncing even if the count reads 0', () {
    final c = containerWith(online: true);
    c
        .read(syncProgressProvider.notifier)
        .set(const SyncProgress(done: 1, total: 3));
    expect(c.read(syncStatusProvider), SyncStatusKind.syncing);
  });

  test('losing the network mid-sync drops to Offline', () {
    final c = containerWith(online: false);
    c
        .read(syncProgressProvider.notifier)
        .set(const SyncProgress(done: 1, total: 3));
    expect(c.read(syncStatusProvider), SyncStatusKind.offline);
  });
}
