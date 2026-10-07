/// Who is signed in. Fixed until real sign-in exists.
class NurseProfile {
  const NurseProfile({required this.firstName, required this.subCounty});

  final String firstName;
  final String subCounty;
}

const demoNurse = NurseProfile(firstName: 'Wairimu', subCounty: 'Kinangop');
