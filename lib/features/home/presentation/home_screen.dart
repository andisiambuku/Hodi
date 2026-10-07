import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/db/app_database.dart';
import '../../../core/sync/status_copy.dart';
import '../../../core/sync/sync_status.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/avatar_initial.dart';
import '../../../core/widgets/list_card.dart';
import '../../../core/widgets/status_pill.dart';
import '../../sync/pending_changes/presentation/pending_providers.dart';
import '../../visits/presentation/visit_providers.dart';
import '../../../l10n/l10n.dart';
import '../domain/home_logic.dart';
import 'home_providers.dart';

/// Screen 1: greeting, the day at a glance, what the pill means, next visit.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(minuteTickProvider); // re-evaluate "next visit" each minute
    final now = ref.watch(clockProvider)();
    final nurse = ref.watch(nurseProfileProvider);
    // Until the local DB has answered once, say nothing about the day rather
    // than something false like "0 visits today".
    final visitsAsync = ref.watch(todaysVisitsProvider);
    final loaded = visitsAsync.hasValue;
    final visits = visitsAsync.value ?? const <Visit>[];
    final pending = ref.watch(pendingCountProvider);
    final online = ref.watch(isOnlineProvider);
    final legendVisible = ref.watch(legendVisibleProvider).value ?? false;
    final next = nextVisitOf(visits, now);
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final greeting = switch (greetingPeriodFor(now)) {
      GreetingPeriod.morning => l.greetingMorning,
      GreetingPeriod.afternoon => l.greetingAfternoon,
      GreetingPeriod.evening => l.greetingEvening,
    };

    return Scaffold(
      appBar: AppHeader(
        title: l.appTitle,
        status: ref.watch(syncStatusProvider),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Tokens.pagePadding),
        children: [
          Semantics(
            header: true,
            child: Text(
              l.homeGreeting(greeting, nurse.firstName),
              style: Tokens.title,
            ),
          ),
          Text(
            l.homeSubtitle(
              nurse.subCounty,
              DateFormat.EEEE(locale).format(now),
            ),
            style: Tokens.caption,
          ),
          const SizedBox(height: Tokens.s16),
          if (loaded) ...[
            _HeroCard(
              visitCount: visits.length,
              pending: pending,
              online: online,
            ),
            const SizedBox(height: Tokens.s24),
          ],
          if (legendVisible) ...[
            const _Legend(),
            const SizedBox(height: Tokens.s24),
          ],
          if (loaded) ...[
            Text(l.homeNextVisit, style: Tokens.heading),
            const SizedBox(height: Tokens.s12),
            if (next == null)
              Text(l.homeNoMoreVisits, style: Tokens.caption)
            else
              ListCard(
                leading: AvatarInitial(name: next.patientName),
                title: next.patientName,
                subtitle:
                    '${localizedVisitType(l, next.visitType)} · ${DateFormat.Hm(locale).format(next.scheduledAt)}',
                onTap: () => context.push('/visits/${next.id}'),
              ),
            const SizedBox(height: Tokens.s12),
            ListCard(
              title: l.homeTodaysVisits,
              subtitle: l.totalCount(visits.length),
              trailing: const Icon(Icons.chevron_right, color: Tokens.inkMuted),
              onTap: () => context.push('/visits/today'),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.visitCount,
    required this.pending,
    required this.online,
  });

  final int visitCount;
  final int pending;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Tokens.s24),
      decoration: BoxDecoration(
        color: Tokens.ink,
        borderRadius: BorderRadius.circular(Tokens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.homeVisitsToday(visitCount),
            style: Tokens.title.copyWith(color: Colors.white),
          ),
          if (pending > 0) ...[
            const SizedBox(height: Tokens.s8),
            Text(
              context.l10n.homePendingLine(pending),
              style: Tokens.body.copyWith(color: Colors.white70),
            ),
          ],
          if (!online) ...[
            const SizedBox(height: Tokens.s8),
            Text(
              context.l10n.homeKeepWorking,
              style: Tokens.bodyStrong.copyWith(color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}

class _Legend extends ConsumerWidget {
  const _Legend();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(syncProgressProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(context.l10n.legendTitle, style: Tokens.heading),
            ),
            TextButton(
              onPressed: () =>
                  ref.read(legendVisibleProvider.notifier).dismiss(),
              child: Text(context.l10n.legendHide),
            ),
          ],
        ),
        const SizedBox(height: Tokens.s8),
        _LegendCard(
          kind: SyncStatusKind.online,
          sentence: statusSentence(context.l10n, SyncStatusKind.online),
        ),
        const SizedBox(height: Tokens.s8),
        _LegendCard(
          kind: SyncStatusKind.offline,
          sentence: statusSentence(context.l10n, SyncStatusKind.offline),
        ),
        const SizedBox(height: Tokens.s8),
        // Live while a sync runs; a static example otherwise.
        _LegendCard(
          kind: SyncStatusKind.syncing,
          sentence: statusSentence(
            context.l10n,
            SyncStatusKind.syncing,
            pending: progress?.total ?? 3,
          ),
          done: progress?.done ?? 2,
          total: progress?.total ?? 3,
        ),
      ],
    );
  }
}

class _LegendCard extends StatelessWidget {
  const _LegendCard({
    required this.kind,
    required this.sentence,
    this.done,
    this.total,
  });

  final SyncStatusKind kind;
  final String sentence;
  final int? done;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final hasProgress = done != null && total != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Tokens.s16),
      decoration: BoxDecoration(
        color: Tokens.surface,
        borderRadius: BorderRadius.circular(Tokens.radiusCard),
        border: Border.all(color: Tokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wraps under the pill when the sentence is long (Swahili, big text).
          Wrap(
            spacing: Tokens.s12,
            runSpacing: Tokens.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusPill(kind: kind),
              Text(sentence, style: Tokens.body),
            ],
          ),
          if (hasProgress) ...[
            const SizedBox(height: Tokens.s12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Tokens.radiusPill),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : done! / total!,
                      minHeight: 8,
                      color: Tokens.info,
                      backgroundColor: Tokens.infoSoft,
                    ),
                  ),
                ),
                const SizedBox(width: Tokens.s12),
                Flexible(
                  child: Text(
                    context.l10n.progressOf(done!, total!),
                    style: Tokens.label.copyWith(color: Tokens.infoText),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
