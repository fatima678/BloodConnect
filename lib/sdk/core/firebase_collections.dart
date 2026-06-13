// lib/sdk/core/firebase_collections.dart

class FirebaseCollections {
  FirebaseCollections._();

  static const String users = 'users';
  static const String rolesDoc = 'roles';

  static const String patients = 'patients';
  static const String donors = 'donors';
  static const String teamVolunteers = 'team_volunteers';
  static const String admins = 'admins';

  static String roleCollection(String role) {
    switch (role.trim().toLowerCase()) {
      case 'patient':
        return patients;
      case 'donor':
        return donors;
      case 'team_volunteer':
      case 'volunteer':
        return teamVolunteers;
      case 'admin':
        return admins;
      default:
        throw Exception('Invalid user role.');
    }
  }
}