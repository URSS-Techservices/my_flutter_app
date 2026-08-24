import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/profile_theme.dart';
import 'package:halo/services/guru_availability_service.dart';

/// Visitor UI to pick an open guru slot and submit a booking request.
class GuruBookingSlotPicker extends StatefulWidget {
  final String guruId;
  final String guruName;
  final String currentUserId;
  final Map<String, dynamic> bookingSettings;

  const GuruBookingSlotPicker({
    super.key,
    required this.guruId,
    required this.guruName,
    required this.currentUserId,
    this.bookingSettings = const {},
  });

  @override
  State<GuruBookingSlotPicker> createState() => _GuruBookingSlotPickerState();
}

class _GuruBookingSlotPickerState extends State<GuruBookingSlotPicker> {
  final _service = GuruAvailabilityService();
  final _noteCtrl = TextEditingController();

  List<GuruAvailableSlot> _slots = [];
  GuruAvailableSlot? _selected;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSlots() async {
    final slots = await _service.getAvailableSlots(guruId: widget.guruId, daysAhead: 14);
    if (mounted) {
      setState(() {
        _slots = slots;
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    final slot = _selected;
    if (slot == null) {
      Fluttertoast.showToast(msg: 'Pick a time slot');
      return;
    }

    setState(() => _submitting = true);
    try {
      await FirebaseFirestore.instance.collection('booking_requests').add({
        'guruId': widget.guruId,
        'userId': widget.currentUserId,
        'service': 'Coaching session',
        'slotId': slot.slotId,
        'slotDate': slot.dateKey,
        'slotTime': slot.time24,
        'preferredDate': slot.dateKey,
        'preferredTime': GuruAvailabilityService.formatTime12(slot.time24),
        'note': _noteCtrl.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Fluttertoast.showToast(msg: 'Booking request sent');
        Navigator.pop(context, true);
      }
    } catch (_) {
      Fluttertoast.showToast(msg: 'Failed to send booking request');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = widget.bookingSettings['basePrice']?.toString();
    final duration = widget.bookingSettings['duration']?.toString() ?? '60 min';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Book with ${widget.guruName}',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (price != null && price.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'From ₹$price • $duration',
              style: GoogleFonts.poppins(fontSize: 13, color: ProfileLayout.textSecondary),
            ),
          ],
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_slots.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'No open slots in the next 2 weeks. Message the coach to arrange a time.',
                style: GoogleFonts.poppins(color: ProfileLayout.textSecondary),
              ),
            )
          else ...[
            Text('Pick a slot', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: ListView.builder(
                itemCount: _slots.length,
                itemBuilder: (context, index) {
                  final slot = _slots[index];
                  final selected = _selected?.slotId == slot.slotId;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      selected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: selected ? ProfileLayout.deepLavender : Colors.grey,
                    ),
                    title: Text(slot.displayDate, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                    subtitle: Text(slot.displayTime),
                    onTap: () => setState(() => _selected = slot),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting || _slots.isEmpty ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: ProfileLayout.deepLavender,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Request booking'),
            ),
          ),
        ],
      ),
    );
  }
}
