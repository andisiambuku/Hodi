import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_providers.dart';
import '../../profile/domain/nurse_profile.dart';
import '../domain/home_logic.dart';

/// "Now", injectable so screens that depend on the time of day are testable.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Ticks every minute so "next visit" moves on by itself.
final minuteTickProvider = StreamProvider<DateTime>((ref) {
  final now = ref.watch(clockProvider);
  return Stream.periodic(const Duration(minutes: 1), (_) => now());
});

final nurseProfileProvider = Provider<NurseProfile>((ref) => demoNurse);

const _firstRunKey = 'first_run_at';
const _legendDismissedKey = 'legend_dismissed';

/// Whether to show the "What the status pill means" section.
final legendVisibleProvider =
    AsyncNotifierProvider<LegendVisibleNotifier, bool>(
      LegendVisibleNotifier.new,
    );

class LegendVisibleNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final meta = ref.read(syncMetaRepositoryProvider);
    final now = ref.read(clockProvider)();
    var first = DateTime.tryParse(await meta.readValue(_firstRunKey) ?? '');
    if (first == null) {
      first = now;
      await meta.writeValue(_firstRunKey, now.toIso8601String());
    }
    final dismissed = await meta.readValue(_legendDismissedKey) == '1';
    return legendVisibleFor(firstRun: first, dismissed: dismissed, now: now);
  }

  Future<void> dismiss() async {
    state = const AsyncData(false);
    await ref
        .read(syncMetaRepositoryProvider)
        .writeValue(_legendDismissedKey, '1');
  }
}
