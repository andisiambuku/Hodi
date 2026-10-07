import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../core/sync/sync_summary.dart';
import 'app_localizations.dart';

export 'app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Visit types are stored in English (they are data). Known ones are shown
/// in the nurse's language; anything else is shown as it was entered.
String localizedVisitType(AppLocalizations l, String raw) => switch (raw) {
  'Antenatal check' => l.visitTypeAntenatal,
  'BP follow-up' => l.visitTypeBp,
  'Child immunisation' => l.visitTypeImmunisation,
  'Malaria test' => l.visitTypeMalaria,
  'Home visit: new household' => l.visitTypeHome,
  'Diabetes review' => l.visitTypeDiabetes,
  _ => raw,
};

/// "Visit: Grace Njeri" is stored as written; show its prefix translated.
String localizedEntityLabel(
  AppLocalizations l,
  String entityType,
  String stored,
) {
  final i = stored.indexOf(': ');
  final name = i < 0 ? stored : stored.substring(i + 2);
  final prefix = switch (entityType) {
    'visit' => l.labelVisit,
    'vitals' => l.labelVitals,
    'patient' => l.labelPatient,
    'household' => l.labelHousehold,
    _ => null,
  };
  return prefix == null ? stored : '$prefix: $name';
}

String localizedNoun(AppLocalizations l, String entityType) =>
    switch (entityType) {
      'visit' => l.nounVisit,
      'vitals' => l.nounVitals,
      'patient' => l.nounPatient,
      'household' => l.nounHousehold,
      _ => l.nounPatient,
    };

/// Field names are stored in English with the conflict; show them translated.
String localizedFieldLabel(
  AppLocalizations l,
  String entityType,
  String field,
  String fallback,
) => switch ('$entityType.$field') {
  'vitals.temperatureC' => l.fieldTemperature,
  'vitals.systolic' => l.fieldSystolic,
  'vitals.diastolic' => l.fieldDiastolic,
  'visit.visitType' => l.fieldVisitType,
  'visit.scheduledAt' => l.fieldVisitTime,
  'visit.completedAt' => l.fieldCompletionTime,
  'visit.patientName' => l.fieldPatientName,
  'patient.fullName' => l.fieldName,
  'patient.householdId' => l.fieldHousehold,
  'patient.phoneNumber' => l.fieldPhoneNumber,
  'patient.accountStatus' => l.fieldAccountStatus,
  'household.headName' => l.fieldHeadOfHousehold,
  'household.location' => l.fieldLocation,
  _ => fallback,
};

String relativeTimeL(AppLocalizations l, DateTime then, DateTime now) {
  final d = now.difference(then);
  if (d.inSeconds < 60) return l.relJustNow;
  if (d.inMinutes < 60) return l.relMinutes(d.inMinutes);
  if (d.inHours < 24) return l.relHours(d.inHours);
  return l.relDays(d.inDays);
}

/// A sync_log summary in the current language. Text that isn't one of ours
/// (older rows) is shown unchanged.
String localizedSummary(AppLocalizations l, String raw) {
  final s = SyncSummary.parse(raw);
  if (s == null) return raw;
  switch (s.kind) {
    case SummaryKind.nothing:
      return l.summaryNothing;
    case SummaryKind.network:
      return l.errNetwork;
    case SummaryKind.server:
      return l.errServer;
    case SummaryKind.local:
      return l.errLocal;
    case SummaryKind.interrupted:
      return l.errInterrupted;
    case SummaryKind.synced:
      return [
        l.summarySent(s.sent, s.received),
        if (s.merged > 0) l.summaryExtraMerged(s.merged),
        if (s.review > 0) l.summaryExtraReview(s.review),
      ].join(', ');
  }
}

/// "Today 11:58", "Yesterday 09:10", "Mon 17:20" (within a week), else a date.
String formatRunTimeL(
  AppLocalizations l,
  String locale,
  DateTime t,
  DateTime now,
) {
  final hm = DateFormat.Hm(locale).format(t);
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return l.runTimeToday(hm);
  if (diff == 1) return l.runTimeYesterday(hm);
  if (diff < 7) return l.runTimeWeekday(DateFormat.E(locale).format(t), hm);
  return l.runTimeDate(DateFormat('d MMM', locale).format(t), hm);
}
