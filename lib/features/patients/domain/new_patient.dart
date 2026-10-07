/// A patient being registered. The household is created with the patient;
/// [headName] defaults to the patient's own name when left blank.
class NewPatient {
  NewPatient({
    required String fullName,
    String? headName,
    required String location,
  }) : fullName = fullName.trim(),
       headName = (headName == null || headName.trim().isEmpty)
           ? fullName.trim()
           : headName.trim(),
       location = location.trim();

  final String fullName;
  final String headName;
  final String location;

  bool get isValid => fullName.isNotEmpty && location.isNotEmpty;
}
