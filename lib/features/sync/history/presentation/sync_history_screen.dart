import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/db/app_database.dart';
import '../../../../core/db/enums.dart';
import '../../../../core/sync/sync_log_repository.dart';
import '../../../../core/sync/sync_providers.dart';
import '../../../../core/sync/sync_status.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/list_card.dart';
import '../../../../core/widgets/stat_tile.dart';
import '../../../../l10n/l10n.dart';

final syncRunsProvider = StreamProvider<List<SyncRun>>(
  (ref) => ref.watch(syncLogRepositoryProvider).watchRecent(),
);

final syncStatsProvider = StreamProvider<SyncStats>(
  (ref) => ref.watch(syncLogRepositoryProvider).watchStats(),
);

/// Screen 5: every sync attempt, newest first, in plain language.
class SyncHistoryScreen extends ConsumerWidget {
  const SyncHistoryScreen({super.key, this.clock});

  /// Injectable for tests.
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final runs = ref.watch(syncRunsProvider).value ?? const <SyncRun>[];
    final stats =
        ref.watch(syncStatsProvider).value ??
        const SyncStats(total: 0, done: 0, merged: 0, failed: 0);
    final now = (clock ?? DateTime.now)();

    // Four tiles fit in a row at normal text size; at large sizes (and long
    // words like "Usawazishaji") they stack full width so labels stay whole.
    final large = MediaQuery.textScalerOf(context).scale(14) > 20;
    final tiles = [
      StatTile(label: l.statSyncs, value: stats.total),
      StatTile(
        label: l.statDone,
        value: stats.done,
        valueColor: Tokens.primary,
      ),
      StatTile(
        label: l.statMerged,
        value: stats.merged,
        valueColor: Tokens.warning,
      ),
      StatTile(
        label: l.statFailed,
        value: stats.failed,
        valueColor: Tokens.danger,
      ),
    ];

    return Scaffold(
      appBar: AppHeader(
        title: l.historyTitle,
        status: ref.watch(syncStatusProvider),
        onBack: () => context.pop(),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(Tokens.pagePadding),
        itemCount: 3 + runs.length,
        itemBuilder: (context, i) {
          if (i == 0) {
            return large
                ? Wrap(
                    spacing: Tokens.s8,
                    runSpacing: Tokens.s8,
                    children: [
                      for (final t in tiles)
                        SizedBox(width: double.infinity, child: t),
                    ],
                  )
                : Row(
                    children: [
                      for (final (j, t) in tiles.indexed) ...[
                        if (j > 0) const SizedBox(width: Tokens.s8),
                        Expanded(child: t),
                      ],
                    ],
                  );
          }
          if (i == 1) {
            return Padding(
              padding: const EdgeInsets.only(
                top: Tokens.s24,
                bottom: Tokens.s12,
              ),
              child: Text(l.historyRecent, style: Tokens.heading),
            );
          }
          if (i == 2) {
            return runs.isEmpty
                ? Text(l.historyNone, style: Tokens.caption)
                : const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: Tokens.s8),
            child: _RunCard(run: runs[i - 3], now: now),
          );
        },
      ),
    );
  }
}

class _RunCard extends StatelessWidget {
  const _RunCard({required this.run, required this.now});

  final SyncRun run;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (title, chip, fg, bg) = switch (run.result) {
      SyncRunResult.done => (
        l.runComplete,
        l.statDone,
        Tokens.primary,
        Tokens.primarySoft,
      ),
      SyncRunResult.merged => (
        l.runMerge,
        l.statMerged,
        Tokens.warningText,
        Tokens.warningSoft,
      ),
      SyncRunResult.failed => (
        l.runFailed,
        l.statFailed,
        Tokens.dangerText,
        Tokens.dangerSoft,
      ),
    };
    final locale = Localizations.localeOf(context).toString();
    final when = formatRunTimeL(l, locale, run.startedAt, now);
    final summary = localizedSummary(l, run.summary);
    return ListCard(
      title: title,
      subtitle: '$summary\n$when',
      semanticLabel: l.runSemantics(title, summary, when, chip),
      // The chip repeats what the title says, so it stops growing at 1.3x
      // instead of squeezing the summary text into a one-word column.
      trailing: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.s12,
            vertical: Tokens.s4,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(Tokens.radiusPill),
          ),
          child: Text(chip, style: Tokens.label.copyWith(color: fg)),
        ),
      ),
    );
  }
}
