class NewVisit {
  const NewVisit({
    required this.patientId,
    required this.patientName,
    required this.visitType,
    required this.scheduledAt,
  });

  final String patientId;
  final String patientName;
  final String visitType;
  final DateTime scheduledAt;
}

/// Fields of a visit that can be edited. Null means "unchanged".
class VisitChanges {
  const VisitChanges({this.visitType, this.scheduledAt, this.completedAt});

  final String? visitType;
  final DateTime? scheduledAt;
  final DateTime? completedAt;

  bool get isEmpty =>
      visitType == null && scheduledAt == null && completedAt == null;
}

const visitTypes = [
  'Antenatal check',
  'BP follow-up',
  'Child immunisation',
  'Malaria test',
  'Home visit: new household',
  'Diabetes review',
];
