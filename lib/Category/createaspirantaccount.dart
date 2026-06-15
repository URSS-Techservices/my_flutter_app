import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart';
import 'package:halo/widgets/gps_location_suffix.dart';

// HALO THEME COLORS
const Color kPrimaryColor = Color(0xFFA58CE3); // Lavender
const Color kSecondaryColor = Color(0xFF5B3FA3); // Deep Purple
const Color kBgTop = Color(0xFF111111);
const Color kBgBottom = Color(0xFF050505);

class CreateAspirantAccount extends StatefulWidget {
  @override
  _CreateAspirantAccountState createState() => _CreateAspirantAccountState();
}

class _CreateAspirantAccountState extends State<CreateAspirantAccount> {
  // Step control
  int _currentStep = 0;

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Form keys
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();

  // Controllers (step1)
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  String? _selectedGender;

  // Step2 selections
  final List<String> _fitnessGoalsOptions = [
    'Weight Loss',
    'Muscle Gain',
    'Strength Building',
    'Body Toning',
    'Endurance',
    'Flexibility / Yoga',
    'Rehab & Recovery',
    'Mental Wellness',
    'General Fitness',
  ];
  final List<String> _selectedFitnessGoals = [];

  final List<String> _fitnessLevelOptions = [
    'Beginner',
    'Intermediate',
    'Advanced'
  ];
  String? _selectedFitnessLevel;

  final List<String> _preferredLocationOptions = ['Gym', 'Home', 'Other'];
  final List<String> _selectedPreferredLocations = [];

  final TextEditingController _healthConcernsController =
  TextEditingController();

