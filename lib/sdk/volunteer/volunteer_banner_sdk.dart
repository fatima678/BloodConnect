import 'package:cloud_firestore/cloud_firestore.dart';

class VolunteerBannerSdk {
  VolunteerBannerSdk._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String bannersCollection = 'banners';

  static Future<List<String>> fetchBannerImages() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection(bannersCollection)
        .get();

    final List<String> bannerImages = [];
    final Set<String> addedUrls = {};

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      final Map<String, dynamic> data = doc.data();

      if (!_isBannerActive(data)) {
        continue;
      }

      final String? imageUrl = _extractImageUrl(data);

      if (imageUrl != null && !addedUrls.contains(imageUrl)) {
        bannerImages.add(imageUrl);
        addedUrls.add(imageUrl);
      }
    }

    return bannerImages;
  }

  static String? _extractImageUrl(Map<String, dynamic> data) {
    final List<dynamic> possibleFields = [
      data['image_url'],
      data['url'],
      data['image'],
      data['imageUrl'],
      data['banner_image'],
      data['bannerImage'],
    ];

    for (final dynamic value in possibleFields) {
      if (value == null) continue;

      final String url = value.toString().trim();

      if (url.isNotEmpty) {
        return url;
      }
    }

    return null;
  }

  static bool _isBannerActive(Map<String, dynamic> data) {
    final dynamic isActive = data['is_active'];
    final dynamic status = data['status'];

    if (isActive is bool && isActive == false) {
      return false;
    }

    if (status != null) {
      final String statusValue = status.toString().trim().toLowerCase();

      if (statusValue == 'inactive' ||
          statusValue == 'disabled' ||
          statusValue == 'deleted') {
        return false;
      }
    }

    return true;
  }
}