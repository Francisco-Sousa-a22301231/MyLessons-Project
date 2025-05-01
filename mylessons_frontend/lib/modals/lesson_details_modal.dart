import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:mylessons_frontend/modals/instructors_modal.dart';
import 'package:provider/provider.dart';
import '../providers/school_provider.dart';
import '../services/api_service.dart';
import '../widgets/contact_school_widget.dart';
import '../widgets/handle_lesson_report.dart';
import 'extras_modal.dart';
import 'students_modal.dart';
import 'subject_modal.dart'; // Ensure this file exports SubjectModal
import 'location_modal.dart'; // Ensure this file exports LocationModal
import '../providers/pack_details_provider.dart';
import '../providers/lessons_modal_provider.dart';
import 'package:mylessons_frontend/modals/pack_details_modal.dart';
import 'parents_modal.dart';
import '../providers/home_page_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// AnimatedGridItem: Fades and slides each grid item into view, with a staggered delay.
class AnimatedGridItem extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const AnimatedGridItem({Key? key, required this.child, required this.delay})
      : super(key: key);

  @override
  _AnimatedGridItemState createState() => _AnimatedGridItemState();
}

class _AnimatedGridItemState extends State<AnimatedGridItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _slideAnimation = Tween<Offset>(
            begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

class LessonDetailsPage extends StatefulWidget {
  final dynamic lesson;

  const LessonDetailsPage({Key? key, required this.lesson}) : super(key: key);

  @override
  _LessonDetailsPageState createState() => _LessonDetailsPageState();
}

class _LessonDetailsPageState extends State<LessonDetailsPage> {
  late Future<Map<String, dynamic>?> _lessonDetailsFuture;
  late final int lessonId;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    lessonId = widget.lesson['id'] ?? widget.lesson['lesson_id'];
    _refreshLessonDetails();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _refreshLessonDetails() {
    setState(() {
      _lessonDetailsFuture = fetchLessonDetails(lessonId);
    });
  }

  Future<void> _showMapOptionsBottomModal(String address) async {
    // Encode the address so it can be safely used in a URL.
    final encodedAddress = Uri.encodeComponent(address);

    // Build a list of map options based on the platform.
    List<Map<String, String>> options = [];

    if (Platform.isIOS) {
      options.add({
        'name': 'Apple Maps',
        'url': 'http://maps.apple.com/?daddr=$encodedAddress',
      });
      options.add({
        'name': 'Google Maps',
        'url': 'comgooglemaps://?daddr=$encodedAddress',
      });
      options.add({
        'name': 'Waze',
        'url': 'waze://?q=$encodedAddress',
      });
    } else {
      // For Android: Apple Maps is not available.
      options.add({
        'name': 'Google Maps',
        'url': 'google.navigation:q=$encodedAddress',
      });
      options.add({
        'name': 'Waze',
        'url': 'waze://?q=$encodedAddress',
      });
    }

    // Show a bottom modal allowing the user to choose.
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return ListView.separated(
          shrinkWrap: true,
          itemCount: options.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final option = options[index];
            return ListTile(
              title: Text(option['name']!),
              onTap: () async {
                // Dismiss the modal.
                Navigator.pop(context);
                final url = option['url']!;
                final Uri mapUri = Uri.parse(url);
                if (await canLaunchUrl(mapUri)) {
                  await launchUrl(mapUri, mode: LaunchMode.externalApplication);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Could not launch ${option['name']}')),
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to HomePageProvider so that if currentRole updates, this widget rebuilds.
    final homeProvider = Provider.of<HomePageProvider>(context);
    final lessonProvider =
        Provider.of<LessonModalProvider>(context, listen: false);
    final currentRole = homeProvider.currentRole;

    return Scaffold(
      appBar: AppBar(
        title: Text("Lesson Details"),
      ),
      body: AnimatedSwitcher(
        duration: Duration(milliseconds: 300),
        child: FutureBuilder<Map<String, dynamic>?>(
          key: ValueKey(_lessonDetailsFuture),
          future: _lessonDetailsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Lesson Details",
                        style: GoogleFonts.lato(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      const Text("Could not fetch lesson details."),
                    ],
                  ),
                ),
              );
            }

            final details = snapshot.data!;

            // Deduplicate parents from packs.
            List<dynamic> allParents = [];
            if (details.containsKey("packs") && details["packs"] is List) {
              for (var pack in details["packs"]) {
                if (pack.containsKey("parents") && pack["parents"] is List) {
                  allParents.addAll(pack["parents"]);
                }
              }
            }
            final Map<String, dynamic> uniqueParentsMap = {};
            for (var parent in allParents) {
              final String id = parent['id'];
              uniqueParentsMap[id] = parent;
            }
            final List<dynamic> uniqueParents =
                uniqueParentsMap.values.toList();

            // Compute values.
            final date = details['date'] ?? '';
            final startTime = details['start_time'] ?? '';
            final endTime = details['end_time'] ?? '';
            final time = startTime.isNotEmpty && endTime.isNotEmpty
                ? '$startTime - $endTime'
                : (startTime.isNotEmpty ? startTime : endTime);
            final lessonNum = details['lesson_number']?.toString() ?? '';
            final numLessons = details['number_of_lessons']?.toString() ?? '';
            final lessonValue = (lessonNum.isNotEmpty && numLessons.isNotEmpty)
                ? '$lessonNum / $numLessons'
                : (lessonNum.isNotEmpty ? lessonNum : numLessons);
            final extras = details['extras'] ?? '';
            final students = details['students_name'] ?? '';
            final type = details['type'] ?? '';
            final instructors = details['instructors_name'] ?? '';
            final school = details['school_name'] ?? '';
            final location = details['location_name'] ?? '';
            final activity = details['subject'] ?? '';
            final isDone = details['is_done'];

            List<Map<String, dynamic>> gridItems = [];
            Map<String, IconData> leftIconMapping = {};
            List<String> labelsWithAction = [];
            Map<String, IconData> actionIconMapping = {};
            Map<String, String> actionNoteMapping = {};

            if (currentRole == "Parent") {
              gridItems = [
                {'label': 'Date', 'value': date},
                {'label': 'Time', 'value': time},
                {'label': 'Lesson', 'value': lessonValue},
                {'label': 'Subject', 'value': activity},
                {'label': 'Type', 'value': type},
                {'label': 'Students', 'value': students},
                {'label': 'Extras', 'value': extras},
                {'label': 'Instructors', 'value': instructors},
                {'label': 'School', 'value': school},
                {'label': 'Location', 'value': location},
              ];
              leftIconMapping = {
                'Date': Icons.calendar_today,
                'Time': Icons.access_time,
                'Lesson': Icons.confirmation_number,
                'Students': Icons.people,
                'Type': Icons.groups,
                'Subject': Icons.menu_book,
                'Extras': Icons.star,
                'Instructors': Icons.person_outline,
                'School': Icons.school,
                'Location': Icons.location_on,
              };
              labelsWithAction = [
                'Extras',
                'Instructors',
                'School',
                'Location'
              ];
              actionIconMapping = {
                'Extras': Icons.edit,
                'Instructors': Icons.phone,
                'School': Icons.phone,
                'Location': Icons.directions,
              };
              actionNoteMapping = {
                'Extras': 'Update extras',
                'Instructors': 'Contact instructor',
                'School': 'Contact school',
                'Location': 'Get directions',
              };
            } else if (currentRole == "Instructor" || currentRole == "Admin") {
              gridItems = [
                {'label': 'Date', 'value': date},
                {'label': 'Time', 'value': time},
                {'label': 'Is Done', 'value': isDone},
                {'label': 'Lesson', 'value': lessonValue},
                {'label': 'Subject', 'value': activity},
                {'label': 'Type', 'value': type},
                {'label': 'Students', 'value': students},
                {'label': 'Extras', 'value': extras},
                {'label': 'Instructors', 'value': instructors},
                {'label': 'School', 'value': school},
                {'label': 'Location', 'value': location},
              ];
              leftIconMapping = {
                'Date': Icons.calendar_today,
                'Time': Icons.access_time,
                'Lesson': Icons.confirmation_number,
                'Is Done': Icons.check_box,
                'Students': Icons.people,
                'Type': Icons.groups,
                'Subject': Icons.menu_book,
                'Extras': Icons.star,
                'Instructors': Icons.person_outline,
                'School': Icons.school,
                'Location': Icons.location_on,
              };
              labelsWithAction = [
                'Is Done',
                'Students',
                'Subject',
                'Extras',
                'Instructors',
                'School',
                'Location'
              ];
              actionIconMapping = {
                'Date': Icons.edit,
                'Time': Icons.edit,
                'Is Done': Icons.check_circle,
                'Students': Icons.edit,
                'Subject': Icons.edit,
                'Extras': Icons.edit,
                'Instructors': Icons.edit,
                'School': Icons.phone,
                'Location': Icons.edit,
              };
              actionNoteMapping = {
                'Date': 'Edit date',
                'Time': 'Edit time',
                'Is Done': 'Toggle completion',
                'Students': 'Edit students',
                'Subject': 'Edit subject',
                'Extras': 'Update extras',
                'Instructors': 'Edit Instructors',
                'School': 'Contact school',
                'Location': 'Edit Location',
              };
            }

            final nonActionItems = gridItems
                .where((item) => !labelsWithAction.contains(item['label']))
                .toList();
            final actionItems = gridItems
                .where((item) => labelsWithAction.contains(item['label']))
                .toList();
            final combinedItems = [...nonActionItems, ...actionItems];

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.jumpTo(0);
              }
            });

            return SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Manage Progress Card.
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading:
                          const Icon(Icons.dashboard, color: Colors.orange),
                      title: Text("Manage Progress",
                          style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
                      subtitle:
                          const Text("Update progress, skills, and goals"),
                      onTap: () async {
                        handleLessonReport(context, details);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Pack Details Card.
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading:
                          const Icon(Icons.dashboard, color: Colors.orange),
                      title: Text(
                        type == "private" ? "Pack" : "Packs",
                        style: GoogleFonts.lato(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        type == "private"
                            ? "View associated pack and its details"
                            : "View associated packs and its details",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () async {
                        if (details.containsKey("packs") &&
                            details["packs"] is List &&
                            details["packs"].isNotEmpty) {
                          final pack = details["packs"][0];
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PackDetailsPage(pack: pack),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("No associated pack found.")),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (uniqueParents.isNotEmpty) ...[
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: const Icon(Icons.people, color: Colors.orange),
                        title: Text("View Parents",
                            style:
                                GoogleFonts.lato(fontWeight: FontWeight.bold)),
                        subtitle: const Text("View parents for this lesson"),
                        onTap: () async {
                          await showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(16)),
                            ),
                            builder: (context) =>
                                ParentsModal(parents: uniqueParents),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Grid of details with animated grid items.
                  LayoutBuilder(
                    builder: (context, constraints) {
                      double spacing = 8.0;
                      double itemWidth = (constraints.maxWidth - spacing) / 2;
                      Widget buildCard(Map<String, dynamic> item,
                          {bool withAction = false}) {
                        final String label = item['label'];
                        final String value = item['value'].toString();
                        return SizedBox(
                          width: itemWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(minHeight: 80),
                                child: Card(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Icon(
                                          leftIconMapping[label] ??
                                              Icons.info_outline,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                label,
                                                style: GoogleFonts.lato(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14),
                                              ),
                                              Text(
                                                value,
                                                style: GoogleFonts.lato(
                                                    fontSize: 12),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (withAction)
                                          IconButton(
                                            icon: Icon(
                                              actionIconMapping[label] ??
                                                  Icons.arrow_forward,
                                              color: Colors.orange,
                                            ),
                                            onPressed: () async {
                                              if (label == "Is Done") {
                                                final result =
                                                    await lessonProvider
                                                        .toggleLessonCompletion(
                                                            lessonId);
                                                if (result != null &&
                                                    result.containsKey(
                                                        "status")) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(SnackBar(
                                                          content: Text(result[
                                                              "status"])));
                                                  await homeProvider
                                                      .fetchData();
                                                  _refreshLessonDetails();
                                                } else {
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) {
                                                      return AlertDialog(
                                                        content: const Text(
                                                            "To complete a lesson make sure the schedule has passed"),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                    context),
                                                            child: const Text(
                                                                "OK"),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  );
                                                }
                                              } else if (label == "Extras") {
                                                final bool? updated =
                                                    await showModalBottomSheet<
                                                        bool>(
                                                  context: context,
                                                  isScrollControlled: true,
                                                  shape:
                                                      const RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.vertical(
                                                            top:
                                                                Radius.circular(
                                                                    16)),
                                                  ),
                                                  builder: (_) => ExtrasModal(
                                                    lessonId: lessonId,
                                                    subjectId: details['subject_id'],
                                                    schoolId:
                                                        details['school_id'],
                                                  ),
                                                );
                                                if (updated == true) {
                                                  await homeProvider
                                                      .fetchData();
                                                  _refreshLessonDetails();
                                                }
                                              } else if (label == "Subject" &&
                                                  currentRole != "Parent") {
                                                bool? updated =
                                                    await showModalBottomSheet<
                                                        bool>(
                                                  context: context,
                                                  isScrollControlled: true,
                                                  shape:
                                                      const RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.vertical(
                                                            top:
                                                                Radius.circular(
                                                                    16)),
                                                  ),
                                                  builder: (context) =>
                                                      SubjectModal(
                                                          lessonId: lessonId),
                                                );
                                                if (updated == true) {
                                                  await homeProvider
                                                      .fetchData();
                                                  _refreshLessonDetails();
                                                } else {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                          const SnackBar(
                                                              content: Text(
                                                                  "Error")));
                                                }
                                              } else if (label == "Location") {
                                                if (currentRole == "Parent") {
                                                  // Ensure the lesson details contain the location address.
                                                  final address = details[
                                                      'location_address'];
                                                  if (address != null &&
                                                      address
                                                          .toString()
                                                          .isNotEmpty) {
                                                    await _showMapOptionsBottomModal(
                                                        address);
                                                  } else {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      const SnackBar(
                                                          content: Text(
                                                              "Location address not available.")),
                                                    );
                                                  }
                                                } else {
                                                  // Existing behavior for non-parent roles (e.g. open modal for editing location)
                                                  bool? updated =
                                                      await showModalBottomSheet<
                                                          bool>(
                                                    context: context,
                                                    isScrollControlled: true,
                                                    shape:
                                                        const RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.vertical(
                                                              top: Radius
                                                                  .circular(
                                                                      16)),
                                                    ),
                                                    builder: (context) =>
                                                        LocationModal(
                                                            lessonId: lessonId),
                                                  );
                                                  if (updated == true) {
                                                    await homeProvider
                                                        .fetchData();
                                                    _refreshLessonDetails();
                                                  }
                                                }
                                              } else if (label == "Students" &&
                                                  currentRole != "Parent") {
                                                bool? updated =
                                                    await showModalBottomSheet<
                                                        bool>(
                                                  context: context,
                                                  isScrollControlled: true,
                                                  shape:
                                                      const RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.vertical(
                                                            top:
                                                                Radius.circular(
                                                                    16)),
                                                  ),
                                                  builder: (context) =>
                                                      StudentsModal(
                                                          lessonId: lessonId),
                                                );
                                                if (updated == true) {
                                                  await homeProvider
                                                      .fetchData();
                                                  _refreshLessonDetails();
                                                }
                                              } else if (label ==
                                                      "Instructors" &&
                                                  currentRole != "Parent") {
                                                bool? updated =
                                                    await showModalBottomSheet<
                                                        bool>(
                                                  context: context,
                                                  isScrollControlled: true,
                                                  shape:
                                                      const RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.vertical(
                                                            top:
                                                                Radius.circular(
                                                                    16)),
                                                  ),
                                                  builder: (context) =>
                                                      InstructorsModal(
                                                          lessonId: lessonId),
                                                );
                                                if (updated == true) {
                                                  await homeProvider
                                                      .fetchData();
                                                  _refreshLessonDetails();
                                                }
                                              } else if (label == "School") {
                                                // The school name shown in Lesson Details.
                                                // For example, if you have:
                                                // final school = details['school_name'] ?? '';
                                                final String schoolName =
                                                    school; // 'school' variable from your lesson details

                                                // Get the SchoolProvider instance.
                                                final schoolProvider =
                                                    Provider.of<SchoolProvider>(
                                                        context,
                                                        listen: false);

                                                // Look up the matching school in the provider's apiSchools list.
                                                // Use toLowerCase() for case-insensitive comparison.
                                                final matchingSchool = schoolProvider
                                                    .apiSchools
                                                    .firstWhere(
                                                        (s) =>
                                                            s['name'] != null &&
                                                            s['name']
                                                                    .toString()
                                                                    .toLowerCase() ==
                                                                schoolName
                                                                    .toLowerCase(),
                                                        orElse: () =>
                                                            {} // Return an empty map if no school is found.
                                                        );

                                                // Optionally, you can also update the selectedSchool property in your provider.
                                                schoolProvider.selectSchool(
                                                    matchingSchool);

                                                // Open the bottom modal with the ContactSchoolWidget, passing the matching school.
                                                showModalBottomSheet(
                                                  context: context,
                                                  shape:
                                                      const RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.vertical(
                                                            top:
                                                                Radius.circular(
                                                                    16)),
                                                  ),
                                                  isScrollControlled: true,
                                                  builder: (context) {
                                                    // If no school was found, you could show an error widget or use the fallback.
                                                    final schoolToPass =
                                                        matchingSchool
                                                                .isNotEmpty
                                                            ? matchingSchool
                                                            : {
                                                                'name':
                                                                    schoolName
                                                              };
                                                    return SizedBox(
                                                      height:
                                                          MediaQuery.of(context)
                                                                  .size
                                                                  .height *
                                                              0.8,
                                                      child:
                                                          ContactSchoolWidget(
                                                              school:
                                                                  schoolToPass),
                                                    );
                                                  },
                                                );
                                              }
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (withAction)
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Text(
                                    actionNoteMapping[label] ?? "",
                                    style: GoogleFonts.lato(
                                        fontSize: 12, color: Colors.orange),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }

                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: combinedItems.asMap().entries.map((entry) {
                          int index = entry.key;
                          Map<String, dynamic> item = entry.value;
                          final bool withAction =
                              labelsWithAction.contains(item['label']);
                          return AnimatedGridItem(
                            delay: Duration(milliseconds: 100 * index),
                            child: buildCard(item, withAction: withAction),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
