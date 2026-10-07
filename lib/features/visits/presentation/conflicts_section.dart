import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/enums.dart';
import '../../../core/sync/conflict_repository.dart';
import '../../../core/sync/sync_engine_provider.dart';
import '../../../core/widgets/banner_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/l10n.dart';
import 'conflict_copy.dart';
import 'conflict_providers.dart';

/// Merge banners (dark, dismissible) and conflict cards (red), above the
/// visit list. Empty when there is nothing to act on.
class ConflictsSection extends ConsumerWidget {
  const ConflictsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(unresolvedConflictsProvider).value ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();
    final repo = ref.read(conflictRepositoryProvider);

    return Column(
      children: [
        for (final c in items)
          Padding(
            padding: const EdgeInsets.only(bottom: Tokens.s12),
            child: c.kind == ConflictKind.merged
                ? _mergeBanner(context, c, repo)
                : _conflictCard(context, c, repo),
          ),
      ],
    );
  }

  Widget _mergeBanner(
    BuildContext context,
    Conflict c,
    ConflictRepository repo,
  ) {
    final copy = describeConflict(
      context.l10n,
      Localizations.localeOf(context).toString(),
      c,
    );
    return BannerCard(
      variant: BannerVariant.dark,
      title: copy.title,
      message: copy.body,
      onDismiss: () => repo.accept(c.id),
    );
  }

  Widget _conflictCard(
    BuildContext context,
    Conflict c,
    ConflictRepository repo,
  ) {
    final copy = describeConflict(
      context.l10n,
      Localizations.localeOf(context).toString(),
      c,
    );

    Future<void> act(ConflictAction a, String confirmation) async {
      switch (a) {
        case ConflictAction.reenterMine:
          await repo.reenterMine(c.id);
        case ConflictAction.useTheirs:
          await repo.useTheirs(c.id);
        case ConflictAction.deleteIt:
          await repo.deleteIt(c.id);
        case ConflictAction.keepNewer || ConflictAction.keepMine:
          await repo.accept(c.id);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(confirmation)));
      }
    }

    return BannerCard(
      variant: BannerVariant.error,
      title: copy.title,
      message: copy.body,
      actions: [
        if (copy.primary case final p?)
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: p.label,
              style: PrimaryButtonStyle.filledDanger,
              onPressed: () => act(p.action, p.confirmation),
            ),
          ),
        if (copy.secondary case final s?)
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: s.label,
              style: PrimaryButtonStyle.outlinedDanger,
              onPressed: () => act(s.action, s.confirmation),
            ),
          ),
      ],
    );
  }
}