  // Step3 toggles
  bool _termsAccepted = false;
  bool _promotional = true;

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _isFetchingLocation = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _dobController.dispose();
    _locationController.dispose();
    _healthConcernsController.dispose();
    super.dispose();
  }

  // ---------- HELPERS ----------

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final initial = DateTime(now.year - 18, now.month, now.day);
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.dark(
              primary: kPrimaryColor,
              surface: const Color(0xFF1C1C1C),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      _dobController.text = DateFormat('dd-MM-yyyy').format(picked);
      setState(() {});
    }
  }

  String? _passwordValidator(String? value) {
    if (value == null || value.isEmpty) return 'Please enter a password';
    if (value.length < 8) return 'Password must be at least 8 characters';
    final reg = r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[!@#\$&*~]).{8,}$';
    if (!RegExp(reg).hasMatch(value)) {
      return 'Password must include uppercase, lowercase, number and symbol';
    }
    return null;
  }

  String? _phoneValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter mobile number';
    }
    final digits = value.trim();
    if (!RegExp(r'^[0-9]+$').hasMatch(digits)) return 'Enter digits only';
    if (digits.length != 10) return 'Mobile number must be 10 digits';
    return null;
  }

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Please enter email';
    final v = value.trim();
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  // Multi-select dialog for Preferred Location
  Future<void> _showPreferredLocationDialog() async {
    final selected = List<String>.from(_selectedPreferredLocations);
    await showDialog(
      context: context,
      builder: (ctx) {
        final textTheme =
        GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);
        return AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'Select Preferred Location(s)',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          content: StatefulBuilder(builder: (context, setLocal) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _preferredLocationOptions.map((opt) {
                  final checked = selected.contains(opt);
                  return CheckboxListTile(
                    value: checked,
                    title: Text(opt),
                    onChanged: (v) {
                      setLocal(() {
                        if (v == true) {
                          selected.add(opt);
                        } else {
                          selected.remove(opt);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            );
          }),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedPreferredLocations
                    ..clear()
                    ..addAll(selected);
                });
                Navigator.pop(ctx);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _detectCurrentCity() async {
    if (_isFetchingLocation) return;
    setState(() => _isFetchingLocation = true);
    try {
      final location = loc.Location();
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
      }
      if (!serviceEnabled) {
        _showSnack('Please enable location service.');
        return;
      }

      var permission = await location.hasPermission();
      if (permission == loc.PermissionStatus.denied) {
        permission = await location.requestPermission();
      }
      if (permission != loc.PermissionStatus.granted &&
          permission != loc.PermissionStatus.grantedLimited) {
        _showSnack('Location permission is required.');
        return;
      }

      final data = await location.getLocation();
      final lat = data.latitude;
      final lng = data.longitude;
      if (lat == null || lng == null) {
        _showSnack('Unable to fetch your location.');
        return;
      }

      final places = await placemarkFromCoordinates(lat, lng);
      if (places.isEmpty) {
        _showSnack('City not found from current location.');
        return;
      }

      final p = places.first;
      final city = (p.locality ?? p.subAdministrativeArea ?? p.administrativeArea ?? '').trim();
      if (city.isEmpty) {
        _showSnack('City not found from current location.');
        return;
      }
      _locationController.text = city;
      _showSnack('Location updated to $city');
    } catch (e) {
      _showSnack('Could not fetch location: $e');
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Move to next step after validating current step
  void _goToNext() {
    if (_currentStep == 0) {
      if (_formKeyStep1.currentState?.validate() ?? false) {
        setState(() => _currentStep = 1);
      }
    } else if (_currentStep == 1) {
      if (_formKeyStep2.currentState?.validate() ?? false) {
        if (_selectedFitnessGoals.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Please select at least one fitness goal')),
          );
          return;
        }
        if (_selectedFitnessLevel == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Please select your fitness level')),
          );
          return;
        }
        setState(() => _currentStep = 2);
      }
    }
  }

  void _goToPrevious() {
    if (_currentStep > 0) setState(() => _currentStep -= 1);
  }

  Future<bool> _onWillPop() async {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
      return false;
    }
    return true;
  }

  // Final submit - uses FirebaseAuth + Firestore
  Future<void> _submit() async {
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please accept terms & conditions')),
      );
      return;
    }

    // safety: revalidate step1
    if (!(_formKeyStep1.currentState?.validate() ?? false)) {
      setState(() => _currentStep = 0);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final username = _usernameController.text.trim();
      final usernameLower = username.toLowerCase();
      final email = _emailController.text.trim();
      final emailLower = email.toLowerCase();
      final password = _passwordController.text.trim();

      // 1) Check username uniqueness (case-insensitive)
      final existing = await _firestore
          .collection('users')
          .where('username_lower', isEqualTo: usernameLower)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
              Text('Username already taken. Please choose another one.')),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      // 2) Create FirebaseAuth user (email + password)
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user!.uid;

      // 3) Save profile in Firestore (no password)
      final payload = {
        'uid': uid,
        'category': 'Aspirant',
        'username': username,
        'username_lower': usernameLower,
        'email': email,
        'email_lower': emailLower,
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'gender': _selectedGender,
        'date_of_birth': _dobController.text.trim(),
        'location': _locationController.text.trim(),
        'fitness_goals': _selectedFitnessGoals,
        'fitness_level': _selectedFitnessLevel,
        'preferred_locations': _selectedPreferredLocations,
        'health_concerns': _healthConcernsController.text.trim(),
        'terms_accepted': _termsAccepted,
        'promotional_emails': _promotional,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(uid).set(payload);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Aspirant account created successfully!')),
      );

      // TODO: navigate to home screen
      // Navigator.pushReplacement(...);

    } on FirebaseAuthException catch (e) {
      String message = 'Failed to create account';
      if (e.code == 'email-already-in-use') {
        message = 'This email is already registered.';
      } else if (e.code == 'weak-password') {
        message = 'Password is too weak.';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email format.';
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create account: $e')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // ---------- UI HELPERS ----------

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final textTheme =
    GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: textTheme.labelMedium?.copyWith(
        color: Colors.grey.shade300,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: textTheme.bodySmall?.copyWith(
        color: Colors.grey.shade500,
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: kPrimaryColor,
          width: 1.5,
        ),
      ),
      errorMaxLines: 4,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildProgressIndicator() {
    final totalSteps = 3;
    final progress = (_currentStep + 1) / totalSteps;
    final textTheme =
    GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: Colors.white.withOpacity(0.15),
            valueColor:
            const AlwaysStoppedAnimation<Color>(kPrimaryColor),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Step ${_currentStep + 1} of $totalSteps',
          style: textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }

  // ---------- STEP UIs ----------

  Widget _buildStep1() {
    final textTheme =
    GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return Form(
      key: _formKeyStep1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Basic Details',
            style: textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),

          // Full Name
          TextFormField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(
              label: 'Full Name',
              prefixIcon: const Icon(Icons.person_outline, color: Colors.white70),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Please enter your full name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Username
          TextFormField(
            controller: _usernameController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(
              label: 'Username',
              prefixIcon:
              const Icon(Icons.alternate_email_rounded, color: Colors.white70),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Please enter a username';
              }
              if (v.contains(' ')) {
                return 'Username cannot contain spaces';
              }
              if (v.length < 3) {
                return 'Username must be at least 3 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Email
          TextFormField(
            controller: _emailController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(
              label: 'Email',
              prefixIcon: const Icon(Icons.email_outlined, color: Colors.white70),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: _emailValidator,
          ),
          const SizedBox(height: 16),

          // Mobile
          TextFormField(
            controller: _phoneController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(
              label: 'Mobile Number',
              prefixIcon: const Icon(Icons.phone_outlined, color: Colors.white70),
            ),
            keyboardType: TextInputType.phone,
            validator: _phoneValidator,
          ),
          const SizedBox(height: 16),

          // Password
          TextFormField(
            controller: _passwordController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(
              label: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded,
                  color: Colors.white70),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white70,
                ),
                onPressed: () => setState(
                    () => _obscurePassword = !_obscurePassword),
              ),
            ),
            obscureText: _obscurePassword,
            validator: _passwordValidator,
          ),
          const SizedBox(height: 16),

          // Gender
          DropdownButtonFormField<String>(
            value: _selectedGender,
            dropdownColor: const Color(0xFF221E36),
            decoration: _inputDecoration(
              label: 'Gender',
              prefixIcon:
              const Icon(Icons.wc_rounded, color: Colors.white70),
            ),
            items: ['Male', 'Female', 'Other']
                .map(
                  (g) => DropdownMenuItem(value: g, child: Text(g)),
            )
                .toList(),
            onChanged: (val) {
              setState(() => _selectedGender = val);
            },
            validator: (val) {
              if (val == null || val.isEmpty) return 'Please select gender';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Date of Birth
          TextFormField(
            controller: _dobController,
            readOnly: true,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(
              label: 'Date of Birth',
              prefixIcon: const Icon(Icons.cake_outlined, color: Colors.white70),
              suffixIcon:
              const Icon(Icons.calendar_today_rounded, color: Colors.white70),
            ),
            onTap: _pickDateOfBirth,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Please select your date of birth';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Location
          TextFormField(
            controller: _locationController,
            style: const TextStyle(color: Colors.white),
            textCapitalization: TextCapitalization.words,
            keyboardType: TextInputType.streetAddress,
            decoration: _inputDecoration(
              label: 'City / Location',
              hint: 'Type your city or tap GPS',
              prefixIcon:
              const Icon(Icons.location_on_outlined, color: Colors.white70),
              suffixIcon: gpsLocationSuffix(
                isFetching: _isFetchingLocation,
                onPressed: _detectCurrentCity,
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Please enter your location';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _goToNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Next'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    final textTheme =
    GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return Form(
      key: _formKeyStep2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fitness Profile',
            style: textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Fitness Goals',
            style: textTheme.titleSmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _fitnessGoalsOptions.map((goal) {
              final selected = _selectedFitnessGoals.contains(goal);
              return FilterChip(
                label: Text(
                  goal,
                  style: textTheme.bodySmall?.copyWith(
                    color: selected ? Colors.black : Colors.white70,
                  ),
                ),
                selected: selected,
                selectedColor: kPrimaryColor,
                backgroundColor: Colors.white.withOpacity(0.06),
                side: BorderSide(
                  color: selected
                      ? kPrimaryColor.withOpacity(0.9)
                      : Colors.white.withOpacity(0.25),
                ),
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _selectedFitnessGoals.add(goal);
                    } else {
                      _selectedFitnessGoals.remove(goal);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          DropdownButtonFormField<String>(
            value: _selectedFitnessLevel,
            dropdownColor: const Color(0xFF221E36),
            decoration: _inputDecoration(
              label: 'Current Fitness Level',
              prefixIcon:
              const Icon(Icons.bar_chart_rounded, color: Colors.white70),
            ),
            items: _fitnessLevelOptions
                .map(
                  (f) => DropdownMenuItem(value: f, child: Text(f)),
            )
                .toList(),
            onChanged: (val) {
              setState(() => _selectedFitnessLevel = val);
            },
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Please select fitness level';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          Text(
            'Preferred Workout Location(s)',
            style: textTheme.titleSmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            children: _selectedPreferredLocations.isEmpty
                ? [
              Text(
                'No location selected',
                style: textTheme.bodySmall
                    ?.copyWith(color: Colors.grey.shade500),
              ),
            ]
                : _selectedPreferredLocations
                .map((loc) => Chip(
              label: Text(loc),
              backgroundColor: Colors.white.withOpacity(0.08),
            ))
                .toList(),
          ),
          const SizedBox(height: 8),

          OutlinedButton.icon(
            onPressed: _showPreferredLocationDialog,
            icon: const Icon(Icons.place_outlined),
            label: const Text('Select Locations'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kPrimaryColor,
              side: const BorderSide(color: kPrimaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _healthConcernsController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(
              label: 'Health Concerns (if any)',
              hint: 'e.g. knee pain, back issues, recent surgery…',
              prefixIcon:
              const Icon(Icons.healing_outlined, color: Colors.white70),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _goToPrevious,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                ),
                child: const Text('Back'),
              ),
              ElevatedButton(
                onPressed: _goToNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    final textTheme =
    GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Final Step',
          style: textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),

        CheckboxListTile(
          value: _termsAccepted,
          onChanged: (v) => setState(() => _termsAccepted = v ?? false),
          title: Text(
            'I accept the Terms & Conditions',
            style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          activeColor: kPrimaryColor,
          checkColor: Colors.black,
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 8),

        SwitchListTile(
          value: _promotional,
          onChanged: (v) => setState(() => _promotional = v),
          title: Text(
            'Receive promotional offers and fitness tips',
            style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          activeColor: kPrimaryColor,
        ),
        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _goToPrevious,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
              ),
              child: const Text('Back'),
            ),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                  AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Text('Create Account'),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final stepTitle = ['Basic Details', 'Fitness Profile', 'Final Step']
    [_currentStep];
    final textTheme =
    GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
        title: Text(
          'Aspirant · $stepTitle',
          style: textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            final allowPop = await _onWillPop();
            if (allowPop && mounted) Navigator.of(context).pop();
          },
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kBgTop, kBgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              children: [
                const SizedBox(height: kToolbarHeight),
                _buildProgressIndicator(),
                const SizedBox(height: 16),
                IndexedStack(
                  index: _currentStep,
                  children: [
                    _buildStep1(),
                    _buildStep2(),
                    _buildStep3(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
