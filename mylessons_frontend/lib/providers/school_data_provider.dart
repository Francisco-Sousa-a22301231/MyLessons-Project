import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../services/school_service.dart';

/// Provides the full school details as fetched from the API, and exposes
/// nested lists for locations, subjects, and equipments.
class SchoolDataProvider extends ChangeNotifier {
  Map<String, dynamic>? _schoolDetails;
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic>? get schoolDetails => _schoolDetails;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<dynamic> get locations =>
      _schoolDetails?['locations'] as List<dynamic>? ?? [];

  List<dynamic> get subjects =>
      _schoolDetails?['subjects'] as List<dynamic>? ?? [];

  List<dynamic> get equipments =>
      _schoolDetails?['equipment'] as List<dynamic>? ?? [];

  /// Fetches and stores the entire school details.
  Future<void> loadSchoolDetails() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await fetchSchoolDetails();
      _schoolDetails = data;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createSchool(String schoolName) async {
  final url = Uri.parse('$baseUrl/api/schools/create/');
  final headers = await getAuthHeaders();

  final payload = jsonEncode({'school_name': schoolName});
  final response = await http.post(url, headers: headers, body: payload);

  if (response.statusCode != 201) {
    // Decode the response using UTF-8 before parsing JSON
    final decodedBody = utf8.decode(response.bodyBytes);
    final data = jsonDecode(decodedBody);
    throw Exception(data['error'] ?? 'Error creating school');
  }
}

  /// Convenience for refreshing equipments only.
  Future<void> refreshEquipments() async {
    if (_schoolDetails == null) return;
    await loadSchoolDetails();
  }
}
