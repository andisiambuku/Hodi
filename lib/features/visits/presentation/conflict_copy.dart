import 'dart:convert';

import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/enums.dart';
import '../../../l10n/l10n.dart';

enum ConflictAction { reenterMine, keepNewer, keepMine, useTheirs, deleteIt }

typedef ConflictChoice = ({
  String label,
  ConflictAction action,
  String confirmation,
});

class ConflictCopy {
  const ConflictCopy({
    required this.title,
    required this.body,
    this.primary,
    this.secondary,
  });

  final String title;
  final String body;
  final ConflictChoice? primary;
  final ConflictChoice? secondary;
}

/// "38.4 °C", "08:15", "nothing". Dates arrive as ISO-8601 UTC strings.
String formatConflictValue(
  AppLocalizations l,
  String locale,
  String json,
  String unit,
) {
  final v = jsonDecode(json);
  if (v == null) return l.valueNothing;
  if (v == 'active') return l.statusActive;
  if (v == 'inactive') return l.statusInactive;
  var text = v.toString();
  if (v is String) {
    final d = DateTime.tryParse(v);
    if (d != null && v.contains('T')) {
      text = DateFormat.Hm(locale).format(d.toLocal());
    }
  }
  if (v is double && v == v.roundToDouble()) text = v.toStringAsFixed(1);
  return unit.isEmpty ? text : '$text $unit';
}

/// The words for a conflict card or merge notice, in the nurse's language.
/// Field names, nouns and values are translated at display time, because the
/// conflict row stores them as data.
ConflictCopy describeConflict(AppLocalizations l, String locale, Conflict c) {
  final local = formatConflictValue(l, locale, c.localValue, c.unit);
  final remote = formatConflictValue(l, locale, c.remoteValue, c.unit);
  final field = localizedFieldLabel(l, c.entityType, c.field, c.fieldLabel);
  final noun = localizedNoun(l, c.entityType);

  switch (c.kind) {
    case ConflictKind.replaced:
      return ConflictCopy(
        title: l.conflictReplacedTitle,
        body: l.conflictReplacedBody(
          c.subjectName,
          field,
          local,
          c.remoteSource,
          remote,
        ),
        primary: (
          label: l.btnReenter,
          action: ConflictAction.reenterMine,
          confirmation: l.confReentered,
        ),
        secondary: (
          label: l.btnKeepNewer,
          action: ConflictAction.keepNewer,
          confirmation: l.confKeptNewer,
        ),
      );
    case ConflictKind.localKept:
      return ConflictCopy(
        title: l.conflictKeptTitle,
        body: l.conflictKeptBody(
          c.subjectName,
          field,
          local,
          c.remoteSource,
          remote,
        ),
        primary: (
          label: l.btnKeepMine,
          action: ConflictAction.keepMine,
          confirmation: l.confKeptMine,
        ),
        secondary: (
          label: l.btnUseTheirs,
          action: ConflictAction.useTheirs,
          confirmation: l.confUsedTheirs(remote),
        ),
      );
    case ConflictKind.deletedRemotely:
      return ConflictCopy(
        title: l.conflictDeletedTitle,
        body: l.conflictDeletedBody(c.remoteSource, c.subjectName, noun),
        primary: (
          label: l.btnKeepMine,
          action: ConflictAction.keepMine,
          confirmation: l.confKeptVersion,
        ),
        secondary: (
          label: l.btnDeleteIt,
          action: ConflictAction.deleteIt,
          confirmation: l.confDeleted,
        ),
      );
    case ConflictKind.merged:
      return ConflictCopy(
        title: l.conflictMergedTitle(c.remoteSource),
        body: l.conflictMergedBody(c.subjectName, noun),
      );
  }
}
