import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/platform/storage_upload.dart';
import 'package:halo/screens/profile/profile_theme.dart';
import 'package:halo/services/wellness_facility_service.dart';
import 'package:image_picker/image_picker.dart';

/// Owner UI to manage wellness fitness events.
class WellnessEventsEditorPage extends StatefulWidget {
  final String wellnessUserId;

  const WellnessEventsEditorPage({super.key, required this.wellnessUserId});

  @override
  State<WellnessEventsEditorPage> createState() => _WellnessEventsEditorPageState();
}

class _WellnessEventsEditorPageState extends State<WellnessEventsEditorPage> {
  final _service = WellnessFacilityService();
  final _picker = ImagePicker();

  Future<void> _openEditor({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final titleCtrl = TextEditingController(text: WellnessFacilityService.eventTitle(existing ?? {}));
    final dateCtrl = TextEditingController(text: existing?['date']?.toString() ?? '');
    final timeCtrl = TextEditingController(text: existing?['time']?.toString() ?? '');
    final placeCtrl = TextEditingController(text: existing?['place']?.toString() ?? '');
    final descCtrl = TextEditingController(text: existing?['description']?.toString() ?? '');
    var imageUrl = existing?['imageUrl']?.toString();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit event' : 'Add event'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (imageUrl != null && imageUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(imageUrl!, height: 100, width: double.infinity, fit: BoxFit.cover),
                  ),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await _picker.pickImage(source: ImageSource.gallery);
                    if (picked == null) return;
                    final ref = FirebaseStorage.instance
                        .ref()
                        .child('users')
                        .child(widget.wellnessUserId)
                        .child('events')
                        .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
                    final url = await uploadReferenceXFileAndGetUrl(ref, picked);
                    setDialogState(() => imageUrl = url);
                  },
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Event image'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Event title', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: dateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    hintText: 'Sun, Jun 15',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: timeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Time',
                    hintText: '7:00 AM',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: placeCtrl,
                  decoration: const InputDecoration(labelText: 'Place', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isEdit ? 'Save' : 'Add')),
          ],
        ),
      ),
    );

    if (saved != true || titleCtrl.text.trim().isEmpty) return;

    await _service.upsertEvent(
      wellnessId: widget.wellnessUserId,
      eventId: existing?['id']?.toString(),
      title: titleCtrl.text.trim(),
      date: dateCtrl.text.trim(),
      time: timeCtrl.text.trim(),
      place: placeCtrl.text.trim(),
      description: descCtrl.text.trim(),
      imageUrl: imageUrl,
    );
  }

  Future<void> _delete(String eventId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove event?'),
        content: const Text('This event will be hidden from your profile.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true) {
      await _service.deleteEvent(wellnessId: widget.wellnessUserId, eventId: eventId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProfileLayout.bg,
      appBar: AppBar(
        title: Text('Manage Events', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: ProfileLayout.textPrimary,
        elevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _service.eventsStream(widget.wellnessUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = snapshot.data ?? const [];
          if (events.isEmpty) {
            return Center(
              child: Text(
                'No events scheduled',
                style: GoogleFonts.poppins(color: ProfileLayout.textSecondary),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              final when = WellnessFacilityService.eventWhen(event);
              final place = event['place']?.toString() ?? '';
              final subtitle = [when, place].where((s) => s.isNotEmpty).join(' • ');
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.event_outlined),
                  title: Text(WellnessFacilityService.eventTitle(event)),
                  subtitle: subtitle.isEmpty ? null : Text(subtitle),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _openEditor(existing: event),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                        onPressed: () => _delete(event['id']?.toString() ?? ''),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: ProfileLayout.deepLavender,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add event'),
      ),
    );
  }
}
