import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/enums.dart';
import '../../../core/db/providers.dart';
import '../../../core/sync/sync_status.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/avatar_initial.dart';
import '../../../core/widgets/banner_card.dart';
import '../../../core/widgets/list_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/sync_badge.dart';
import '../../../l10n/l10n.dart';
import 'conflicts_section.dart';
import 'visit_providers.dart';

/// Screen 2: today's visits, read straight from the local database.
class VisitsScreen extends ConsumerWidget {
  const VisitsScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final visits = ref.watch(todaysVisitsProvider);
    final recovered = ref.watch(dbRecoveredProvider);
    final online = ref.watch(isOnlineProvider);
    final lastSynced = ref.watch(lastSyncedAtProvider).value;

    return Scaffold(
      appBar: AppHeader(
        title: l.visitsTitle,
        status: ref.watch(syncStatusProvider),
        onBack: onBack,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(Tokens.pagePadding),
              children: [
                if (!online) ...[
                  BannerCard(
                    variant: BannerVariant.success,
                    title: l.offlineBannerTitle,
                    message: lastSynced == null
                        ? l.notSyncedYet
                        : l.lastSyncedAt(
                            DateFormat.Hm(locale).format(lastSynced),
                          ),
                  ),
                  const SizedBox(height: Tokens.s16),
                ],
                if (recovered) ...[
                  BannerCard(
                    variant: BannerVariant.warning,
                    title: l.dbRecoveredTitle,
                    message: l.dbRecoveredBody,
                    onDismiss: () =>
                        ref.read(dbRecoveredProvider.notifier).dismiss(),
                  ),
                  const SizedBox(height: Tokens.s16),
                ],
                const ConflictsSection(),
                // The local DB is the source of truth; no spinner while it answers.
                ...switch (visits) {
                  AsyncData(:final value) => _list(context, value),
                  AsyncError() => [
                    Text(l.visitsReadError, style: Tokens.caption),
                  ],
                  _ => const <Widget>[],
                },
              ],
            ),
          ),
          // Pinned so it is always one thumb-tap away, however long the list.
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Tokens.pagePadding,
                Tokens.s8,
                Tokens.pagePadding,
                Tokens.s16,
              ),
              child: PrimaryButton(
                label: l.recordNewVisit,
                onPressed: () => context.push('/visits/new'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _list(BuildContext context, List<Visit> visits) {
    final l = context.l10n;
    final time = DateFormat.Hm(Localizations.localeOf(context).toString());
    return [
      Row(
        children: [
          Expanded(child: Text(l.homeTodaysVisits, style: Tokens.heading)),
          Text(l.totalCount(visits.length), style: Tokens.caption),
        ],
      ),
      const SizedBox(height: Tokens.s12),
      if (visits.isEmpty) Text(l.visitsNone, style: Tokens.caption),
      for (final v in visits)
        Padding(
          padding: const EdgeInsets.only(bottom: Tokens.s8),
          child: ListCard(
            leading: AvatarInitial(name: v.patientName),
            title: v.patientName,
            subtitle: localizedVisitType(l, v.visitType),
            semanticLabel: l.visitCardSemantics(
              v.patientName,
              localizedVisitType(l, v.visitType),
              time.format(v.scheduledAt),
              SyncBadge(kind: badgeFor(v.syncState)).labelFor(l),
            ),
            onTap: () => context.push('/visits/${v.id}'),
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(time.format(v.scheduledAt), style: Tokens.caption),
                SyncBadge(kind: badgeFor(v.syncState)),
              ],
            ),
          ),
        ),
    ];
  }
}

SyncBadgeKind badgeFor(SyncState s) => switch (s) {
  SyncState.synced => SyncBadgeKind.synced,
  SyncState.pending || SyncState.syncing => SyncBadgeKind.waiting,
  SyncState.conflict => SyncBadgeKind.needsReview,
  SyncState.failed => SyncBadgeKind.failed,
};
