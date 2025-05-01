// lib/modals/equipment_details_modal.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EquipmentDetailsModal extends StatelessWidget {
  final Map<String, dynamic> equipment;
  const EquipmentDetailsModal({Key? key, required this.equipment})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    // limit to 90% of screen height
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    final photoUrl = (equipment['photo_url'] as String?) ?? '';
    final isForKids = (equipment['is_for_kids'] as bool?) ?? false;

    return Container(
      height: maxHeight,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Equipment Details',
                style: GoogleFonts.lato(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),

          // Photo (if any)
          if (photoUrl.isNotEmpty) ...[
            SizedBox(
              height: 200,
              child: Image.network(
                photoUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 64,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Details list
          Expanded(
            child: ListView(
              children: [
                _buildDetailRow('Name', equipment['equipment_name']),
                _buildDetailRow('Location', equipment['location_name']),
                _buildDetailRow('Size', equipment['size']),
                _buildDetailRow('State', equipment['state']),
                _buildDetailRow('For Kids', isForKids ? 'Yes' : 'No'),
                _buildDetailRow('Brand', equipment['brand']),
                _buildDetailRow('Description', equipment['description']),
                const SizedBox(height: 8),
                Text(
                  'Subjects:',
                  style: GoogleFonts.lato(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                ...((equipment['subjects'] as List<dynamic>?)
                        ?.map((s) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4.0),
                              child: Text('• ${s['name']}',
                                  style: GoogleFonts.lato(fontSize: 14)),
                            ))
                        .toList() ??
                    []),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    final text = (value ?? '').toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: GoogleFonts.lato(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
