// lib/pages/manage_school.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../modals/add_equipment_modal.dart';
import '../modals/add_staff_modal.dart';
import '../modals/equipment_details_modal.dart';
import '../modals/payment_modal.dart';
import '../modals/service_modal.dart';
import '../modals/subject_modal.dart';
import '../modals/location_modal.dart';
import '../providers/school_data_provider.dart';

class SchoolSetupPage extends StatefulWidget {
  final bool isCreatingSchool;
  final Future<void> Function() fetchProfileData;

  const SchoolSetupPage({
    Key? key,
    this.isCreatingSchool = false,
    required this.fetchProfileData,
  }) : super(key: key);

  @override
  _SchoolSetupPageState createState() => _SchoolSetupPageState();
}

class _SchoolSetupPageState extends State<SchoolSetupPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _schoolNameController = TextEditingController();
  bool _isCreated = false;

  final List<String> _tabLabels = [
    'Service',
    'Staff',
    'Staff Payment',
    'Subject',
    'Equipment',
    'Location',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this)
      ..addListener(() => setState(() {}));
    if (!widget.isCreatingSchool) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<SchoolDataProvider>().loadSchoolDetails();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _schoolNameController.dispose();
    super.dispose();
  }

  Future<void> _onCreateSchool() async {
    final name = _schoolNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a school name')),
      );
      return;
    }
    try {
      await context.read<SchoolDataProvider>().createSchool(name);
      _isCreated = true;
      await widget.fetchProfileData();
      await context.read<SchoolDataProvider>().loadSchoolDetails();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create school: $e')),
      );
    }
  }

  Future<void> _onBottomButtonPressed() async {
    final provider = context.read<SchoolDataProvider>();
    final details = provider.schoolDetails!;
    final schoolId = details['school_id'] as int;

    switch (_tabController.index) {
      case 0:
        await showAddEditServiceModal(context, details);
        break;
      case 1:
        await showAddStaffModal(context);
        break;
      case 2:
        await showPaymentTypeModal(
          context,
          details,
          _schoolNameController,
          () async {},
        );
        break;
      case 3:
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => SubjectModal(schoolId: schoolId),
        );
        break;
      case 4:
        await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          builder: (_) => AddEquipmentModal(schoolId: schoolId),
        );
        break;
      case 5:
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => LocationModal(schoolId: schoolId),
        );
        break;
    }

    await provider.loadSchoolDetails();
  }

  String _getBottomButtonLabel() =>
      'Add ${_tabLabels[_tabController.index]}';

  @override
  Widget build(BuildContext context) {
    return Consumer<SchoolDataProvider>(
      builder: (context, provider, child) {
        // Always show a spinner in a scaffold until we have real details
        final details = provider.schoolDetails;
        if (provider.isLoading || details == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(widget.isCreatingSchool
                  ? 'School Setup'
                  : 'School Settings'),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        // We now know `details` is non-null and `isLoading` is false
        final String? critical = details['critical_message'] as String?;

        // If still in creation mode, show the create form
        if (widget.isCreatingSchool && !_isCreated) {
          return Scaffold(
            appBar: AppBar(title: const Text('School Setup')),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create School',
                    style: GoogleFonts.lato(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _schoolNameController,
                    decoration: const InputDecoration(
                      labelText: 'School Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: ElevatedButton(
                      onPressed: _onCreateSchool,
                      child: const Text('Create School'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Main tabbed UI
        final appBarTitle = details['school_name'] != null
            ? '${details['school_name']} Settings'
            : 'School Settings';

        return DefaultTabController(
          length: 6,
          child: Scaffold(
            appBar: AppBar(
              title: Text(appBarTitle),
              bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: const [
                  Tab(text: 'Services'),
                  Tab(text: 'Staff'),
                  Tab(text: 'Staff Payments'),
                  Tab(text: 'Subjects'),
                  Tab(text: 'Equipments'),
                  Tab(text: 'Locations'),
                ],
              ),
            ),
            body: Column(
              children: [
                if (critical != null && critical.isNotEmpty)
                  Container(
                    width: double.infinity,
                    color: Colors.redAccent,
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            critical,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Stack(
                    children: [
                      TabBarView(
                        controller: _tabController,
                        children: [
                          _buildServicesTab(details),
                          _buildStaffTab(details),
                          _buildStaffPaymentsTab(details),
                          _buildSubjectsTab(details),
                          _buildEquipmentsTab(details),
                          _buildLocationsTab(details),
                        ],
                      ),
                      Positioned(
                        bottom: 24,
                        left: 24,
                        right: 24,
                        child: ElevatedButton(
                          onPressed: _onBottomButtonPressed,
                          style: ElevatedButton.styleFrom(
                            shape: const StadiumBorder(),
                            backgroundColor: Colors.orange,
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            _getBottomButtonLabel(),
                            style: const TextStyle(
                                color: Colors.black, fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],  
            ),
          ),
        );
      },
    );
  }

  Widget _buildServicesTab(Map<String, dynamic> details) {
    final raw = details['services'];
    final List services = raw is List
        ? raw
        : raw is Map
            ? raw.values.toList()
            : [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: services.isEmpty
          ? const Text('No services available.')
          : Column(
              children: services.map((s) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 24),
                  child: ListTile(
                    title: Text(
                      s['name'] ?? 'No Name',
                      style:
                          const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit,
                          color: Colors.orange),
                      onPressed: () =>
                          showAddEditServiceModal(context, details,
                              service: s),
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildStaffTab(Map<String, dynamic> details) {
    final List staff = details['staff'] as List? ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: staff.isEmpty
          ? const Text('No staff data available.')  
          : Column(
              children: staff.map((s) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 24),
                  child: ListTile(
                    title: Text(s['user_name'] ?? 'No Name'),
                    subtitle: Text((s['roles'] as List).join(', ')),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit,
                          color: Colors.orange),
                      onPressed: () {},
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildStaffPaymentsTab(Map<String, dynamic> details) {
    final Map<String, dynamic> paymentTypes =
        details['payment_types'] as Map<String, dynamic>? ?? {};
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: paymentTypes.isEmpty
          ? const Text('No payment types available.')
          : Column(
              children: paymentTypes.entries.map((e) {
                final pt = e.value as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.only(bottom: 24),
                  child: ListTile(
                    title: Text(pt['name'] ?? 'No Name'),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit,
                          color: Colors.orange),
                      onPressed: () {},
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildSubjectsTab(Map<String, dynamic> details) {
    final List subs = details['subjects'] as List? ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: subs.isEmpty
          ? const Text('No subjects available.')
          : Column(
              children: subs.map((sub) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 24),
                  child: ListTile(
                    title:
                        Text(sub['subject_name'] ?? 'No Name'),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildEquipmentsTab(Map<String, dynamic> details) {
  final List eqs = details['equipment'] as List? ?? [];
  return SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: eqs.isEmpty
        ? const Text('No equipments available.')
        : Column(
            children: eqs.map((e) {
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  title: Text(e['equipment_name'] ?? 'No Name'),
                  subtitle: Text(
                    '${e['location_name'] ?? ''} • ${e['size'] ?? ''}',
                  ),
                  trailing: TextButton(
                    child: const Text('Details'),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => EquipmentDetailsModal(
                          equipment: e,
                        ),
                      );
                    },
                  ),
                ),
              );
            }).toList(),
          ),
  );
}

  Widget _buildLocationsTab(Map<String, dynamic> details) {
    final List locs = details['locations'] as List? ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: locs.isEmpty
          ? const Text('No locations available.')
          : Column(
              children: locs.map((l) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 24),
                  child: ListTile(
                    title:
                        Text(l['location_name'] ?? 'No Name'),
                    subtitle: Text(l['address'] ?? ''),
                  ),
                );
              }).toList(),
            ),
    );
  }
}
