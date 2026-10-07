import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/sync/sync_engine_provider.dart';

/// Merge notices and conflict cards the nurse hasn't acted on. Persisted, so
/// they survive restarts.
final unresolvedConflictsProvider = StreamProvider<List<Conflict>>(
  (ref) => ref.watch(conflictRepositoryProvider).watchUnresolved(),
);
