// edit_profile_sections.dart
// Comprehensive edit pages for all profile sections

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:halo/platform/storage_upload.dart';
import 'package:halo/models/aspirant_profile_model.dart';
import 'package:halo/screens/profile/configs/aspirant_profile_config.dart';
import 'package:halo/screens/profile/profile_theme.dart';

// ===================================================================
//  EDIT WORKOUTS PAGE (For Aspirant & Guru)
// ===================================================================
class EditWorkoutsPage extends StatefulWidget {
  final List<Map<String, dynamic>> initialWorkouts;
  final String userType; // "aspirant" or "guru"

  const EditWorkoutsPage({
    Key? key,
    required this.initialWorkouts,
    required this.userType,
  }) : super(key: key);

  @override
  State<EditWorkoutsPage> createState() => _EditWorkoutsPageState();
}

class _EditWorkoutsPageState extends State<EditWorkoutsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _workouts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _workouts = List.from(widget.initialWorkouts);
  }

  Future<void> _saveWorkouts() async {
    setState(() => _isLoading = true);
    try {
      final userId = _auth.currentUser!.uid;
      await _firestore.collection('users').doc(userId).update({
        'lastWorkouts': _workouts,
      });
      Fluttertoast.showToast(msg: 'Workouts updated successfully');
      Navigator.pop(context, _workouts);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to update workouts: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addWorkout() {
    setState(() {
      final workout = <String, dynamic>{
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': '',
        'calories': '',
        'duration': '',
        'date': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (widget.userType == 'aspirant') {
        workout['intensity'] = 'Moderate';
      } else {
        workout['clients'] = '';
      }
      _workouts.add(workout);
    });
  }

  void _removeWorkout(int index) {
    setState(() {
      _workouts.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Workouts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addWorkout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _workouts.length,
              itemBuilder: (context, index) {
                final workout = _workouts[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Workout Title',
                                  border: OutlineInputBorder(),
                                ),
                                controller: TextEditingController(
                                  text: workout['title']?.toString() ?? '',
                                ),
                                onChanged: (value) {
                                  _workouts[index]['title'] = value;
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeWorkout(index),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (widget.userType == 'aspirant') ...[
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Intensity',
                              border: OutlineInputBorder(),
                            ),
                            value: workout['intensity']?.toString() ?? 'Moderate',
                            items: ['Low', 'Moderate', 'High', 'Fun']
                                .map((e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _workouts[index]['intensity'] = value;
                              });
                            },
                          ),
                        ] else ...[
                          TextField(
                            decoration: const InputDecoration(
                              labelText: 'Clients (e.g., "5 clients")',
                              border: OutlineInputBorder(),
                            ),
                            controller: TextEditingController(
                              text: workout['clients']?.toString() ?? '',
                            ),
                            onChanged: (value) {
                              _workouts[index]['clients'] = value;
                            },
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Calories',
                                  border: OutlineInputBorder(),
                                ),
                                controller: TextEditingController(
                                  text: workout['calories']?.toString() ?? '',
                                ),
                                onChanged: (value) {
                                  _workouts[index]['calories'] = value;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Duration',
                                  border: OutlineInputBorder(),
                                ),
                                controller: TextEditingController(
                                  text: workout['duration']?.toString() ?? '',
                                ),
                                onChanged: (value) {
                                  _workouts[index]['duration'] = value;
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveWorkouts,
        label: const Text('Save Workouts'),
        icon: const Icon(Icons.save),
      ),
    );
  }
}

// ===================================================================
//  EDIT EVENTS & CHALLENGES PAGE (Aspirant)
// ===================================================================
class EditEventsChallengesPage extends StatefulWidget {
  final List<Map<String, dynamic>> initialEvents;

  const EditEventsChallengesPage({
    Key? key,
    required this.initialEvents,
  }) : super(key: key);

  @override
  State<EditEventsChallengesPage> createState() =>
      _EditEventsChallengesPageState();
}

class _EditEventsChallengesPageState extends State<EditEventsChallengesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _events = List.from(widget.initialEvents);
  }

  Future<void> _saveEvents() async {
    setState(() => _isLoading = true);
    try {
      final userId = _auth.currentUser!.uid;
      await _firestore.collection('users').doc(userId).update({
        'eventsChallenges': _events,
      });
      Fluttertoast.showToast(msg: 'Events updated successfully');
      Navigator.pop(context, _events);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to update events: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addEvent() {
    setState(() {
      _events.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'type': 'Challenge',
        'name': '',
        'status': 'Active',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  void _removeEvent(int index) {
    setState(() {
      _events.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Events & Challenges'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _addEvent),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _events.length,
              itemBuilder: (context, index) {
                final event = _events[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Event Name',
                                  border: OutlineInputBorder(),
                                ),
                                controller: TextEditingController(
                                  text: event['name']?.toString() ?? '',
                                ),
                                onChanged: (value) {
                                  _events[index]['name'] = value;
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeEvent(index),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'Type',
                                  border: OutlineInputBorder(),
                                ),
                                value: event['type']?.toString() ?? 'Challenge',
                                items: ['Challenge', 'Goal', 'Event']
                                    .map((e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(e),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _events[index]['type'] = value;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'Status',
                                  border: OutlineInputBorder(),
                                ),
                                value: event['status']?.toString() ?? 'Active',
                                items: ['Active', 'Upcoming', 'Completed', 'Joined']
                                    .map((e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(e),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _events[index]['status'] = value;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveEvents,
        label: const Text('Save Events'),
        icon: const Icon(Icons.save),
      ),
    );
  }
}

// ===================================================================
//  EDIT FITNESS STATS PAGE (Aspirant)
// ===================================================================
class EditFitnessStatsPage extends StatefulWidget {
  final Map<String, dynamic> initialStats;

  const EditFitnessStatsPage({
    Key? key,
    required this.initialStats,
  }) : super(key: key);

  @override
  State<EditFitnessStatsPage> createState() => _EditFitnessStatsPageState();
}

class _EditFitnessStatsPageState extends State<EditFitnessStatsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _stepsController = TextEditingController();
  final TextEditingController _caloriesController = TextEditingController();
  final TextEditingController _workoutsController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _stepsController.text = (widget.initialStats['steps'] ?? 0).toString();
    _caloriesController.text =
        (widget.initialStats['caloriesBurned'] ?? 0).toString();
    _workoutsController.text = (widget.initialStats['workouts'] ?? 0).toString();
  }

  @override
  void dispose() {
    _stepsController.dispose();
    _caloriesController.dispose();
    _workoutsController.dispose();
    super.dispose();
  }

  Future<void> _saveStats() async {
    setState(() => _isLoading = true);
    try {
      final userId = _auth.currentUser!.uid;
      await _firestore.collection('users').doc(userId).update({
        'fitnessStats': {
          'steps': int.tryParse(_stepsController.text) ?? 0,
          'caloriesBurned': int.tryParse(_caloriesController.text) ?? 0,
          'workouts': int.tryParse(_workoutsController.text) ?? 0,
          'lastUpdated': FieldValue.serverTimestamp(),
        },
      });
      Fluttertoast.showToast(msg: 'Fitness stats updated successfully');
      Navigator.pop(context);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to update stats: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Fitness Stats')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _stepsController,
                    decoration: const InputDecoration(
                      labelText: 'Steps',
                      border: OutlineInputBorder(),
                      helperText: 'Total steps today',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _caloriesController,
                    decoration: const InputDecoration(
                      labelText: 'Calories Burned',
                      border: OutlineInputBorder(),
                      helperText: 'Total calories burned today',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _workoutsController,
                    decoration: const InputDecoration(
                      labelText: 'Workouts',
                      border: OutlineInputBorder(),
                      helperText: 'Number of workouts this week',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveStats,
                      child: const Text('Save Stats'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ===================================================================
//  EDIT SOCIAL LINKS PAGE (All Profile Types)
// ===================================================================
class EditSocialLinksPage extends StatefulWidget {
  final Map<String, String> initialLinks;

  const EditSocialLinksPage({
    Key? key,
    required this.initialLinks,
  }) : super(key: key);

  @override
  State<EditSocialLinksPage> createState() => _EditSocialLinksPageState();
}

class _EditSocialLinksPageState extends State<EditSocialLinksPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Map<String, TextEditingController> _controllers = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final platforms = ['instagram', 'spotify', 'telegram', 'youtube'];
    for (var platform in platforms) {
      _controllers[platform] = TextEditingController(
        text: widget.initialLinks[platform] ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveLinks() async {
    setState(() => _isLoading = true);
    try {
      final userId = _auth.currentUser!.uid;
      final socialLinks = <String, String>{};
      for (var entry in _controllers.entries) {
        if (entry.value.text.trim().isNotEmpty) {
          socialLinks[entry.key] = entry.value.text.trim();
        }
      }
      await _firestore.collection('users').doc(userId).update({
        'socialLinks': socialLinks,
      });
      Fluttertoast.showToast(msg: 'Social links updated successfully');
      Navigator.pop(context, socialLinks);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to update links: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Social Links')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildLinkField('Instagram', _controllers['instagram']!,
                      Icons.camera_alt),
                  const SizedBox(height: 16),
                  _buildLinkField('Spotify', _controllers['spotify']!,
                      Icons.music_note),
                  const SizedBox(height: 16),
                  _buildLinkField('Telegram', _controllers['telegram']!,
                      Icons.telegram),
                  const SizedBox(height: 16),
                  _buildLinkField('YouTube', _controllers['youtube']!,
                      Icons.play_circle),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveLinks,
                      child: const Text('Save Links'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLinkField(String label, TextEditingController controller,
      IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
        hintText: 'https://...',
      ),
      keyboardType: TextInputType.url,
    );
  }
}

// ===================================================================
//  EDIT PRODUCTS PAGE (Guru & Wellness)
// ===================================================================
class EditProductsPage extends StatefulWidget {
  final List<Map<String, dynamic>> initialProducts;
  final String userType; // "guru" or "wellness"

  const EditProductsPage({
    Key? key,
    required this.initialProducts,
    required this.userType,
  }) : super(key: key);

  @override
  State<EditProductsPage> createState() => _EditProductsPageState();
}

class _EditProductsPageState extends State<EditProductsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _products = List.from(widget.initialProducts);
  }

  Future<void> _saveProducts() async {
    setState(() => _isLoading = true);
    try {
      final userId = _auth.currentUser!.uid;
      await _firestore.collection('users').doc(userId).update({
        'popularProducts': _products,
      });
      Fluttertoast.showToast(msg: 'Products updated successfully');
      Navigator.pop(context, _products);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to update products: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addProduct() {
    setState(() {
      final product = <String, dynamic>{
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': '',
        'price': '',
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (widget.userType == 'guru') {
        product['note'] = '';
      } else {
        product['tag'] = '';
      }
      _products.add(product);
    });
  }

  void _removeProduct(int index) {
    setState(() {
      _products.removeAt(index);
    });
  }

  Future<void> _pickProductImage(int index) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      try {
        final userId = _auth.currentUser!.uid;
        final fileName =
            'product_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = FirebaseStorage.instance
            .ref()
            .child('users')
            .child(userId)
            .child('products')
            .child(fileName);
        final url = await uploadReferenceXFileAndGetUrl(
          ref,
          picked,
          metadata: SettableMetadata(contentType: 'image/jpeg'),
        );
        setState(() {
          _products[index]['imageUrl'] = url;
        });
      } catch (e) {
        Fluttertoast.showToast(msg: 'Failed to upload image');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Products'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _addProduct),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Product Name',
                                  border: OutlineInputBorder(),
                                ),
                                controller: TextEditingController(
                                  text: product['name']?.toString() ?? '',
                                ),
                                onChanged: (value) {
                                  _products[index]['name'] = value;
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeProduct(index),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Price',
                                  border: OutlineInputBorder(),
                                ),
                                controller: TextEditingController(
                                  text: product['price']?.toString() ?? '',
                                ),
                                onChanged: (value) {
                                  _products[index]['price'] = value;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  labelText: widget.userType == 'guru'
                                      ? 'Note'
                                      : 'Tag',
                                  border: const OutlineInputBorder(),
                                ),
                                controller: TextEditingController(
                                  text: (widget.userType == 'guru'
                                          ? product['note']
                                          : product['tag'])
                                      ?.toString() ??
                                      '',
                                ),
                                onChanged: (value) {
                                  _products[index][widget.userType == 'guru'
                                      ? 'note'
                                      : 'tag'] = value;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (product['imageUrl'] != null)
                          Image.network(product['imageUrl'], height: 100),
                        TextButton.icon(
                          onPressed: () => _pickProductImage(index),
                          icon: const Icon(Icons.image),
                          label: const Text('Add/Change Image'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveProducts,
        label: const Text('Save Products'),
        icon: const Icon(Icons.save),
      ),
    );
  }
}

// ===================================================================
//  EDIT SPECIALTIES & CERTIFICATIONS PAGE (Guru)
// ===================================================================
class EditSpecialtiesPage extends StatefulWidget {
  final List<String> initialSpecialties;
  final List<String> initialCertifications;

  const EditSpecialtiesPage({
    Key? key,
    required this.initialSpecialties,
    required this.initialCertifications,
  }) : super(key: key);

  @override
  State<EditSpecialtiesPage> createState() => _EditSpecialtiesPageState();
}

class _EditSpecialtiesPageState extends State<EditSpecialtiesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<String> _specialties = [];
  List<String> _certifications = [];
  final TextEditingController _specialtyController = TextEditingController();
  final TextEditingController _certController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _specialties = List.from(widget.initialSpecialties);
    _certifications = List.from(widget.initialCertifications);
  }

  @override
  void dispose() {
    _specialtyController.dispose();
    _certController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final userId = _auth.currentUser!.uid;
      await _firestore.collection('users').doc(userId).update({
        'specialties': _specialties,
        'certifications': _certifications,
      });
      Fluttertoast.showToast(msg: 'Updated successfully');
      Navigator.pop(context);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to update: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addSpecialty() {
    if (_specialtyController.text.trim().isNotEmpty) {
      setState(() {
        _specialties.add(_specialtyController.text.trim());
        _specialtyController.clear();
      });
    }
  }

  void _addCertification() {
    if (_certController.text.trim().isNotEmpty) {
      setState(() {
        _certifications.add(_certController.text.trim());
        _certController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Specialties & Certifications')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Specialties', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _specialtyController,
                          decoration: const InputDecoration(
                            labelText: 'Add Specialty',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _addSpecialty,
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: _specialties.map((s) {
                      return Chip(
                        label: Text(s),
                        onDeleted: () {
                          setState(() {
                            _specialties.remove(s);
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Text('Certifications', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _certController,
                          decoration: const InputDecoration(
                            labelText: 'Add Certification',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _addCertification,
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: _certifications.map((c) {
                      return Chip(
                        label: Text(c),
                        onDeleted: () {
                          setState(() {
                            _certifications.remove(c);
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _save,
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ===================================================================
//  EDIT SERVICES PAGE (Wellness)
// ===================================================================
class EditServicesPage extends StatefulWidget {
  final List<String> initialServices;

  const EditServicesPage({
    Key? key,
    required this.initialServices,
  }) : super(key: key);

  @override
  State<EditServicesPage> createState() => _EditServicesPageState();
}

class _EditServicesPageState extends State<EditServicesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<String> _services = [];
  final TextEditingController _serviceController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _services = List.from(widget.initialServices);
  }

  @override
  void dispose() {
    _serviceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final userId = _auth.currentUser!.uid;
      await _firestore.collection('users').doc(userId).update({
        'popularServices': _services,
      });
      Fluttertoast.showToast(msg: 'Services updated successfully');
      Navigator.pop(context, _services);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to update services: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addService() {
    if (_serviceController.text.trim().isNotEmpty) {
      setState(() {
        _services.add(_serviceController.text.trim());
        _serviceController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Services')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _serviceController,
                          decoration: const InputDecoration(
                            labelText: 'Add Service',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _addService,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _services.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(_services[index]),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _services.removeAt(index);
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _save,
                      child: const Text('Save Services'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ===================================================================
//  EDIT LOCATION & AVAILABILITY PAGE (Wellness)
// ===================================================================
class EditLocationAvailabilityPage extends StatefulWidget {
  final String initialLocation;
  final List<Map<String, dynamic>> initialSlots;

  const EditLocationAvailabilityPage({
    Key? key,
    required this.initialLocation,
    required this.initialSlots,
  }) : super(key: key);

  @override
  State<EditLocationAvailabilityPage> createState() =>
      _EditLocationAvailabilityPageState();
}

class _EditLocationAvailabilityPageState
    extends State<EditLocationAvailabilityPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _locationController = TextEditingController();
  List<Map<String, dynamic>> _slots = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _locationController.text = widget.initialLocation;
    _slots = List.from(widget.initialSlots);
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final userId = _auth.currentUser!.uid;
      await _firestore.collection('users').doc(userId).update({
        'studioLocation': _locationController.text.trim(),
        'serviceSlots': _slots,
      });
      Fluttertoast.showToast(msg: 'Location & availability updated');
      Navigator.pop(context);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to update: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addSlot() {
    setState(() {
      _slots.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': '',
        'time': '',
        'status': 'Available',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  void _removeSlot(int index) {
    setState(() {
      _slots.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Location & Availability'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _addSlot),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'Studio Location',
                      border: OutlineInputBorder(),
                      helperText: 'Enter your studio address',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                  Text('Service Slots', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...List.generate(_slots.length, (index) {
                    final slot = _slots[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: TextField(
                                    decoration: const InputDecoration(
                                      labelText: 'Slot Title',
                                      border: OutlineInputBorder(),
                                    ),
                                    controller: TextEditingController(
                                      text: slot['title']?.toString() ?? '',
                                    ),
                                    onChanged: (value) {
                                      _slots[index]['title'] = value;
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _removeSlot(index),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    decoration: const InputDecoration(
                                      labelText: 'Time',
                                      border: OutlineInputBorder(),
                                    ),
                                    controller: TextEditingController(
                                      text: slot['time']?.toString() ?? '',
                                    ),
                                    onChanged: (value) {
                                      _slots[index]['time'] = value;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    decoration: const InputDecoration(
                                      labelText: 'Status',
                                      border: OutlineInputBorder(),
                                    ),
                                    value: slot['status']?.toString() ?? 'Available',
                                    items: ['Available', 'Limited Slots', 'Full']
                                        .map((e) => DropdownMenuItem(
                                              value: e,
                                              child: Text(e),
                                            ))
                                        .toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _slots[index]['status'] = value;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _save,
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ===================================================================
//  EDIT FITNESS EVENTS PAGE (Wellness)
// ===================================================================
class EditFitnessEventsPage extends StatefulWidget {
  final List<Map<String, dynamic>> initialEvents;

  const EditFitnessEventsPage({
    Key? key,
    required this.initialEvents,
  }) : super(key: key);

  @override
  State<EditFitnessEventsPage> createState() => _EditFitnessEventsPageState();
}

class _EditFitnessEventsPageState extends State<EditFitnessEventsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _events = List.from(widget.initialEvents);
  }

  Future<void> _saveEvents() async {
    setState(() => _isLoading = true);
    try {
      final userId = _auth.currentUser!.uid;
      await _firestore.collection('users').doc(userId).update({
        'fitnessEvents': _events,
      });
      Fluttertoast.showToast(msg: 'Events updated successfully');
      Navigator.pop(context, _events);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to update events: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addEvent() {
    setState(() {
      _events.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': '',
        'date': '',
        'place': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  void _removeEvent(int index) {
    setState(() {
      _events.removeAt(index);
    });
  }

  Future<void> _pickEventImage(int index) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      try {
        final userId = _auth.currentUser!.uid;
        final fileName =
            'event_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = FirebaseStorage.instance
            .ref()
            .child('users')
            .child(userId)
            .child('events')
            .child(fileName);
        final url = await uploadReferenceXFileAndGetUrl(
          ref,
          picked,
          metadata: SettableMetadata(contentType: 'image/jpeg'),
        );
        setState(() {
          _events[index]['imageUrl'] = url;
        });
      } catch (e) {
        Fluttertoast.showToast(msg: 'Failed to upload image');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Fitness Events'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _addEvent),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _events.length,
              itemBuilder: (context, index) {
                final event = _events[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Event Title',
                                  border: OutlineInputBorder(),
                                ),
                                controller: TextEditingController(
                                  text: event['title']?.toString() ?? '',
                                ),
                                onChanged: (value) {
                                  _events[index]['title'] = value;
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeEvent(index),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'Date & Time',
                            border: OutlineInputBorder(),
                            helperText: 'e.g., "Sun, 7:00 AM"',
                          ),
                          controller: TextEditingController(
                            text: event['date']?.toString() ?? '',
                          ),
                          onChanged: (value) {
                            _events[index]['date'] = value;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'Place',
                            border: OutlineInputBorder(),
                          ),
                          controller: TextEditingController(
                            text: event['place']?.toString() ?? '',
                          ),
                          onChanged: (value) {
                            _events[index]['place'] = value;
                          },
                        ),
                        const SizedBox(height: 12),
                        if (event['imageUrl'] != null)
                          Image.network(event['imageUrl'], height: 100),
                        TextButton.icon(
                          onPressed: () => _pickEventImage(index),
                          icon: const Icon(Icons.image),
                          label: const Text('Add/Change Image'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveEvents,
        label: const Text('Save Events'),
        icon: const Icon(Icons.save),
      ),
    );
  }
}

// ===================================================================
//  EDIT PROFILE MODULES (Aspirant optional sections)
// ===================================================================

class EditProfileModulesPage extends StatefulWidget {
  final AspirantProfileModules initial;

  const EditProfileModulesPage({super.key, required this.initial});

  @override
  State<EditProfileModulesPage> createState() => _EditProfileModulesPageState();
}

class _EditProfileModulesPageState extends State<EditProfileModulesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late AspirantProfileModules _modules;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _modules = widget.initial;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final uid = _auth.currentUser!.uid;
      await _firestore.collection('users').doc(uid).update({
        'profileModules': _modules.toMap(),
      });
      if (!mounted) return;
      Fluttertoast.showToast(msg: 'Profile sections updated');
      Navigator.pop(context, _modules);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggle(String key, bool value) {
    setState(() {
      switch (key) {
        case 'fitnessGoals':
          _modules = _modules.copyWith(fitnessGoals: value);
        case 'recentActivities':
          _modules = _modules.copyWith(recentActivities: value);
        case 'activityStats':
          _modules = _modules.copyWith(activityStats: value);
        case 'progressTracking':
          _modules = _modules.copyWith(progressTracking: value);
        case 'workoutCalendar':
          _modules = _modules.copyWith(workoutCalendar: value);
        case 'workoutStreak':
          _modules = _modules.copyWith(workoutStreak: value);
        case 'personalRecords':
          _modules = _modules.copyWith(personalRecords: value);
        case 'weeklyProgress':
          _modules = _modules.copyWith(weeklyProgress: value);
        case 'learningResources':
          _modules = _modules.copyWith(learningResources: value);
        case 'achievements':
          _modules = _modules.copyWith(achievements: value);
      }
    });
  }

  bool _valueFor(String key) =>
      AspirantProfileConfig.isModuleEnabled(_modules, key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProfileLayout.bg,
      appBar: AppBar(
        backgroundColor: ProfileLayout.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          'Profile Sections',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
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
                : Text(
                    'Save',
                    style: GoogleFonts.poppins(
                      color: ProfileLayout.deepLavender,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Choose which sections appear on your profile.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),
          ...AspirantProfileConfig.moduleKeys.map((key) {
            final label = AspirantProfileConfig.moduleLabels[key] ?? key;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: SwitchListTile(
                title: Text(
                  label,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                value: _valueFor(key),
                activeThumbColor: ProfileLayout.lavender,
                onChanged: (v) => _toggle(key, v),
              ),
            );
          }),
        ],
      ),
    );
  }
}

