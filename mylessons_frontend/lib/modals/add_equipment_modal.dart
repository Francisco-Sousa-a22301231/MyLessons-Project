// lib/modals/add_equipment_modal.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../providers/school_data_provider.dart';

class AddEquipmentModal extends StatefulWidget {
  final int schoolId;
  const AddEquipmentModal({Key? key, required this.schoolId}) : super(key: key);

  @override
  _AddEquipmentModalState createState() => _AddEquipmentModalState();
}

class _AddEquipmentModalState extends State<AddEquipmentModal> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Equipment fields
  final TextEditingController _nameCtrl = TextEditingController();
  int? _locationId;
  String _state = 'new';
  final TextEditingController _sizeCtrl = TextEditingController();
  bool _isForKids = false;
  final TextEditingController _descriptionCtrl = TextEditingController();
  final TextEditingController _brandCtrl = TextEditingController();
  List<int> _selectedSubjects = [];
  File? _photoFile;

  // Inline create-location fields
  bool _showNewLocationForm = false;
  final TextEditingController _newLocNameCtrl = TextEditingController();
  final TextEditingController _newLocAddressCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sizeCtrl.dispose();
    _descriptionCtrl.dispose();
    _brandCtrl.dispose();
    _newLocNameCtrl.dispose();
    _newLocAddressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _photoFile = File(picked.path));
  }

  Future<void> _createLocationInline() async {
    final name = _newLocNameCtrl.text.trim();
    final address = _newLocAddressCtrl.text.trim();
    if (name.isEmpty || address.isEmpty) return;
    setState(() => _isLoading = true);
    final url = Uri.parse('$baseUrl/api/schools/create_location/');
    final headers = await getAuthHeaders();
    final payload = jsonEncode({
      'location_name': name,
      'location_address': address,
      'school_id': widget.schoolId,
    });
    final res = await http.post(url, headers: headers, body: payload);
    if (res.statusCode == 200) {
      // parse response: expect created location id
      final data = jsonDecode(res.body);
      final newId = data['location_id'] as int?;
      // reload provider
      await context.read<SchoolDataProvider>().loadSchoolDetails();
      setState(() {
        _showNewLocationForm = false;
        _locationId = newId;
      });
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: \${res.body}')));
    }
    setState(() => _isLoading = false);
  }

Future<void> _submit() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isLoading = true);

  // 1) Create equipment (JSON only)
  final createUri = Uri.parse('$baseUrl/api/schools/create_equipment/');
  final createBody = {
    'name':          _nameCtrl.text.trim(),
    'school':        widget.schoolId,
    'location':      _locationId,
    'state':         _state,
    'is_being_used': false,
    'nothing_missing': true,
    'sports':        _selectedSubjects,  // List<int>
    'size':          _sizeCtrl.text.trim(),
    'is_for_kids':   _isForKids,
    'description':   _descriptionCtrl.text.trim(),
    'brand':         _brandCtrl.text.trim(),
  };

  final createRes = await http.post(
    createUri,
    headers: {
      'Content-Type': 'application/json',
      ...await getAuthHeaders(),
    },
    body: jsonEncode(createBody),
  );

  if (createRes.statusCode != 201) {
    final err = createRes.body;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('Error creating: $err')));
    return;
  }

  // parse out the new equipment's ID
  final created = jsonDecode(createRes.body);
  final int equipmentId = created['id'];

  // 2) If there's a photo, upload it via PATCH
  if (_photoFile != null) {
    final patchUri = Uri.parse('$baseUrl/api/schools/create_equipment/$equipmentId/');
    final patchReq = http.MultipartRequest('PATCH', patchUri)
      ..headers.addAll(await getAuthHeaders())
      ..files.add(
        await http.MultipartFile.fromPath('photo', _photoFile!.path),
      );

    final patchRes = await patchReq.send();
    final patchBody = await patchRes.stream.bytesToString();
    if (patchRes.statusCode != 200) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Error uploading photo: $patchBody')));
      return;
    }
  }

  // 3) Success!
  await context.read<SchoolDataProvider>().refreshEquipments();
  Navigator.pop(context, true);
  setState(() => _isLoading = false);
}

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SchoolDataProvider>();
    final locations = provider.locations;
    final subjects = provider.subjects;
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add Equipment',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                // Name
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder()),
                  validator: (v) => v == null || v.isEmpty
                      ? 'Required'
                      : null,
                ),
                const SizedBox(height: 12),

                // Location or inline create
                if (!_showNewLocationForm) ...[
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        decoration: const InputDecoration(
                            labelText: 'Location',
                            border: OutlineInputBorder()),
                        value: _locationId,
                        items: locations
                            .map((loc) => DropdownMenuItem<int>(
                                  value: loc['location_id'],
                                  child: Text(
                                      loc['location_name'] ?? ''),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _locationId = v),
                        validator: (v) => v == null
                            ? 'Required'
                            : null,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_location),
                      onPressed: () =>
                          setState(() => _showNewLocationForm = true),
                    ),
                  ]),
                ] else ...[
                  // Inline create location form
                  const Text('New Location',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _newLocNameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder()),
                    validator: (v) => v == null || v.isEmpty
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _newLocAddressCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Address',
                        border: OutlineInputBorder()),
                    validator: (v) => v == null || v.isEmpty
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    ElevatedButton(
                      onPressed: _createLocationInline,
                      child: const Text('Create Location'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () =>
                          setState(() => _showNewLocationForm = false),
                      child: const Text('Cancel'),
                    ),
                  ]),
                ],
                const SizedBox(height: 12),

                // Photo picker
                Center(
                  child: Column(children: [
                    if (_photoFile != null)
                      Image.file(_photoFile!, height: 100),
                    TextButton.icon(
                      icon: const Icon(Icons.photo),
                      label: const Text('Pick Photo'),
                      onPressed: _pickPhoto,
                    ),
                  ]),
                ),
                const SizedBox(height: 12),

                // State dropdown
                DropdownButtonFormField<String>(
                  value: _state,
                  decoration: const InputDecoration(
                      labelText: 'State',
                      border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(
                        value: 'new', child: Text('New')),
                    DropdownMenuItem(
                        value: 'used', child: Text('Used')),
                    DropdownMenuItem(
                        value: 'damaged', child: Text('Damaged')),
                    DropdownMenuItem(
                        value: 'something_missing',
                        child: Text('Something Missing')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _state = v);
                  },
                ),
                const SizedBox(height: 12),

                // Subjects multi-select
                InputDecorator(
                  decoration: const InputDecoration(
                      labelText: 'Subjects',
                      border: OutlineInputBorder()),
                  child: Wrap(
                    spacing: 8,
                    children: subjects.map<Widget>((sub) {
                      final id = sub['subject_id'] as int;
                      final sel = _selectedSubjects.contains(id);
                      return FilterChip(
                        label: Text(sub['subject_name'] ?? ''),
                        selected: sel,
                        onSelected: (yes) => setState(() {
                          yes
                              ? _selectedSubjects.add(id)
                              : _selectedSubjects.remove(id);
                        }),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // Size, kids, description, brand...
                TextFormField(
                  controller: _sizeCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Size',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Is for kids'),
                  value: _isForKids,
                  onChanged: (v) =>
                      setState(() => _isForKids = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _brandCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Brand',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),

                // Submit
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange),
                        child: const SizedBox(
                          width: double.infinity,
                          child:
                              Center(child: Text('Create Equipment')),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
