import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/sync/status_copy.dart';
import '../../../../core/sync/sync_status.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/banner_card.dart';
import '../../../../core/widgets/list_card.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../l10n/l10n.dart';
import '../../pending_changes/presentation/pending_providers.dart';
import '../../presentation/sync_now_button.dart';

/// The Sync tab's root: what the pill says right now, and the way to the two
/// detail screens.
class SyncHubScreen extends ConsumerWidget {
  const SyncHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final status = ref.watch(syncStatusProvider);
    final progress = ref.watch(syncProgressProvider);
    final pending = ref.watch(pendingCountProvider);
    final lastSynced = ref.watch(lastSyncedAtProvider).value;

    final variant = switch (status) {
      SyncStatusKind.online => BannerVariant.success,
      SyncStatusKind.offline => BannerVariant.warning,
      SyncStatusKind.syncing => BannerVariant.info,
    };

    return Scaffold(
      appBar: AppHeader(title: l.hubTitle, status: status),
      body: ListView(
        padding: const EdgeInsets.all(Tokens.pagePadding),
        children: [
          BannerCard(
            variant: variant,
            title: statusSentence(
              l,
              status,
              pending: progress?.total ?? pending,
            ),
            message: lastSynced == null
                ? l.notSyncedYet
                : l.lastSyncedAt(DateFormat.Hm(locale).format(lastSynced)),
          ),
          const SizedBox(height: Tokens.s16),
          ListCard(
            title: l.hubPendingRow(pending),
            subtitle: pending == 0 ? l.pendingEmpty : l.hubWaiting,
            trailing: const Icon(Icons.chevron_right, color: Tokens.inkMuted),
            onTap: () => context.push('/sync/pending'),
          ),
          const SizedBox(height: Tokens.s8),
          ListCard(
            title: l.historyTitle,
            subtitle: l.hubHistorySub,
            trailing: const Icon(Icons.chevron_right, color: Tokens.inkMuted),
            onTap: () => context.push('/sync/history'),
          ),
          const SizedBox(height: Tokens.s24),
          const SyncNowButton(),
        ],
      ),
    );
  }
}
