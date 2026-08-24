import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/core/profile_field_utils.dart';
import 'package:halo/utils/search_utils.dart';

/// Extended edit screen for aspirants — interests, location, fitness metadata.
class AspirantEditProfileHub extends StatefulWidget {
  final Map<String, dynamic> initialData;

  const AspirantEditProfileHub({super.key, required this.initialData});

  @override
  State<AspirantEditProfileHub> createState() => _AspirantEditProfileHubState();
}

class _AspirantEditProfileHubState extends State<AspirantEditProfileHub> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _ageCtrl;
  late final TextEditingController _healthNotesCtrl;
  late final TextEditingController _interestInputCtrl;

  String _fitnessLevel = 'Beginner';
  String? _primaryCategory;
  final List<String> _interests = [];
  bool _saving = false;

  static const _levelOptions = ['Beginner', 'Intermediate', 'Advanced', 'Athlete'];
  static const _categoryOptions = [
    'Fitness & Training',
    'Yoga & Mindfulness',
    'Nutrition',
    'Sports',
    'Wellness Lifestyle',
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _usernameCtrl = TextEditingController(text: d['username']?.toString() ?? '');
    _nameCtrl = TextEditingController(text: ProfileFieldUtils.displayName(d));
    _bioCtrl = TextEditingController(text: d['bio']?.toString() ?? '');
    _cityCtrl = TextEditingController(text: d['city']?.toString() ?? '');
    _ageCtrl = TextEditingController(text: d['age']?.toString() ?? '');
    _healthNotesCtrl = TextEditingController(text: d['healthNotes']?.toString() ?? '');
    _interestInputCtrl = TextEditingController();
    _fitnessLevel = d['fitnessLevel']?.toString() ?? 'Beginner';
    _primaryCategory = d['primaryCategory']?.toString();
    _interests.addAll(List<String>.from(d['interests'] ?? []));
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _cityCtrl.dispose();
    _ageCtrl.dispose();
    _healthNotesCtrl.dispose();
    _interestInputCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _saving = true);
    try {
      final username = _usernameCtrl.text.trim();
      final name = _nameCtrl.text.trim();
      final ageRaw = _ageCtrl.text.trim();
      final age = int.tryParse(ageRaw);

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'username': username,
        ...ProfileFieldUtils.nameUpdateFields(name),
        'bio': _bioCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        if (age != null) 'age': age,
        'fitnessLevel': _fitnessLevel,
        'primaryCategory': _primaryCategory,
        'interests': _interests,
        'healthNotes': _healthNotesCtrl.text.trim(),
        'searchTerms': buildSearchTerms(name: name, username: username),
      });
      if (!mounted) return;
      Fluttertoast.showToast(msg: 'Profile updated');
      Navigator.pop(context, true);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to save profile');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addInterest() {
    final value = _interestInputCtrl.text.trim();
    if (value.isEmpty || _interests.contains(value)) return;
    setState(() {
      _interests.add(value);
      _interestInputCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field('Username', _usernameCtrl, required: true),
            _field('Name', _nameCtrl, required: true),
            _field('Bio', _bioCtrl, maxLines: 3),
            _field('City', _cityCtrl),
            _field('Age', _ageCtrl, keyboard: TextInputType.number),
            const SizedBox(height: 8),
            Text('Fitness level', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _levelOptions.map((level) {
                final selected = _fitnessLevel == level;
                return ChoiceChip(
                  label: Text(level),
                  selected: selected,
                  onSelected: (_) => setState(() => _fitnessLevel = level),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text('Primary category', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _primaryCategory,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              hint: const Text('Select category'),
              items: _categoryOptions
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _primaryCategory = v),
            ),
            const SizedBox(height: 16),
            Text('Interests', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _interestInputCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Add interest',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addInterest(),
                  ),
                ),
                IconButton(onPressed: _addInterest, icon: const Icon(Icons.add)),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _interests
                  .map(
                    (i) => InputChip(
                      label: Text(i),
                      onDeleted: () => setState(() => _interests.remove(i)),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            _field('Health notes (private)', _healthNotesCtrl, maxLines: 3),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    bool required = false,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboard,
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null
            : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
