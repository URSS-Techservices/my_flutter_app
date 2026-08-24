import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/platform/storage_upload.dart';
import 'package:halo/screens/profile/profile_theme.dart';
import 'package:halo/services/wellness_facility_service.dart';
import 'package:image_picker/image_picker.dart';

/// Owner UI to manage wellness facility team members.
class WellnessStaffEditorPage extends StatefulWidget {
  final String wellnessUserId;

  const WellnessStaffEditorPage({super.key, required this.wellnessUserId});

  @override
  State<WellnessStaffEditorPage> createState() => _WellnessStaffEditorPageState();
}

class _WellnessStaffEditorPageState extends State<WellnessStaffEditorPage> {
  final _service = WellnessFacilityService();
  final _picker = ImagePicker();

  Future<void> _openEditor({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?['name']?.toString() ?? '');
    final roleCtrl = TextEditingController(text: existing?['role']?.toString() ?? '');
    final bioCtrl = TextEditingController(text: existing?['bio']?.toString() ?? '');
    var photoUrl = existing?['photoUrl']?.toString();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit team member' : 'Add team member'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundImage: photoUrl != null && photoUrl!.isNotEmpty ? NetworkImage(photoUrl!) : null,
                  child: photoUrl == null || photoUrl!.isEmpty
                      ? const Icon(Icons.person, size: 36)
                      : null,
                ),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await _picker.pickImage(source: ImageSource.gallery);
                    if (picked == null) return;
                    final ref = FirebaseStorage.instance
                        .ref()
                        .child('users')
                        .child(widget.wellnessUserId)
                        .child('staff')
                        .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
                    final url = await uploadReferenceXFileAndGetUrl(ref, picked);
                    setDialogState(() => photoUrl = url);
                  },
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Photo'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: roleCtrl,
                  decoration: const InputDecoration(labelText: 'Role (e.g. Yoga Instructor)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: bioCtrl,
                  decoration: const InputDecoration(labelText: 'Bio (optional)', border: OutlineInputBorder()),
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

    if (saved != true || nameCtrl.text.trim().isEmpty) return;

    await _service.upsertStaff(
      wellnessId: widget.wellnessUserId,
      staffId: existing?['id']?.toString(),
      name: nameCtrl.text.trim(),
      role: roleCtrl.text.trim(),
      bio: bioCtrl.text.trim(),
      photoUrl: photoUrl,
    );
  }

  Future<void> _delete(String staffId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove team member?'),
        content: const Text('They will no longer appear on your profile.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true) {
      await _service.deleteStaff(wellnessId: widget.wellnessUserId, staffId: staffId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProfileLayout.bg,
      appBar: AppBar(
        title: Text('Manage Team', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: ProfileLayout.textPrimary,
        elevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _service.staffStream(widget.wellnessUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final staff = snapshot.data ?? const [];
          if (staff.isEmpty) {
            return Center(
              child: Text(
                'No team members yet',
                style: GoogleFonts.poppins(color: ProfileLayout.textSecondary),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: staff.length,
            itemBuilder: (context, index) {
              final member = staff[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: member['photoUrl'] != null
                        ? NetworkImage(member['photoUrl'].toString())
                        : null,
                    child: member['photoUrl'] == null ? const Icon(Icons.person) : null,
                  ),
                  title: Text(member['name']?.toString() ?? ''),
                  subtitle: Text(member['role']?.toString() ?? ''),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _openEditor(existing: member),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                        onPressed: () => _delete(member['id']?.toString() ?? ''),
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
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Add member'),
      ),
    );
  }
}
