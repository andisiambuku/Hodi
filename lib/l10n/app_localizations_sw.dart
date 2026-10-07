// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swahili (`sw`).
class AppLocalizationsSw extends AppLocalizations {
  AppLocalizationsSw([String locale = 'sw']) : super(locale);

  @override
  String get appTitle => 'Hodi';

  @override
  String get navVisits => 'Ziara';

  @override
  String get navPatients => 'Wagonjwa';

  @override
  String get navSync => 'Sawazisha';

  @override
  String get navProfile => 'Wasifu';

  @override
  String get back => 'Rudi';

  @override
  String get dismiss => 'Funga';

  @override
  String get comingSoon => 'Inakuja hivi karibuni';

  @override
  String get statusOnline => 'Mtandaoni';

  @override
  String get statusOffline => 'Nje ya mtandao';

  @override
  String get statusSyncing => 'Inasawazisha';

  @override
  String statusPillSemantics(String status) {
    return 'Hali ya muunganisho: $status';
  }

  @override
  String get statusOnlineSentence =>
      'Mabadiliko yote yamehifadhiwa kwenye seva';

  @override
  String get statusOfflineSentence =>
      'Mabadiliko yamehifadhiwa kwenye simu hii';

  @override
  String statusSyncingSentence(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mabadiliko $count',
      one: 'badiliko 1',
    );
    return 'Inatuma $_temp0 kwenye seva';
  }

  @override
  String get badgeSynced => 'Imesawazishwa';

  @override
  String get badgeWaiting => 'Inasubiri';

  @override
  String get badgeNeedsReview => 'Inahitaji ukaguzi';

  @override
  String get badgeFailed => 'Imeshindwa';

  @override
  String badgeSemantics(String state) {
    return 'Hali ya usawazishaji: $state';
  }

  @override
  String get greetingMorning => 'Habari za asubuhi';

  @override
  String get greetingAfternoon => 'Habari za mchana';

  @override
  String get greetingEvening => 'Habari za jioni';

  @override
  String homeGreeting(String greeting, String name) {
    return '$greeting, Nesi $name';
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
      other: 'Ziara $count leo',
      one: 'Ziara 1 leo',
    );
    return '$_temp0';
  }

  @override
  String homePendingLine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Mabadiliko $count yamehifadhiwa kwenye simu hii, yanasubiri kusawazishwa',
      one: 'Badiliko 1 limehifadhiwa kwenye simu hii, linasubiri kusawazishwa',
    );
    return '$_temp0';
  }

  @override
  String get homeKeepWorking => 'Endelea kufanya kazi. Hakuna kitakachopotea.';

  @override
  String get legendTitle => 'Maana ya kiashiria cha hali';

  @override
  String get legendHide => 'Ficha';

  @override
  String get homeNextVisit => 'Ziara inayofuata';

  @override
  String get homeNoMoreVisits => 'Hakuna ziara nyingine leo.';

  @override
  String get homeTodaysVisits => 'Ziara za leo';

  @override
  String totalCount(int count) {
    return 'Jumla $count';
  }

  @override
  String get visitsTitle => 'Ziara';

  @override
  String get visitsNone => 'Hakuna ziara zilizopangwa leo.';

  @override
  String get visitsReadError =>
      'Imeshindwa kusoma ziara kutoka kwenye simu hii.';

  @override
  String get recordNewVisit => 'Rekodi ziara mpya';

  @override
  String get offlineBannerTitle => 'Imepakiwa kutoka kwenye simu hii';

  @override
  String lastSyncedAt(String time) {
    return 'Ilisawazishwa mara ya mwisho na seva saa $time';
  }

  @override
  String get notSyncedYet => 'Bado haijasawazishwa na seva';

  @override
  String get dbRecoveredTitle =>
      'Data iliyohifadhiwa kwenye simu hii haikuweza kufunguliwa';

  @override
  String get dbRecoveredBody =>
      'Ziara zako zilizosawazishwa zinapakuliwa tena.';

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
  String get fieldPatient => 'Mgonjwa';

  @override
  String get fieldVisitTypeInput => 'Aina ya ziara';

  @override
  String get fieldTime => 'Saa';

  @override
  String get saveVisit => 'Hifadhi ziara';

  @override
  String get savedOnPhone => 'Imehifadhiwa kwenye simu hii';

  @override
  String get visitTypeAntenatal => 'Uchunguzi wa ujauzito';

  @override
  String get visitTypeBp => 'Ufuatiliaji wa shinikizo la damu';

  @override
  String get visitTypeImmunisation => 'Chanjo ya mtoto';

  @override
  String get visitTypeMalaria => 'Kipimo cha malaria';

  @override
  String get visitTypeHome => 'Ziara ya nyumbani: kaya mpya';

  @override
  String get visitTypeDiabetes => 'Ukaguzi wa kisukari';

  @override
  String get visitTitle => 'Ziara';

  @override
  String get visitGone => 'Ziara hii haipo tena kwenye simu.';

  @override
  String get vitalsTitle => 'Viashiria vya afya';

  @override
  String get noVitals => 'Bado hakuna viashiria vilivyorekodiwa.';

  @override
  String get recordVitals => 'Rekodi viashiria';

  @override
  String get editVitals => 'Hariri viashiria';

  @override
  String get saveVitals => 'Hifadhi viashiria';

  @override
  String vitalsTemperature(String value) {
    return 'Joto la mwili: $value';
  }

  @override
  String vitalsBloodPressure(String systolic, String diastolic) {
    return 'Shinikizo la damu: $systolic/$diastolic mmHg';
  }

  @override
  String get inputTemperature => 'Joto la mwili (°C)';

  @override
  String get inputSystolic => 'Shinikizo la juu (mmHg)';

  @override
  String get inputDiastolic => 'Shinikizo la chini (mmHg)';

  @override
  String get pendingTitle => 'Mabadiliko yanayosubiri';

  @override
  String pendingBannerTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mabadiliko $count yanasubiri kusawazishwa',
      one: 'Badiliko 1 linasubiri kusawazishwa',
    );
    return '$_temp0';
  }

  @override
  String pendingOldest(String relative) {
    return 'Badiliko la zamani zaidi lilifanywa $relative';
  }

  @override
  String get pendingFootnote =>
      'Mabadiliko huhifadhiwa kwenye simu, hata ikizimwa na kuwashwa tena.';

  @override
  String get pendingEmpty => 'Kila kitu kimesawazishwa';

  @override
  String get opAdded => 'Imeongezwa';

  @override
  String get opEdited => 'Imehaririwa';

  @override
  String get opDeleted => 'Imefutwa';

  @override
  String get entryRejected => 'Imekataliwa';

  @override
  String get entryRejectedSemantics => 'Imekataliwa na seva';

  @override
  String entrySemantics(String op, String label) {
    return '$op. $label';
  }

  @override
  String get syncNow => 'Sawazisha sasa';

  @override
  String syncSending(int done, int total) {
    return 'Inatuma $done kati ya $total';
  }

  @override
  String get syncAutoCaption =>
      'Usawazishaji utaanza wenyewe utakaporudi mtandaoni.';

  @override
  String get relJustNow => 'sasa hivi';

  @override
  String relMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dakika $count zilizopita',
      one: 'dakika 1 iliyopita',
    );
    return '$_temp0';
  }

  @override
  String relHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'saa $count zilizopita',
      one: 'saa 1 iliyopita',
    );
    return '$_temp0';
  }

  @override
  String relDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'siku $count zilizopita',
      one: 'siku 1 iliyopita',
    );
    return '$_temp0';
  }

  @override
  String get labelVisit => 'Ziara';

  @override
  String get labelVitals => 'Viashiria';

  @override
  String get labelPatient => 'Mgonjwa';

  @override
  String get labelHousehold => 'Kaya';

  @override
  String get historyTitle => 'Historia ya usawazishaji';

  @override
  String get statSyncs => 'Usawazishaji';

  @override
  String get statDone => 'Imekamilika';

  @override
  String get statMerged => 'Imeunganishwa';

  @override
  String get statFailed => 'Imeshindwa';

  @override
  String statSemantics(String label, int value) {
    return '$label: $value';
  }

  @override
  String get historyRecent => 'Usawazishaji wa hivi karibuni';

  @override
  String get historyNone => 'Bado hakuna usawazishaji.';

  @override
  String get runComplete => 'Usawazishaji umekamilika';

  @override
  String get runMerge => 'Usawazishaji na uunganishaji';

  @override
  String get runFailed => 'Usawazishaji umeshindwa';

  @override
  String runSemantics(String title, String summary, String when, String chip) {
    return '$title. $summary. $when. $chip';
  }

  @override
  String runTimeToday(String time) {
    return 'Leo $time';
  }

  @override
  String runTimeYesterday(String time) {
    return 'Jana $time';
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
      other: 'Mabadiliko $sent yametumwa',
      one: 'Badiliko 1 limetumwa',
    );
    return '$_temp0, $received yamepokelewa';
  }

  @override
  String summaryExtraMerged(int count) {
    return '$count yameunganishwa';
  }

  @override
  String summaryExtraReview(int count) {
    return '$count ya kukagua';
  }

  @override
  String get summaryNothing => 'Hakuna jipya la kusawazisha';

  @override
  String get errNetwork => 'Imeshindwa kufikia seva. Itajaribu tena.';

  @override
  String get errServer => 'Seva haikujibu. Itajaribu tena.';

  @override
  String get errLocal => 'Hitilafu imetokea kwenye simu hii. Itajaribu tena.';

  @override
  String get errInterrupted => 'Usawazishaji ulikatizwa. Utajaribu tena.';

  @override
  String get errRejectedDefault => 'Seva ilikataa badiliko hili.';

  @override
  String get hubTitle => 'Sawazisha';

  @override
  String hubPendingRow(int count) {
    return 'Mabadiliko yanayosubiri ($count)';
  }

  @override
  String get hubWaiting => 'Yanasubiri kutumwa';

  @override
  String get hubHistorySub => 'Kila usawazishaji, wa karibuni kwanza';

  @override
  String get conflictReplacedTitle =>
      'Mojawapo ya mabadiliko yako yalibadilishwa';

  @override
  String conflictReplacedBody(
    String subject,
    String field,
    String local,
    String source,
    String remote,
  ) {
    return 'Ulibadilisha $field kwa $subject kuwa $local. Badiliko jipya zaidi kutoka $source liliiweka kuwa $remote, kwa hivyo thamani hiyo ilihifadhiwa.';
  }

  @override
  String get btnReenter => 'Weka yangu tena';

  @override
  String get btnKeepNewer => 'Weka mpya';

  @override
  String get confReentered =>
      'Thamani yako imewekwa tena. Itasawazishwa hivi karibuni.';

  @override
  String get confKeptNewer => 'Thamani mpya imehifadhiwa.';

  @override
  String get conflictKeptTitle => 'Thamani mbili tofauti ziliingizwa';

  @override
  String conflictKeptBody(
    String subject,
    String field,
    String local,
    String source,
    String remote,
  ) {
    return 'Uliweka $field kwa $subject kuwa $local. Badiliko la zamani kutoka $source liliiweka kuwa $remote. Thamani yako ilihifadhiwa. Tafadhali ikague.';
  }

  @override
  String get btnKeepMine => 'Weka yangu';

  @override
  String get btnUseTheirs => 'Tumia yao';

  @override
  String get confKeptMine => 'Thamani yako imehifadhiwa.';

  @override
  String confUsedTheirs(String remote) {
    return 'Imebadilishwa kuwa $remote. Itasawazishwa hivi karibuni.';
  }

  @override
  String get conflictDeletedTitle => 'Kitu ulichohariri kilifutwa kwingine';

  @override
  String conflictDeletedBody(String source, String subject, String noun) {
    return '$source alifuta $noun kwa $subject, lakini ulikuwa umebadilisha. Toleo lako lilihifadhiwa.';
  }

  @override
  String get btnDeleteIt => 'Kifute';

  @override
  String get confKeptVersion => 'Toleo lako limehifadhiwa.';

  @override
  String get confDeleted => 'Imefutwa. Itasawazishwa hivi karibuni.';

  @override
  String conflictMergedTitle(String source) {
    return 'Badiliko kutoka $source limeunganishwa';
  }

  @override
  String conflictMergedBody(String subject, String noun) {
    return '$noun kwa $subject sasa ina mabadiliko yote mawili.';
  }

  @override
  String get nounVisit => 'ziara';

  @override
  String get nounVitals => 'viashiria';

  @override
  String get nounPatient => 'rekodi';

  @override
  String get nounHousehold => 'kaya';

  @override
  String get fieldTemperature => 'joto la mwili';

  @override
  String get fieldSystolic => 'shinikizo la juu la damu';

  @override
  String get fieldDiastolic => 'shinikizo la chini la damu';

  @override
  String get fieldVisitType => 'aina ya ziara';

  @override
  String get fieldVisitTime => 'saa ya ziara';

  @override
  String get fieldCompletionTime => 'saa ya kukamilika';

  @override
  String get fieldPatientName => 'jina la mgonjwa';

  @override
  String get fieldName => 'jina';

  @override
  String get fieldHousehold => 'kaya';

  @override
  String get fieldHeadOfHousehold => 'mkuu wa kaya';

  @override
  String get fieldLocation => 'Mahali';

  @override
  String get valueNothing => 'hakuna';

  @override
  String get profileTitle => 'Wasifu';

  @override
  String profileNurse(String name) {
    return 'Nesi $name';
  }

  @override
  String profileSubCounty(String subCounty) {
    return 'Kaunti ndogo ya $subCounty';
  }

  @override
  String get deviceName => 'Jina la kifaa';

  @override
  String get deviceNameHelp =>
      'Vifaa vingine huliona jina hili mabadiliko yako yanapounganishwa.';

  @override
  String get languageTitle => 'Lugha';

  @override
  String get langSystem => 'Lugha ya simu';

  @override
  String get langEnglish => 'English';

  @override
  String get langSwahili => 'Kiswahili';

  @override
  String progressOf(int done, int total) {
    return '$done kati ya $total';
  }

  @override
  String get startupErrorTitle =>
      'Hifadhi salama ya simu hii haikuweza kufunguliwa';

  @override
  String get startupErrorBody =>
      'Ziara zako zilizohifadhiwa zinalindwa na ufunguo ambao hauwezi kusomwa sasa hivi. Jaribu tena. Ikiwa simu imewashwa upya hivi punde, ifungue kwanza.';

  @override
  String get startupRetry => 'Jaribu tena';

  @override
  String get startupReset => 'Futa data ya simu hii';

  @override
  String get startupResetTitle => 'Futa data ya simu hii?';

  @override
  String get startupResetBody =>
      'Mabadiliko ambayo hayajatumwa kwenye seva yatapotea. Ziara zilizosawazishwa zitapakuliwa tena.';

  @override
  String get startupResetConfirm => 'Futa';

  @override
  String get cancel => 'Ghairi';

  @override
  String get registerPatient => 'Sajili mgonjwa';

  @override
  String get registerNewPatient => 'Sajili mgonjwa mpya';

  @override
  String get fieldFullName => 'Jina kamili';

  @override
  String get fieldHouseholdHead => 'Mkuu wa kaya';

  @override
  String get fieldHouseholdHeadHint => 'Acha wazi ikiwa ni mgonjwa mwenyewe';

  @override
  String get savePatient => 'Hifadhi mgonjwa';

  @override
  String get noPatientsYet =>
      'Hakuna wagonjwa bado. Sajili mgonjwa wako wa kwanza kuanza.';

  @override
  String get fieldPhoneNumber => 'Namba ya simu';

  @override
  String get fieldPhoneNumberHint => 'Si lazima';

  @override
  String get phoneNumberInvalid =>
      'Weka namba sahihi ya simu, mf. 0712 345 678';

  @override
  String get fieldAccountStatus => 'Hali ya akaunti';

  @override
  String get statusActive => 'Hai';

  @override
  String get statusInactive => 'Haifanyi kazi';

  @override
  String markInactiveTitle(String name) {
    return 'Weka $name kama hafanyi kazi?';
  }

  @override
  String markActiveTitle(String name) {
    return 'Weka $name kama yuko hai?';
  }

  @override
  String get markStatusBody =>
      'Hii inahifadhiwa kwenye simu na kutumwa unaposawazisha.';

  @override
  String get markInactiveAction => 'Weka haifanyi kazi';

  @override
  String get markActiveAction => 'Weka hai';

  @override
  String patientStatusChanged(String name, String status) {
    return '$name sasa ni $status.';
  }

  @override
  String get noPhoneNumber => 'Hakuna namba ya simu';
}
