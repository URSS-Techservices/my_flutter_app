import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/profile_theme.dart';
import 'package:halo/services/guru_availability_service.dart';

/// Guru owner UI to set recurring weekly bookable time slots.
class GuruAvailabilityEditorPage extends StatefulWidget {
  final String guruUserId;
  final Map<String, dynamic> bookingSettings;

  const GuruAvailabilityEditorPage({
    super.key,
    required this.guruUserId,
    this.bookingSettings = const {},
  });

  @override
  State<GuruAvailabilityEditorPage> createState() => _GuruAvailabilityEditorPageState();
}

class _GuruAvailabilityEditorPageState extends State<GuruAvailabilityEditorPage> {
  final _service = GuruAvailabilityService();
  Map<String, List<String>> _slots = {};
  bool _loading = true;
  bool _saving = false;

  final _priceCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  bool _acceptsOnline = true;
  bool _acceptsOffline = true;

  @override
  void initState() {
    super.initState();
    _priceCtrl.text = widget.bookingSettings['basePrice']?.toString() ?? '';
    _durationCtrl.text = widget.bookingSettings['duration']?.toString() ?? '60 min';
    _acceptsOnline = widget.bookingSettings['online'] != false;
    _acceptsOffline = widget.bookingSettings['offline'] != false;
    _load();
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final snap = await _service.weeklySlotsStream(widget.guruUserId).first;
    if (mounted) {
      setState(() {
        _slots = snap;
        _loading = false;
      });
    }
  }

  Future<void> _addTime(String dayKey) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked == null) return;

    final time24 =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      final list = List<String>.from(_slots[dayKey] ?? []);
      if (!list.contains(time24)) list.add(time24);
      list.sort();
      _slots[dayKey] = list;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _service.saveWeeklySlots(guruId: widget.guruUserId, slots: _slots);
      await FirebaseFirestore.instance.collection('users').doc(widget.guruUserId).set({
        'bookingSettings': {
          'basePrice': _priceCtrl.text.trim(),
          'duration': _durationCtrl.text.trim(),
          'online': _acceptsOnline,
          'offline': _acceptsOffline,
          'hasWeeklySlots': _slots.isNotEmpty,
        },
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Availability saved')),
        );
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save availability')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProfileLayout.bg,
      appBar: AppBar(
        title: Text('Weekly Availability', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: ProfileLayout.textPrimary,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Set recurring slots each week. Aspirants can book open times directly.',
                  style: GoogleFonts.poppins(fontSize: 13, color: ProfileLayout.textSecondary),
                ),
                const SizedBox(height: 16),
                _settingsCard(),
                const SizedBox(height: 20),
                ...GuruAvailabilityService.dayLabels.entries.map((e) => _dayCard(e.key, e.value)),
              ],
            ),
    );
  }

  Widget _settingsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          TextField(
            controller: _priceCtrl,
            decoration: const InputDecoration(labelText: 'Base price (₹)', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _durationCtrl,
            decoration: const InputDecoration(labelText: 'Session duration', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Online sessions'),
            value: _acceptsOnline,
            onChanged: (v) => setState(() => _acceptsOnline = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('In-person sessions'),
            value: _acceptsOffline,
            onChanged: (v) => setState(() => _acceptsOffline = v),
          ),
        ],
      ),
    );
  }

  Widget _dayCard(String dayKey, String label) {
    final times = _slots[dayKey] ?? const [];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _addTime(dayKey),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (times.isEmpty)
            Text('No slots', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: times.map((t) {
                return InputChip(
                  label: Text(GuruAvailabilityService.formatTime12(t)),
                  onDeleted: () {
                    setState(() {
                      final list = List<String>.from(_slots[dayKey] ?? [])..remove(t);
                      if (list.isEmpty) {
                        _slots.remove(dayKey);
                      } else {
                        _slots[dayKey] = list;
                      }
                    });
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
