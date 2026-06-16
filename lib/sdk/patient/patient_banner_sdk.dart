import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PatientBannerSdk {
  PatientBannerSdk._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String bannersCollection = 'banners';

  static Future<List<String>> fetchBannerImages() async {
    debugPrint(
      'Fetching banners from Firestore collection: $bannersCollection',
    );

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection(bannersCollection)
        .get();

    debugPrint('Total banner documents found: ${snapshot.docs.length}');

    final List<String> bannerImages = [];
    final Set<String> addedUrls = {};

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      final Map<String, dynamic> data = doc.data();

      debugPrint('Banner doc id: ${doc.id}');
      debugPrint('Banner data: $data');

      final String status = (data['status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      if (status.isNotEmpty && status != 'active') {
        debugPrint('Skipped inactive banner: ${doc.id}');
        continue;
      }

      final String imageUrl = (data['image_url'] ?? '').toString().trim();

      if (imageUrl.isEmpty) {
        debugPrint('Skipped banner because image_url is empty: ${doc.id}');
        continue;
      }

      if (!addedUrls.contains(imageUrl)) {
        bannerImages.add(imageUrl);
        addedUrls.add(imageUrl);
      }
    }

    debugPrint('Final banner images count: ${bannerImages.length}');
    return bannerImages;
  }
}