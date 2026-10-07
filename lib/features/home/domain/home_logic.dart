import '../../../core/db/app_database.dart';

enum GreetingPeriod { morning, afternoon, evening }

/// Morning before noon, afternoon before 17:00, else evening. The words come
/// from the localizations.
GreetingPeriod greetingPeriodFor(DateTime now) {
  if (now.hour < 12) return GreetingPeriod.morning;
  if (now.hour < 17) return GreetingPeriod.afternoon;
  return GreetingPeriod.evening;
}

/// The first visit today that is still ahead of [now] and not completed.
/// [todays] must already be ordered soonest first.
Visit? nextVisitOf(List<Visit> todays, DateTime now) {
  for (final v in todays) {
    if (v.completedAt == null && v.scheduledAt.isAfter(now)) return v;
  }
  return null;
}

/// The "what the pill means" legend is onboarding: shown for the first
/// [legendDays] days, or until the nurse hides it.
const legendDays = 7;

bool legendVisibleFor({
  required DateTime firstRun,
  required bool dismissed,
  required DateTime now,
}) => !dismissed && now.difference(firstRun) < const Duration(days: legendDays);
