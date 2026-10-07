import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../l10n/l10n.dart';

enum SyncBadgeKind { synced, waiting, needsReview, failed }

/// ✓ Synced / ◷ Waiting / ⚠ Needs review / ✕ Failed.
class SyncBadge extends StatelessWidget {
  const SyncBadge({super.key, required this.kind});

  final SyncBadgeKind kind;

  String get _glyph => switch (kind) {
    SyncBadgeKind.synced => '✓',
    SyncBadgeKind.waiting => '◷',
    SyncBadgeKind.needsReview => '⚠',
    SyncBadgeKind.failed => '✕',
  };

  String labelFor(AppLocalizations l) => switch (kind) {
    SyncBadgeKind.synced => l.badgeSynced,
    SyncBadgeKind.waiting => l.badgeWaiting,
    SyncBadgeKind.needsReview => l.badgeNeedsReview,
    SyncBadgeKind.failed => l.badgeFailed,
  };

  Color get _color => switch (kind) {
    SyncBadgeKind.synced => Tokens.primary,
    SyncBadgeKind.waiting => Tokens.warning,
    SyncBadgeKind.needsReview => Tokens.danger,
    SyncBadgeKind.failed => Tokens.dangerText,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final label = labelFor(l);
    return Semantics(
      label: l.badgeSemantics(label),
      excludeSemantics: true,
      child: Text(
        '$_glyph $label',
        style: Tokens.label.copyWith(color: _color),
      ),
    );
  }
}
