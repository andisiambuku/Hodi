import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../l10n/l10n.dart';

enum SyncStatusKind { online, offline, syncing }

/// The connectivity/sync pill shown in every header.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.kind});

  final SyncStatusKind kind;

  String labelFor(AppLocalizations l) => switch (kind) {
    SyncStatusKind.online => l.statusOnline,
    SyncStatusKind.offline => l.statusOffline,
    SyncStatusKind.syncing => l.statusSyncing,
  };

  Color get _bg => switch (kind) {
    SyncStatusKind.online => Tokens.primarySoft,
    SyncStatusKind.offline => Tokens.warningSoft,
    SyncStatusKind.syncing => Tokens.infoSoft,
  };

  Color get _dot => switch (kind) {
    SyncStatusKind.online => Tokens.primary,
    SyncStatusKind.offline => Tokens.warning,
    SyncStatusKind.syncing => Tokens.info,
  };

  Color get _text => switch (kind) {
    SyncStatusKind.online => Tokens.primary,
    SyncStatusKind.offline => Tokens.warningText,
    SyncStatusKind.syncing => Tokens.infoText,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final label = labelFor(l);
    return Semantics(
      label: l.statusPillSemantics(label),
      // A change (going offline, syncing) is announced by the screen reader.
      liveRegion: true,
      container: true,
      excludeSemantics: true,
      // The pill is header chrome next to the title, and its meaning is also
      // carried by the screen-reader label and the Home legend, so its text
      // stops growing at 1.3x rather than crowding the title out.
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.s12,
            vertical: Tokens.s8,
          ),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(Tokens.radiusPill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: _dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(label, style: Tokens.label.copyWith(color: _text)),
            ],
          ),
        ),
      ),
    );
  }
}
