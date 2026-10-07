import '../../../core/db/enums.dart';

/// A patient being registered. The household is created with the patient;
/// [headName] defaults to the patient's own name when left blank.
class NewPatient {
  NewPatient({
    required String fullName,
    String? headName,
    required String location,
    String? phoneNumber,
    this.accountStatus = AccountStatus.active,
  }) : fullName = fullName.trim(),
       headName = (headName == null || headName.trim().isEmpty)
           ? fullName.trim()
           : headName.trim(),
       location = location.trim(),
       phoneNumber = (phoneNumber == null || phoneNumber.trim().isEmpty)
           ? null
           : phoneNumber.trim();

  final String fullName;
  final String headName;
  final String location;

  /// Optional; null when left blank.
  final String? phoneNumber;
  final AccountStatus accountStatus;

  bool get isValid =>
      fullName.isNotEmpty && location.isNotEmpty && isValidPhone(phoneNumber);

  /// Blank is fine. Otherwise 7 to 15 digits, with an optional leading `+` and
  /// spaces or dashes between them.
  static bool isValidPhone(String? v) {
    if (v == null || v.trim().isEmpty) return true;
    final t = v.trim();
    if (!RegExp(r'^\+?[0-9][0-9 \-]*$').hasMatch(t)) return false;
    final digits = t.replaceAll(RegExp(r'[^0-9]'), '').length;
    return digits >= 7 && digits <= 15;
  }
}
