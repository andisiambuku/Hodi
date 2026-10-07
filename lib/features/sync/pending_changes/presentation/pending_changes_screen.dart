import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/db/app_database.dart';
import '../../../../core/db/enums.dart';
import '../../../../core/sync/sync_status.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/banner_card.dart';
import '../../../../core/widgets/list_card.dart';
import '../../../../l10n/l10n.dart';
import '../../presentation/sync_now_button.dart';
import 'pending_providers.dart';

/// Screen 3: what is waiting to be sent, in send order.
class PendingChangesScreen extends ConsumerWidget {
  const PendingChangesScreen({super.key, this.clock});

  /// Injectable for tests.
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final entries = ref.watch(pendingEntriesProvider).value ?? const [];
    final now = (clock ?? DateTime.now)();
    final lastSynced = ref.watch(lastSyncedAtProvider).value;

    // Header banner, then one lazily built row per change (a nurse can come
    // back from a day offline with hundreds), then the footnote and button.
    final headCount = 1;
    final tailCount = entries.isEmpty ? 1 : 2;

    return Scaffold(
      appBar: AppHeader(
        title: l.pendingTitle,
        status: ref.watch(syncStatusProvider),
        onBack: () => context.pop(),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(Tokens.pagePadding),
        itemCount: headCount + entries.length + tailCount,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: Tokens.s16),
              child: entries.isEmpty
                  ? BannerCard(
                      variant: BannerVariant.success,
                      title: l.pendingEmpty,
                      message: lastSynced == null
                          ? null
                          : l.lastSyncedAt(
                              DateFormat.Hm(locale).format(lastSynced),
                            ),
                    )
                  : BannerCard(
                      variant: BannerVariant.warning,
                      title: l.pendingBannerTitle(entries.length),
                      message: l.pendingOldest(
                        relativeTimeL(l, entries.first.createdAt, now),
                      ),
                    ),
            );
          }
          final entryIndex = i - headCount;
          if (entryIndex < entries.length) {
            return Padding(
              padding: const EdgeInsets.only(bottom: Tokens.s8),
              child: _EntryCard(entry: entries[entryIndex]),
            );
          }
          final tailIndex = entryIndex - entries.length;
          if (entries.isNotEmpty && tailIndex == 0) {
            return Padding(
              padding: const EdgeInsets.only(top: Tokens.s8),
              child: Text(l.pendingFootnote, style: Tokens.caption),
            );
          }
          return const Padding(
            padding: EdgeInsets.only(top: Tokens.s24),
            child: SyncNowButton(),
          );
        },
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final OutboxEntry entry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final failed = entry.status == OutboxStatus.failed;
    final (icon, color, title) = switch (entry.op) {
      ChangeOp.added => (Icons.add, Tokens.primary, l.opAdded),
      ChangeOp.edited => (Icons.edit_outlined, Tokens.info, l.opEdited),
      ChangeOp.deleted => (Icons.remove, Tokens.danger, l.opDeleted),
    };
    final label = localizedEntityLabel(l, entry.entityType, entry.label);
    return Semantics(
      label:
          '${l.entrySemantics(title, label)}${failed ? '. ${l.entryRejectedSemantics}' : ''}',
      excludeSemantics: true,
      child: ListCard(
        leading: Icon(icon, color: color),
        title: title,
        subtitle: failed ? '$label · ✕ ${l.entryRejected}' : label,
        borderColor: failed ? Tokens.danger : null,
        trailing: Text(
          DateFormat.Hm(
            Localizations.localeOf(context).toString(),
          ).format(entry.createdAt),
          style: Tokens.caption,
        ),
      ),
    );
  }
}
