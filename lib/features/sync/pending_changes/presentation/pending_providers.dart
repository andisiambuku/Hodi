import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/sync/sync_providers.dart';

/// Unacked outbox entries, oldest first.
final pendingEntriesProvider = StreamProvider<List<OutboxEntry>>(
  (ref) => ref.watch(outboxRepositoryProvider).watchPending(),
);

/// The one pending number. Home, the Sync hub and Pending changes all show
/// this, so they can't disagree. It counts changes (outbox entries), not
/// records: three visits with five edits between them is "5 changes".
final pendingCountProvider = Provider<int>(
  (ref) => ref.watch(pendingEntriesProvider).value?.length ?? 0,
);
