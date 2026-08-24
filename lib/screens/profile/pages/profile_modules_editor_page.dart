import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/models/aspirant_profile_model.dart';
import 'package:halo/screens/profile/configs/aspirant_profile_config.dart';
import 'package:halo/screens/profile/configs/guru_profile_config.dart';
import 'package:halo/screens/profile/configs/wellness_profile_config.dart';
import 'package:halo/screens/profile/core/profile_modules.dart';
import 'package:halo/screens/profile/core/profile_type.dart';
import 'package:halo/screens/profile/profile_theme.dart';

/// Single profile-sections editor for aspirant, guru, and wellness accounts.
class ProfileModulesEditorPage extends StatefulWidget {
  final ProfileKind kind;
  final Map<String, dynamic>? initialModulesRaw;

  const ProfileModulesEditorPage({
    super.key,
    required this.kind,
    this.initialModulesRaw,
  });

  @override
  State<ProfileModulesEditorPage> createState() =>
      _ProfileModulesEditorPageState();
}

class _ProfileModulesEditorPageState extends State<ProfileModulesEditorPage> {
  late Map<String, bool> _flags;
  late Map<String, String> _labels;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _labels = _labelsForKind(widget.kind);
    _flags = _initialFlags(widget.kind, widget.initialModulesRaw);
  }

  Map<String, String> _labelsForKind(ProfileKind kind) {
    switch (kind) {
      case ProfileKind.aspirant:
        return AspirantProfileConfig.moduleLabels;
      case ProfileKind.guru:
        return GuruProfileConfig.moduleLabels;
      case ProfileKind.wellness:
        return WellnessProfileConfig.moduleLabels;
    }
  }

  Map<String, bool> _initialFlags(
    ProfileKind kind,
    Map<String, dynamic>? raw,
  ) {
    switch (kind) {
      case ProfileKind.aspirant:
        final modules = AspirantProfileModules.fromMap(raw);
        return {
          for (final key in AspirantProfileConfig.moduleKeys)
            key: AspirantProfileConfig.isModuleEnabled(modules, key),
        };
      case ProfileKind.guru:
      case ProfileKind.wellness:
        return Map<String, bool>.from(
          ProfileModules.fromMap(raw).flags,
        );
    }
  }

  Map<String, dynamic> _payloadForSave() {
    if (widget.kind == ProfileKind.aspirant) {
      return {'profileModules': Map<String, dynamic>.from(_flags)};
    }
    return {'profileModules': _flags};
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(_payloadForSave());
      if (!mounted) return;
      Fluttertoast.showToast(msg: 'Profile sections updated');
      Navigator.pop(context, _flags);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to save sections');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keys = _labels.keys.toList();

    return Scaffold(
      backgroundColor: ProfileLayout.bg,
      appBar: AppBar(
        backgroundColor: ProfileLayout.bg,
        elevation: 0,
        title: Text(
          'Profile Sections',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: keys.map((key) {
          return SwitchListTile(
            title: Text(_labels[key] ?? key),
            value: _flags[key] ?? true,
            activeThumbColor: ProfileLayout.deepLavender,
            onChanged: (v) => setState(() => _flags[key] = v),
          );
        }).toList(),
      ),
    );
  }
}

/// Opens the unified modules editor and returns updated flags when saved.
Future<Map<String, bool>?> openProfileModulesEditor(
  BuildContext context, {
  required ProfileKind kind,
  Map<String, dynamic>? initialModulesRaw,
}) {
  return Navigator.push<Map<String, bool>>(
    context,
    MaterialPageRoute(
      builder: (_) => ProfileModulesEditorPage(
        kind: kind,
        initialModulesRaw: initialModulesRaw,
      ),
    ),
  );
}
