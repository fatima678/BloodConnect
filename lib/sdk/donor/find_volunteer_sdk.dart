import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DonorFindVolunteerModel {
  final String uid;
  final String name;
  final String location;
  final String phone;
  final String bloodGroup;
  final String photoUrl;
  final String status;

  const DonorFindVolunteerModel({
    required this.uid,
    required this.name,
    required this.location,
    required this.phone,
    required this.bloodGroup,
    required this.photoUrl,
    required this.status,
  });

  bool get isActive => status.trim().toLowerCase() != 'inactive';

  factory DonorFindVolunteerModel.fromFirestore({
    required String docId,
    required Map<String, dynamic> data,
  }) {
    String readString(List<String> keys) {
      for (final key in keys) {
        final value = data[key];

        if (value == null) continue;

        final text = value.toString().trim();

        if (text.isNotEmpty && text.toLowerCase() != 'null') {
          return text;
        }
      }

      return '';
    }

    return DonorFindVolunteerModel(
      uid: readString(['uid']).isNotEmpty ? readString(['uid']) : docId,
      name: readString(['name']),
      location: readString(['location', 'address']),
      phone: readString(['phone', 'phone_number']),
      bloodGroup: readString(['blood_group', 'bloodGroup']),
      photoUrl: readString(['photo_url', 'photoUrl']),
      status: readString(['status']).isNotEmpty ? readString(['status']) : 'active',
    );
  }
}

class DonorFindVolunteerSdk {
  DonorFindVolunteerSdk._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _teamVolunteerCollection {
    return _firestore
        .collection('users')
        .doc('roles')
        .collection('team_volunteers');
  }

  static Future<List<DonorFindVolunteerModel>> fetchVolunteers() async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      throw Exception('Session not found. Please login again.');
    }

    final snapshot = await _teamVolunteerCollection.get();

    final volunteers = snapshot.docs.map((doc) {
      return DonorFindVolunteerModel.fromFirestore(
        docId: doc.id,
        data: Map<String, dynamic>.from(doc.data()),
      );
    }).where((volunteer) {
      return volunteer.isActive &&
          volunteer.name.trim().isNotEmpty &&
          volunteer.phone.trim().isNotEmpty;
    }).toList();

    volunteers.sort((a, b) {
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return volunteers;
  }
}