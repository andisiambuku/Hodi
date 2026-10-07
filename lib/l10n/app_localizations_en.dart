// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Hodi';

  @override
  String get navVisits => 'Visits';

  @override
  String get navPatients => 'Patients';

  @override
  String get navSync => 'Sync';

  @override
  String get navProfile => 'Profile';

  @override
  String get back => 'Back';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get statusOnline => 'Online';

  @override
  String get statusOffline => 'Offline';

  @override
  String get statusSyncing => 'Syncing';

  @override
  String statusPillSemantics(String status) {
    return 'Connection status: $status';
  }

  @override
  String get statusOnlineSentence => 'All changes are saved to the server';

  @override
  String get statusOfflineSentence => 'Changes are saved on this phone';

  @override
  String statusSyncingSentence(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes',
      one: '1 change',
    );
    return 'Sending $_temp0 to the server';
  }

  @override
  String get badgeSynced => 'Synced';

  @override
  String get badgeWaiting => 'Waiting';

  @override
  String get badgeNeedsReview => 'Needs review';

  @override
  String get badgeFailed => 'Failed';

  @override
  String badgeSemantics(String state) {
    return 'Sync state: $state';
  }

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get greetingAfternoon => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String homeGreeting(String greeting, String name) {
    return '$greeting, Nurse $name';
  }

  @override
  String homeSubtitle(String subCounty, String weekday) {
    return '$subCounty, $weekday';
  }

  @override
  String homeVisitsToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count visits today',
      one: '1 visit today',
    );
    return '$_temp0';
  }

  @override
  String homePendingLine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes saved on this phone, waiting to sync',
      one: '1 change saved on this phone, waiting to sync',
    );
    return '$_temp0';
  }

  @override
  String get homeKeepWorking => 'Keep working. Nothing is lost.';

  @override
  String get legendTitle => 'What the status pill means';

  @override
  String get legendHide => 'Hide';

  @override
  String get homeNextVisit => 'Next visit';

  @override
  String get homeNoMoreVisits => 'No more visits today.';

  @override
  String get homeTodaysVisits => 'Today\'s visits';

  @override
  String totalCount(int count) {
    return '$count total';
  }

  @override
  String get visitsTitle => 'Visits';

  @override
  String get visitsNone => 'No visits scheduled today.';

  @override
  String get visitsReadError => 'Couldn\'t read visits from this phone.';

  @override
  String get recordNewVisit => 'Record new visit';

  @override
  String get offlineBannerTitle => 'Loaded from this phone';

  @override
  String lastSyncedAt(String time) {
    return 'Last synced with the server at $time';
  }

  @override
  String get notSyncedYet => 'Not synced with the server yet';

  @override
  String get dbRecoveredTitle => 'This phone\'s saved data couldn\'t be opened';

  @override
  String get dbRecoveredBody =>
      'Your synced visits are being downloaded again.';

  @override
  String visitCardSemantics(
    String name,
    String type,
    String time,
    String state,
  ) {
    return '$name, $type, $time, $state';
  }

  @override
  String get fieldPatient => 'Patient';

  @override
  String get fieldVisitTypeInput => 'Visit type';

  @override
  String get fieldTime => 'Time';

  @override
  String get saveVisit => 'Save visit';

  @override
  String get savedOnPhone => 'Saved on this phone';

  @override
  String get visitTypeAntenatal => 'Antenatal check';

  @override
  String get visitTypeBp => 'BP follow-up';

  @override
  String get visitTypeImmunisation => 'Child immunisation';

  @override
  String get visitTypeMalaria => 'Malaria test';

  @override
  String get visitTypeHome => 'Home visit: new household';

  @override
  String get visitTypeDiabetes => 'Diabetes review';

  @override
  String get visitTitle => 'Visit';

  @override
  String get visitGone => 'This visit is no longer on the phone.';

  @override
  String get vitalsTitle => 'Vitals';

  @override
  String get noVitals => 'No vitals recorded yet.';

  @override
  String get recordVitals => 'Record vitals';

  @override
  String get editVitals => 'Edit vitals';

  @override
  String get saveVitals => 'Save vitals';

  @override
  String vitalsTemperature(String value) {
    return 'Temperature: $value';
  }

  @override
  String vitalsBloodPressure(String systolic, String diastolic) {
    return 'Blood pressure: $systolic/$diastolic mmHg';
  }

  @override
  String get inputTemperature => 'Temperature (°C)';

  @override
  String get inputSystolic => 'Systolic (mmHg)';

  @override
  String get inputDiastolic => 'Diastolic (mmHg)';

  @override
  String get pendingTitle => 'Pending changes';

  @override
  String pendingBannerTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes waiting to sync',
      one: '1 change waiting to sync',
    );
    return '$_temp0';
  }

  @override
  String pendingOldest(String relative) {
    return 'Oldest change made $relative';
  }

  @override
  String get pendingFootnote =>
      'Changes are kept on the phone, even if it restarts.';

  @override
  String get pendingEmpty => 'Everything is synced';

  @override
  String get opAdded => 'Added';

  @override
  String get opEdited => 'Edited';

  @override
  String get opDeleted => 'Deleted';

  @override
  String get entryRejected => 'Rejected';

  @override
  String get entryRejectedSemantics => 'Rejected by the server';

  @override
  String entrySemantics(String op, String label) {
    return '$op. $label';
  }

  @override
  String get syncNow => 'Sync now';

  @override
  String syncSending(int done, int total) {
    return 'Sending $done of $total changes';
  }

  @override
  String get syncAutoCaption =>
      'Sync starts on its own when you\'re back online.';

  @override
  String get relJustNow => 'just now';

  @override
  String relMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String relHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String relDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get labelVisit => 'Visit';

  @override
  String get labelVitals => 'Vitals';

  @override
  String get labelPatient => 'Patient';

  @override
  String get labelHousehold => 'Household';

  @override
  String get historyTitle => 'Sync history';

  @override
  String get statSyncs => 'Syncs';

  @override
  String get statDone => 'Done';

  @override
  String get statMerged => 'Merged';

  @override
  String get statFailed => 'Failed';

  @override
  String statSemantics(String label, int value) {
    return '$label: $value';
  }

  @override
  String get historyRecent => 'Recent syncs';

  @override
  String get historyNone => 'No syncs yet.';

  @override
  String get runComplete => 'Sync complete';

  @override
  String get runMerge => 'Sync with a merge';

  @override
  String get runFailed => 'Sync failed';

  @override
  String runSemantics(String title, String summary, String when, String chip) {
    return '$title. $summary. $when. $chip';
  }

  @override
  String runTimeToday(String time) {
    return 'Today $time';
  }

  @override
  String runTimeYesterday(String time) {
    return 'Yesterday $time';
  }

  @override
  String runTimeWeekday(String day, String time) {
    return '$day $time';
  }

  @override
  String runTimeDate(String date, String time) {
    return '$date $time';
  }

  @override
  String summarySent(int sent, int received) {
    String _temp0 = intl.Intl.pluralLogic(
      sent,
      locale: localeName,
      other: '$sent changes sent',
      one: '1 change sent',
    );
    return '$_temp0, $received received';
  }

  @override
  String summaryExtraMerged(int count) {
    return '$count merged';
  }

  @override
  String summaryExtraReview(int count) {
    return '$count to review';
  }

  @override
  String get summaryNothing => 'Nothing new to sync';

  @override
  String get errNetwork => 'Couldn\'t reach the server. Will retry.';

  @override
  String get errServer => 'Server didn\'t respond. Will retry.';

  @override
  String get errLocal => 'Something went wrong on this phone. Will retry.';

  @override
  String get errInterrupted => 'Sync was interrupted. Will retry.';

  @override
  String get errRejectedDefault => 'The server rejected this change.';

  @override
  String get hubTitle => 'Sync';

  @override
  String hubPendingRow(int count) {
    return 'Pending changes ($count)';
  }

  @override
  String get hubWaiting => 'Waiting to be sent';

  @override
  String get hubHistorySub => 'Every sync, newest first';

  @override
  String get conflictReplacedTitle => 'One of your edits was replaced';

  @override
  String conflictReplacedBody(
    String subject,
    String field,
    String local,
    String source,
    String remote,
  ) {
    return 'You changed $subject\'s $field to $local. A newer edit from $source set it to $remote, so that value was kept.';
  }

  @override
  String get btnReenter => 'Re-enter mine';

  @override
  String get btnKeepNewer => 'Keep newer';

  @override
  String get confReentered => 'Your value was re-entered. It will sync soon.';

  @override
  String get confKeptNewer => 'Kept the newer value.';

  @override
  String get conflictKeptTitle => 'Two different values were entered';

  @override
  String conflictKeptBody(
    String subject,
    String field,
    String local,
    String source,
    String remote,
  ) {
    return 'You set $subject\'s $field to $local. An older edit from $source set it to $remote. Your value was kept. Please check it.';
  }

  @override
  String get btnKeepMine => 'Keep mine';

  @override
  String get btnUseTheirs => 'Use theirs';

  @override
  String get confKeptMine => 'Kept your value.';

  @override
  String confUsedTheirs(String remote) {
    return 'Changed to $remote. It will sync soon.';
  }

  @override
  String get conflictDeletedTitle =>
      'Something you edited was deleted elsewhere';

  @override
  String conflictDeletedBody(String source, String subject, String noun) {
    return '$source deleted $subject\'s $noun, but you had changed it. Your version was kept.';
  }

  @override
  String get btnDeleteIt => 'Delete it';

  @override
  String get confKeptVersion => 'Kept your version.';

  @override
  String get confDeleted => 'Deleted. It will sync soon.';

  @override
  String conflictMergedTitle(String source) {
    return 'Merged a change from $source';
  }

  @override
  String conflictMergedBody(String subject, String noun) {
    return '$subject\'s $noun now has both edits.';
  }

  @override
  String get nounVisit => 'visit';

  @override
  String get nounVitals => 'vitals';

  @override
  String get nounPatient => 'record';

  @override
  String get nounHousehold => 'household';

  @override
  String get fieldTemperature => 'temperature';

  @override
  String get fieldSystolic => 'systolic blood pressure';

  @override
  String get fieldDiastolic => 'diastolic blood pressure';

  @override
  String get fieldVisitType => 'visit type';

  @override
  String get fieldVisitTime => 'visit time';

  @override
  String get fieldCompletionTime => 'completion time';

  @override
  String get fieldPatientName => 'patient name';

  @override
  String get fieldName => 'name';

  @override
  String get fieldHousehold => 'household';

  @override
  String get fieldHeadOfHousehold => 'head of household';

  @override
  String get fieldLocation => 'Location';

  @override
  String get valueNothing => 'nothing';

  @override
  String get profileTitle => 'Profile';

  @override
  String profileNurse(String name) {
    return 'Nurse $name';
  }

  @override
  String profileSubCounty(String subCounty) {
    return '$subCounty sub-county';
  }

  @override
  String get deviceName => 'Device name';

  @override
  String get deviceNameHelp =>
      'Other devices see this when your edits are merged.';

  @override
  String get languageTitle => 'Language';

  @override
  String get langSystem => 'Phone language';

  @override
  String get langEnglish => 'English';

  @override
  String get langSwahili => 'Kiswahili';

  @override
  String progressOf(int done, int total) {
    return '$done of $total';
  }

  @override
  String get startupErrorTitle =>
      'This phone\'s secure storage couldn\'t be opened';

  @override
  String get startupErrorBody =>
      'Your saved visits are protected by a key that can\'t be read right now. Try again. If the phone was just restarted, unlock it first.';

  @override
  String get startupRetry => 'Try again';

  @override
  String get startupReset => 'Reset this phone\'s data';

  @override
  String get startupResetTitle => 'Reset this phone\'s data?';

  @override
  String get startupResetBody =>
      'Changes that haven\'t been sent to the server will be lost. Synced visits will be downloaded again.';

  @override
  String get startupResetConfirm => 'Reset';

  @override
  String get cancel => 'Cancel';

  @override
  String get registerPatient => 'Register patient';

  @override
  String get registerNewPatient => 'Register new patient';

  @override
  String get fieldFullName => 'Full name';

  @override
  String get fieldHouseholdHead => 'Head of household';

  @override
  String get fieldHouseholdHeadHint => 'Leave blank if same as patient';

  @override
  String get savePatient => 'Save patient';

  @override
  String get noPatientsYet =>
      'No patients yet. Register your first patient to get started.';
}
