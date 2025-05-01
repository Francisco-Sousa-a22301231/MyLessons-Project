import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mylessons_frontend/services/api_service.dart';

class ExtrasModal extends StatefulWidget {
  final int lessonId;
  final int schoolId;
  final int subjectId;

  const ExtrasModal({
    Key? key,
    required this.lessonId,
    required this.schoolId,
    required this.subjectId,
  }) : super(key: key);

  @override
  _ExtrasModalState createState() => _ExtrasModalState();
}

class _ExtrasModalState extends State<ExtrasModal> {
  bool isLoading = true;
  List<Map<String, dynamic>> availableEquipments = [];
  Set<String> equipmentNames = {};
  Map<String, Map<bool, List<String>>> equipmentSizes = {};
  bool? selectedForKids;

  // Toggle between extra students and equipment
  String extrasType = 'student';
  int extraStudents = 0;
  String? selectedEquipmentName;
  String? selectedEquipmentSize;

  @override
  void initState() {
    super.initState();
    fetchEquipments();
  }

  Future<void> fetchEquipments() async {
    print("subject_id = ${widget.subjectId}");
    try {
      final url = Uri.parse(
        '$baseUrl/api/schools/${widget.schoolId}/equipments/${widget.subjectId}',
      );
      final response = await http.get(url, headers: await getAuthHeaders());
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final List<Map<String, dynamic>> filtered = [];
        for (var item in data) {
          if (item['is_being_used'] == false &&
              item['nothing_missing'] == true) {
            filtered.add(Map<String, dynamic>.from(item));
          }
        }
        setState(() {
          availableEquipments = filtered;
          equipmentNames.clear();
          equipmentSizes.clear();

          for (var eq in filtered) {
            final name = eq['name'] as String;
            final isKids = eq['is_for_kids'] as bool? ?? false;
            final sizeVal = (eq['size'] as String?) ?? '';

            equipmentNames.add(name);
            equipmentSizes.putIfAbsent(name, () => {});
            equipmentSizes[name]!.putIfAbsent(isKids, () => []).add(sizeVal);
          }

          // Remove duplicate sizes within each category
          equipmentSizes.updateAll((_, ageMap) {
            ageMap.updateAll((_, list) => list.toSet().toList());
            return ageMap;
          });

          isLoading = false;
        });
      } else {
        throw Exception('Failed to load equipments');
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

void onSave() async {
  final payload = {
    'lesson_id': widget.lessonId,
    'equipment': {
      'name': selectedEquipmentName,
      'size': selectedEquipmentSize,
    },
  };

  // get your auth headers, then force JSON
  final headers = await getAuthHeaders();
  headers['Content-Type'] = 'application/json';

  final resp = await http.post(
    Uri.parse('$baseUrl/api/lessons/extras/'),
    headers: headers,
    body: jsonEncode(payload),
  );

  // debug: log the raw response body too
  print('Response (${resp.statusCode}): ${resp.body}');

  if (resp.statusCode == 200) {
    Navigator.pop(context, true);
  } else {
    final error = jsonDecode(resp.body);
    print('Error: ${error['detail'] ?? resp.statusCode}');
  }
}


  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add Extras',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Toggle between Students / Equipment
          Center(
            child: ToggleButtons(
              isSelected: [
                extrasType == 'student',
                extrasType == 'equipment',
              ],
              onPressed: (index) {
                setState(() {
                  extrasType = index == 0 ? 'student' : 'equipment';
                  // Reset fields when switching
                  if (extrasType == 'student') {
                    selectedEquipmentName = null;
                    selectedEquipmentSize = null;
                    selectedForKids = null;
                  } else {
                    extraStudents = 0;
                  }
                });
              },
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('Students'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('Equipment'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Student count input
          if (extrasType == 'student') ...[
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Number of extra students',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                extraStudents = int.tryParse(value) ?? 0;
              },
            ),

            // Equipment selection flow
          ] else ...[
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              // 1) Choose equipment name
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Equipment',
                  border: OutlineInputBorder(),
                ),
                items: equipmentNames
                    .map((name) =>
                        DropdownMenuItem(value: name, child: Text(name)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedEquipmentName = value;
                    selectedEquipmentSize = null;
                    selectedForKids = null;
                  });
                },
                value: selectedEquipmentName,
              ),
              const SizedBox(height: 16),

              if (selectedEquipmentName != null) ...[
                // 2) Pick Kids or Adult
                DropdownButtonFormField<bool>(
                  decoration: const InputDecoration(
                    labelText: 'Size category',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: false, child: Text('Adult')),
                    DropdownMenuItem(value: true, child: Text('Kids')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      selectedForKids = val;
                      selectedEquipmentSize = null;
                    });
                  },
                  value: selectedForKids,
                ),
                const SizedBox(height: 16),

                // 3) Then pick the size within that category
                if (selectedForKids != null) ...[
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Size',
                      border: OutlineInputBorder(),
                    ),
                    items: equipmentSizes[selectedEquipmentName]![
                            selectedForKids!]!
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        selectedEquipmentSize = val;
                      });
                    },
                    value: selectedEquipmentSize,
                  ),
                ],
              ],
            ],
          ],

          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onSave,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
