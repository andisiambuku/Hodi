import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_sw.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('sw'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Hodi'**
  String get appTitle;

  /// No description provided for @navVisits.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get navVisits;

  /// No description provided for @navPatients.
  ///
  /// In en, this message translates to:
  /// **'Patients'**
  String get navPatients;

  /// No description provided for @navSync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get navSync;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @statusOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get statusOnline;

  /// No description provided for @statusOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get statusOffline;

  /// No description provided for @statusSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing'**
  String get statusSyncing;

  /// No description provided for @statusPillSemantics.
  ///
  /// In en, this message translates to:
  /// **'Connection status: {status}'**
  String statusPillSemantics(String status);

  /// No description provided for @statusOnlineSentence.
  ///
  /// In en, this message translates to:
  /// **'All changes are saved to the server'**
  String get statusOnlineSentence;

  /// No description provided for @statusOfflineSentence.
  ///
  /// In en, this message translates to:
  /// **'Changes are saved on this phone'**
  String get statusOfflineSentence;

  /// No description provided for @statusSyncingSentence.
  ///
  /// In en, this message translates to:
  /// **'Sending {count, plural, =1{1 change} other{{count} changes}} to the server'**
  String statusSyncingSentence(int count);

  /// No description provided for @badgeSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get badgeSynced;

  /// No description provided for @badgeWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get badgeWaiting;

  /// No description provided for @badgeNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'Needs review'**
  String get badgeNeedsReview;

  /// No description provided for @badgeFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get badgeFailed;

  /// No description provided for @badgeSemantics.
  ///
  /// In en, this message translates to:
  /// **'Sync state: {state}'**
  String badgeSemantics(String state);

  /// No description provided for @greetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get greetingEvening;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'{greeting}, Nurse {name}'**
  String homeGreeting(String greeting, String name);

  /// No description provided for @homeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{subCounty}, {weekday}'**
  String homeSubtitle(String subCounty, String weekday);

  /// No description provided for @homeVisitsToday.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 visit today} other{{count} visits today}}'**
  String homeVisitsToday(int count);

  /// No description provided for @homePendingLine.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change saved on this phone, waiting to sync} other{{count} changes saved on this phone, waiting to sync}}'**
  String homePendingLine(int count);

  /// No description provided for @homeKeepWorking.
  ///
  /// In en, this message translates to:
  /// **'Keep working. Nothing is lost.'**
  String get homeKeepWorking;

  /// No description provided for @legendTitle.
  ///
  /// In en, this message translates to:
  /// **'What the status pill means'**
  String get legendTitle;

  /// No description provided for @legendHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get legendHide;

  /// No description provided for @homeNextVisit.
  ///
  /// In en, this message translates to:
  /// **'Next visit'**
  String get homeNextVisit;

  /// No description provided for @homeNoMoreVisits.
  ///
  /// In en, this message translates to:
  /// **'No more visits today.'**
  String get homeNoMoreVisits;

  /// No description provided for @homeTodaysVisits.
  ///
  /// In en, this message translates to:
  /// **'Today\'s visits'**
  String get homeTodaysVisits;

  /// No description provided for @totalCount.
  ///
  /// In en, this message translates to:
  /// **'{count} total'**
  String totalCount(int count);

  /// No description provided for @visitsTitle.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get visitsTitle;

  /// No description provided for @visitsNone.
  ///
  /// In en, this message translates to:
  /// **'No visits scheduled today.'**
  String get visitsNone;

  /// No description provided for @visitsReadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read visits from this phone.'**
  String get visitsReadError;

  /// No description provided for @recordNewVisit.
  ///
  /// In en, this message translates to:
  /// **'Record new visit'**
  String get recordNewVisit;

  /// No description provided for @offlineBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Loaded from this phone'**
  String get offlineBannerTitle;

  /// No description provided for @lastSyncedAt.
  ///
  /// In en, this message translates to:
  /// **'Last synced with the server at {time}'**
  String lastSyncedAt(String time);

  /// No description provided for @notSyncedYet.
  ///
  /// In en, this message translates to:
  /// **'Not synced with the server yet'**
  String get notSyncedYet;

  /// No description provided for @dbRecoveredTitle.
  ///
  /// In en, this message translates to:
  /// **'This phone\'s saved data couldn\'t be opened'**
  String get dbRecoveredTitle;

  /// No description provided for @dbRecoveredBody.
  ///
  /// In en, this message translates to:
  /// **'Your synced visits are being downloaded again.'**
  String get dbRecoveredBody;

  /// No description provided for @visitCardSemantics.
  ///
  /// In en, this message translates to:
  /// **'{name}, {type}, {time}, {state}'**
  String visitCardSemantics(
    String name,
    String type,
    String time,
    String state,
  );

  /// No description provided for @fieldPatient.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get fieldPatient;

  /// No description provided for @fieldVisitTypeInput.
  ///
  /// In en, this message translates to:
  /// **'Visit type'**
  String get fieldVisitTypeInput;

  /// No description provided for @fieldTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get fieldTime;

  /// No description provided for @saveVisit.
  ///
  /// In en, this message translates to:
  /// **'Save visit'**
  String get saveVisit;

  /// No description provided for @savedOnPhone.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone'**
  String get savedOnPhone;

  /// No description provided for @visitTypeAntenatal.
  ///
  /// In en, this message translates to:
  /// **'Antenatal check'**
  String get visitTypeAntenatal;

  /// No description provided for @visitTypeBp.
  ///
  /// In en, this message translates to:
  /// **'BP follow-up'**
  String get visitTypeBp;

  /// No description provided for @visitTypeImmunisation.
  ///
  /// In en, this message translates to:
  /// **'Child immunisation'**
  String get visitTypeImmunisation;

  /// No description provided for @visitTypeMalaria.
  ///
  /// In en, this message translates to:
  /// **'Malaria test'**
  String get visitTypeMalaria;

  /// No description provided for @visitTypeHome.
  ///
  /// In en, this message translates to:
  /// **'Home visit: new household'**
  String get visitTypeHome;

  /// No description provided for @visitTypeDiabetes.
  ///
  /// In en, this message translates to:
  /// **'Diabetes review'**
  String get visitTypeDiabetes;

  /// No description provided for @visitTitle.
  ///
  /// In en, this message translates to:
  /// **'Visit'**
  String get visitTitle;

  /// No description provided for @visitGone.
  ///
  /// In en, this message translates to:
  /// **'This visit is no longer on the phone.'**
  String get visitGone;

  /// No description provided for @vitalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Vitals'**
  String get vitalsTitle;

  /// No description provided for @noVitals.
  ///
  /// In en, this message translates to:
  /// **'No vitals recorded yet.'**
  String get noVitals;

  /// No description provided for @recordVitals.
  ///
  /// In en, this message translates to:
  /// **'Record vitals'**
  String get recordVitals;

  /// No description provided for @editVitals.
  ///
  /// In en, this message translates to:
  /// **'Edit vitals'**
  String get editVitals;

  /// No description provided for @saveVitals.
  ///
  /// In en, this message translates to:
  /// **'Save vitals'**
  String get saveVitals;

  /// No description provided for @vitalsTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature: {value}'**
  String vitalsTemperature(String value);

  /// No description provided for @vitalsBloodPressure.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure: {systolic}/{diastolic} mmHg'**
  String vitalsBloodPressure(String systolic, String diastolic);

  /// No description provided for @inputTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature (°C)'**
  String get inputTemperature;

  /// No description provided for @inputSystolic.
  ///
  /// In en, this message translates to:
  /// **'Systolic (mmHg)'**
  String get inputSystolic;

  /// No description provided for @inputDiastolic.
  ///
  /// In en, this message translates to:
  /// **'Diastolic (mmHg)'**
  String get inputDiastolic;

  /// No description provided for @pendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Pending changes'**
  String get pendingTitle;

  /// No description provided for @pendingBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change waiting to sync} other{{count} changes waiting to sync}}'**
  String pendingBannerTitle(int count);

  /// No description provided for @pendingOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest change made {relative}'**
  String pendingOldest(String relative);

  /// No description provided for @pendingFootnote.
  ///
  /// In en, this message translates to:
  /// **'Changes are kept on the phone, even if it restarts.'**
  String get pendingFootnote;

  /// No description provided for @pendingEmpty.
  ///
  /// In en, this message translates to:
  /// **'Everything is synced'**
  String get pendingEmpty;

  /// No description provided for @opAdded.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get opAdded;

  /// No description provided for @opEdited.
  ///
  /// In en, this message translates to:
  /// **'Edited'**
  String get opEdited;

  /// No description provided for @opDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get opDeleted;

  /// No description provided for @entryRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get entryRejected;

  /// No description provided for @entryRejectedSemantics.
  ///
  /// In en, this message translates to:
  /// **'Rejected by the server'**
  String get entryRejectedSemantics;

  /// No description provided for @entrySemantics.
  ///
  /// In en, this message translates to:
  /// **'{op}. {label}'**
  String entrySemantics(String op, String label);

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @syncSending.
  ///
  /// In en, this message translates to:
  /// **'Sending {done} of {total} changes'**
  String syncSending(int done, int total);

  /// No description provided for @syncAutoCaption.
  ///
  /// In en, this message translates to:
  /// **'Sync starts on its own when you\'re back online.'**
  String get syncAutoCaption;

  /// No description provided for @relJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get relJustNow;

  /// No description provided for @relMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute ago} other{{count} minutes ago}}'**
  String relMinutes(int count);

  /// No description provided for @relHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String relHours(int count);

  /// No description provided for @relDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String relDays(int count);

  /// No description provided for @labelVisit.
  ///
  /// In en, this message translates to:
  /// **'Visit'**
  String get labelVisit;

  /// No description provided for @labelVitals.
  ///
  /// In en, this message translates to:
  /// **'Vitals'**
  String get labelVitals;

  /// No description provided for @labelPatient.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get labelPatient;

  /// No description provided for @labelHousehold.
  ///
  /// In en, this message translates to:
  /// **'Household'**
  String get labelHousehold;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync history'**
  String get historyTitle;

  /// No description provided for @statSyncs.
  ///
  /// In en, this message translates to:
  /// **'Syncs'**
  String get statSyncs;

  /// No description provided for @statDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get statDone;

  /// No description provided for @statMerged.
  ///
  /// In en, this message translates to:
  /// **'Merged'**
  String get statMerged;

  /// No description provided for @statFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statFailed;

  /// No description provided for @statSemantics.
  ///
  /// In en, this message translates to:
  /// **'{label}: {value}'**
  String statSemantics(String label, int value);

  /// No description provided for @historyRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent syncs'**
  String get historyRecent;

  /// No description provided for @historyNone.
  ///
  /// In en, this message translates to:
  /// **'No syncs yet.'**
  String get historyNone;

  /// No description provided for @runComplete.
  ///
  /// In en, this message translates to:
  /// **'Sync complete'**
  String get runComplete;

  /// No description provided for @runMerge.
  ///
  /// In en, this message translates to:
  /// **'Sync with a merge'**
  String get runMerge;

  /// No description provided for @runFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get runFailed;

  /// No description provided for @runSemantics.
  ///
  /// In en, this message translates to:
  /// **'{title}. {summary}. {when}. {chip}'**
  String runSemantics(String title, String summary, String when, String chip);

  /// No description provided for @runTimeToday.
  ///
  /// In en, this message translates to:
  /// **'Today {time}'**
  String runTimeToday(String time);

  /// No description provided for @runTimeYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday {time}'**
  String runTimeYesterday(String time);

  /// No description provided for @runTimeWeekday.
  ///
  /// In en, this message translates to:
  /// **'{day} {time}'**
  String runTimeWeekday(String day, String time);

  /// No description provided for @runTimeDate.
  ///
  /// In en, this message translates to:
  /// **'{date} {time}'**
  String runTimeDate(String date, String time);

  /// No description provided for @summarySent.
  ///
  /// In en, this message translates to:
  /// **'{sent, plural, =1{1 change sent} other{{sent} changes sent}}, {received} received'**
  String summarySent(int sent, int received);

  /// No description provided for @summaryExtraMerged.
  ///
  /// In en, this message translates to:
  /// **'{count} merged'**
  String summaryExtraMerged(int count);

  /// No description provided for @summaryExtraReview.
  ///
  /// In en, this message translates to:
  /// **'{count} to review'**
  String summaryExtraReview(int count);

  /// No description provided for @summaryNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing new to sync'**
  String get summaryNothing;

  /// No description provided for @errNetwork.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the server. Will retry.'**
  String get errNetwork;

  /// No description provided for @errServer.
  ///
  /// In en, this message translates to:
  /// **'Server didn\'t respond. Will retry.'**
  String get errServer;

  /// No description provided for @errLocal.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong on this phone. Will retry.'**
  String get errLocal;

  /// No description provided for @errInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Sync was interrupted. Will retry.'**
  String get errInterrupted;

  /// No description provided for @errRejectedDefault.
  ///
  /// In en, this message translates to:
  /// **'The server rejected this change.'**
  String get errRejectedDefault;

  /// No description provided for @hubTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get hubTitle;

  /// No description provided for @hubPendingRow.
  ///
  /// In en, this message translates to:
  /// **'Pending changes ({count})'**
  String hubPendingRow(int count);

  /// No description provided for @hubWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting to be sent'**
  String get hubWaiting;

  /// No description provided for @hubHistorySub.
  ///
  /// In en, this message translates to:
  /// **'Every sync, newest first'**
  String get hubHistorySub;

  /// No description provided for @conflictReplacedTitle.
  ///
  /// In en, this message translates to:
  /// **'One of your edits was replaced'**
  String get conflictReplacedTitle;

  /// No description provided for @conflictReplacedBody.
  ///
  /// In en, this message translates to:
  /// **'You changed {subject}\'s {field} to {local}. A newer edit from {source} set it to {remote}, so that value was kept.'**
  String conflictReplacedBody(
    String subject,
    String field,
    String local,
    String source,
    String remote,
  );

  /// No description provided for @btnReenter.
  ///
  /// In en, this message translates to:
  /// **'Re-enter mine'**
  String get btnReenter;

  /// No description provided for @btnKeepNewer.
  ///
  /// In en, this message translates to:
  /// **'Keep newer'**
  String get btnKeepNewer;

  /// No description provided for @confReentered.
  ///
  /// In en, this message translates to:
  /// **'Your value was re-entered. It will sync soon.'**
  String get confReentered;

  /// No description provided for @confKeptNewer.
  ///
  /// In en, this message translates to:
  /// **'Kept the newer value.'**
  String get confKeptNewer;

  /// No description provided for @conflictKeptTitle.
  ///
  /// In en, this message translates to:
  /// **'Two different values were entered'**
  String get conflictKeptTitle;

  /// No description provided for @conflictKeptBody.
  ///
  /// In en, this message translates to:
  /// **'You set {subject}\'s {field} to {local}. An older edit from {source} set it to {remote}. Your value was kept. Please check it.'**
  String conflictKeptBody(
    String subject,
    String field,
    String local,
    String source,
    String remote,
  );

  /// No description provided for @btnKeepMine.
  ///
  /// In en, this message translates to:
  /// **'Keep mine'**
  String get btnKeepMine;

  /// No description provided for @btnUseTheirs.
  ///
  /// In en, this message translates to:
  /// **'Use theirs'**
  String get btnUseTheirs;

  /// No description provided for @confKeptMine.
  ///
  /// In en, this message translates to:
  /// **'Kept your value.'**
  String get confKeptMine;

  /// No description provided for @confUsedTheirs.
  ///
  /// In en, this message translates to:
  /// **'Changed to {remote}. It will sync soon.'**
  String confUsedTheirs(String remote);

  /// No description provided for @conflictDeletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Something you edited was deleted elsewhere'**
  String get conflictDeletedTitle;

  /// No description provided for @conflictDeletedBody.
  ///
  /// In en, this message translates to:
  /// **'{source} deleted {subject}\'s {noun}, but you had changed it. Your version was kept.'**
  String conflictDeletedBody(String source, String subject, String noun);

  /// No description provided for @btnDeleteIt.
  ///
  /// In en, this message translates to:
  /// **'Delete it'**
  String get btnDeleteIt;

  /// No description provided for @confKeptVersion.
  ///
  /// In en, this message translates to:
  /// **'Kept your version.'**
  String get confKeptVersion;

  /// No description provided for @confDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted. It will sync soon.'**
  String get confDeleted;

  /// No description provided for @conflictMergedTitle.
  ///
  /// In en, this message translates to:
  /// **'Merged a change from {source}'**
  String conflictMergedTitle(String source);

  /// No description provided for @conflictMergedBody.
  ///
  /// In en, this message translates to:
  /// **'{subject}\'s {noun} now has both edits.'**
  String conflictMergedBody(String subject, String noun);

  /// No description provided for @nounVisit.
  ///
  /// In en, this message translates to:
  /// **'visit'**
  String get nounVisit;

  /// No description provided for @nounVitals.
  ///
  /// In en, this message translates to:
  /// **'vitals'**
  String get nounVitals;

  /// No description provided for @nounPatient.
  ///
  /// In en, this message translates to:
  /// **'record'**
  String get nounPatient;

  /// No description provided for @nounHousehold.
  ///
  /// In en, this message translates to:
  /// **'household'**
  String get nounHousehold;

  /// No description provided for @fieldTemperature.
  ///
  /// In en, this message translates to:
  /// **'temperature'**
  String get fieldTemperature;

  /// No description provided for @fieldSystolic.
  ///
  /// In en, this message translates to:
  /// **'systolic blood pressure'**
  String get fieldSystolic;

  /// No description provided for @fieldDiastolic.
  ///
  /// In en, this message translates to:
  /// **'diastolic blood pressure'**
  String get fieldDiastolic;

  /// No description provided for @fieldVisitType.
  ///
  /// In en, this message translates to:
  /// **'visit type'**
  String get fieldVisitType;

  /// No description provided for @fieldVisitTime.
  ///
  /// In en, this message translates to:
  /// **'visit time'**
  String get fieldVisitTime;

  /// No description provided for @fieldCompletionTime.
  ///
  /// In en, this message translates to:
  /// **'completion time'**
  String get fieldCompletionTime;

  /// No description provided for @fieldPatientName.
  ///
  /// In en, this message translates to:
  /// **'patient name'**
  String get fieldPatientName;

  /// No description provided for @fieldName.
  ///
  /// In en, this message translates to:
  /// **'name'**
  String get fieldName;

  /// No description provided for @fieldHousehold.
  ///
  /// In en, this message translates to:
  /// **'household'**
  String get fieldHousehold;

  /// No description provided for @fieldHeadOfHousehold.
  ///
  /// In en, this message translates to:
  /// **'head of household'**
  String get fieldHeadOfHousehold;

  /// No description provided for @fieldLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get fieldLocation;

  /// No description provided for @valueNothing.
  ///
  /// In en, this message translates to:
  /// **'nothing'**
  String get valueNothing;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileNurse.
  ///
  /// In en, this message translates to:
  /// **'Nurse {name}'**
  String profileNurse(String name);

  /// No description provided for @profileSubCounty.
  ///
  /// In en, this message translates to:
  /// **'{subCounty} sub-county'**
  String profileSubCounty(String subCounty);

  /// No description provided for @deviceName.
  ///
  /// In en, this message translates to:
  /// **'Device name'**
  String get deviceName;

  /// No description provided for @deviceNameHelp.
  ///
  /// In en, this message translates to:
  /// **'Other devices see this when your edits are merged.'**
  String get deviceNameHelp;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @langSystem.
  ///
  /// In en, this message translates to:
  /// **'Phone language'**
  String get langSystem;

  /// No description provided for @langEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// No description provided for @langSwahili.
  ///
  /// In en, this message translates to:
  /// **'Kiswahili'**
  String get langSwahili;

  /// No description provided for @progressOf.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total}'**
  String progressOf(int done, int total);

  /// No description provided for @startupErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'This phone\'s secure storage couldn\'t be opened'**
  String get startupErrorTitle;

  /// No description provided for @startupErrorBody.
  ///
  /// In en, this message translates to:
  /// **'Your saved visits are protected by a key that can\'t be read right now. Try again. If the phone was just restarted, unlock it first.'**
  String get startupErrorBody;

  /// No description provided for @startupRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get startupRetry;

  /// No description provided for @startupReset.
  ///
  /// In en, this message translates to:
  /// **'Reset this phone\'s data'**
  String get startupReset;

  /// No description provided for @startupResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset this phone\'s data?'**
  String get startupResetTitle;

  /// No description provided for @startupResetBody.
  ///
  /// In en, this message translates to:
  /// **'Changes that haven\'t been sent to the server will be lost. Synced visits will be downloaded again.'**
  String get startupResetBody;

  /// No description provided for @startupResetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get startupResetConfirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @registerPatient.
  ///
  /// In en, this message translates to:
  /// **'Register patient'**
  String get registerPatient;

  /// No description provided for @registerNewPatient.
  ///
  /// In en, this message translates to:
  /// **'Register new patient'**
  String get registerNewPatient;

  /// No description provided for @fieldFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fieldFullName;

  /// No description provided for @fieldHouseholdHead.
  ///
  /// In en, this message translates to:
  /// **'Head of household'**
  String get fieldHouseholdHead;

  /// No description provided for @fieldHouseholdHeadHint.
  ///
  /// In en, this message translates to:
  /// **'Leave blank if same as patient'**
  String get fieldHouseholdHeadHint;

  /// No description provided for @savePatient.
  ///
  /// In en, this message translates to:
  /// **'Save patient'**
  String get savePatient;

  /// No description provided for @noPatientsYet.
  ///
  /// In en, this message translates to:
  /// **'No patients yet. Register your first patient to get started.'**
  String get noPatientsYet;

  /// No description provided for @fieldPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get fieldPhoneNumber;

  /// No description provided for @fieldPhoneNumberHint.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get fieldPhoneNumberHint;

  /// No description provided for @phoneNumberInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number, e.g. 0712 345 678'**
  String get phoneNumberInvalid;

  /// No description provided for @fieldAccountStatus.
  ///
  /// In en, this message translates to:
  /// **'Account status'**
  String get fieldAccountStatus;

  /// No description provided for @statusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get statusActive;

  /// No description provided for @statusInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get statusInactive;

  /// No description provided for @markInactiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark {name} inactive?'**
  String markInactiveTitle(String name);

  /// No description provided for @markActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark {name} active?'**
  String markActiveTitle(String name);

  /// No description provided for @markStatusBody.
  ///
  /// In en, this message translates to:
  /// **'This is saved on the phone and sent when you sync.'**
  String get markStatusBody;

  /// No description provided for @markInactiveAction.
  ///
  /// In en, this message translates to:
  /// **'Mark inactive'**
  String get markInactiveAction;

  /// No description provided for @markActiveAction.
  ///
  /// In en, this message translates to:
  /// **'Mark active'**
  String get markActiveAction;

  /// No description provided for @patientStatusChanged.
  ///
  /// In en, this message translates to:
  /// **'{name} is now {status}.'**
  String patientStatusChanged(String name, String status);

  /// No description provided for @noPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'No phone number'**
  String get noPhoneNumber;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'sw'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'sw':
      return AppLocalizationsSw();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
