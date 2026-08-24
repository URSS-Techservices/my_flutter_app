import 'package:halo/features/auth/presentation/login_page.dart';
import 'package:halo/utils/search_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart';

// ---------- HALO THEME COLORS ----------
const Color kPrimaryColor = Color(0xFFA58CE3); // Lavender
const Color kSecondaryColor = Color(0xFF5B3FA3); // Deep Purple
const Color kBgTop = Color(0xFF111111);
const Color kBgBottom = Color(0xFF050505);

class CreateGuruAccount extends StatefulWidget {
  @override
  _CreateGuruAccount createState() => _CreateGuruAccount();
}

class _CreateGuruAccount extends State<CreateGuruAccount> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ---------- Controllers ----------

  // Basic info
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
  TextEditingController();
  final TextEditingController _dateofbirth = TextEditingController();
  final TextEditingController _location = TextEditingController();

  // Professional
  String? _selectedProfessionType;
  String? _experienceLevel; // Beginner / Experienced / Expert
  List<String> _selectedSpecializations = [];
  List<String> _selectedLanguages = [];

  // Additional
  final TextEditingController _hourlyfees = TextEditingController();
  final TextEditingController _availability = TextEditingController();
  final TextEditingController _certification = TextEditingController();

  // Extra fields
  String? _selectedGender;

  bool _isFirstToggleOn = true; // Terms & Conditions
  bool _isSecondToggleOn = true; // Promotional emails

  String? selectedDate;
  final ImagePicker _imagePicker = ImagePicker();
  final List<String> _selectedFiles = [];

  // Multi-step control
  int _currentStep = 0;
  String? _specializationError;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isFetchingLocation = false;

  // ---------- Helpers ----------

  Future<void> _pickdateofbirth() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(1995),
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
    if (pickedDate != null) {
      String formattedDate = DateFormat('dd-MM-yyyy').format(pickedDate);
      setState(() {
        _dateofbirth.text = formattedDate;
        selectedDate = formattedDate;
      });
    }
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    final passwordRegEx =
        r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[!@#\$&*~]).{8,}$';
    if (!RegExp(passwordRegEx).hasMatch(value)) {
      return 'Password must contain:\n- 1 uppercase letter\n- 1 lowercase letter\n- 1 symbol\n- 1 number';
    }
    return null;
  }

  Future<bool> _isUsernameUnique(String username) async {
    final querySnapshot = await _firestore
        .collection('users')
        .where('username', isEqualTo: username)
        .get();
    return querySnapshot.docs.isEmpty;
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
      _location.text = city;
      _showSnack('Location updated to $city');
    } catch (e) {
      _showSnack('Could not fetch location: $e');
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  // --------- File picking (certifications) ----------

  Future<void> _pickDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        _selectedFiles.addAll(result.paths.whereType<String>());
        _certification.text =
            _selectedFiles.map((e) => e.split('/').last).join(", ");
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No document selected.')),
      );
    }
  }

  Future<void> _pickImages() async {
    final List<XFile>? images = await _imagePicker.pickMultiImage(
      imageQuality: 85,
    );

    if (images != null && images.isNotEmpty) {
      setState(() {
        _selectedFiles.addAll(images.map((e) => e.path));
        _certification.text =
            _selectedFiles.map((e) => e.split('/').last).join(", ");
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No image selected.')),
      );
    }
  }

  void _removeFile(String filePath) {
    setState(() {
      _selectedFiles.remove(filePath);
      _certification.text =
          _selectedFiles.map((e) => e.split('/').last).join(", ");
    });
  }

  Future<void> _openFile(String filePath) async {
    await OpenFilex.open(filePath);
  }

  void _showFileSourceDialog() {
    final textTheme =
    GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            "Upload Certification",
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            "Select your file type",
            style: textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _pickDocument();
              },
              child: const Text(".pdf"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _pickImages();
              },
              child: const Text(".png/.jpg"),
            ),
          ],
        );
      },
    );
  }

  // ---------- Firestore + Auth (REGISTER) ----------

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!_isFirstToggleOn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You must agree to terms & conditions')),
      );
      return;
    }

    // Check username uniqueness
    bool isUnique = await _isUsernameUnique(_usernameController.text.trim());
    if (!isUnique) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Username already exists! Choose another one.')),
      );
      return;
    }

    try {
      // Create User with Firebase Authentication
      UserCredential userCredential =
      await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final username = _usernameController.text.trim();
      final fullName = _nameController.text.trim();
      // Store profile in Firestore (CLEAN SCHEMA)
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'category': 'Guru',
        'accountType': 'guru',
        'profileType': 'guru',
        'username': username,
        'full_name': fullName,
        'searchTerms': buildSearchTerms(username: username, fullName: fullName),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'date_of_birth': _dateofbirth.text.trim(),
        'gender': _selectedGender,
        'location': _location.text.trim(),

        // Professional
        'profession': _selectedProfessionType,
        'areas_of_specialization': _selectedSpecializations,
        'experience_level': _experienceLevel,
        'languages_spoken': _selectedLanguages,

        // Additional
        'hourly_fees': _hourlyfees.text.trim(),
        'availability': _availability.text.trim(),
        'certifications': _selectedFiles, // file paths / names

        // Settings
        'terms_accepted': _isFirstToggleOn,
        'promotional_emails': _isSecondToggleOn,

        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account Created Successfully!')),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: ${e.toString()}')),
      );
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------- UI HELPERS ----------

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    IconData? icon,
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
      prefixIcon: icon != null
          ? Icon(
        icon,
        color: Colors.white70,
      )
          : null,
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

  Widget _buildMultiSelectChips({
    required List<String> options,
    required List<String> selectedValues,
    required Function(String) onTap,
  }) {
    final textTheme =
    GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = selectedValues.contains(option);
        return ChoiceChip(
          label: Text(
            option,
            style: textTheme.bodySmall?.copyWith(
              color: isSelected ? Colors.black : Colors.white70,
            ),
          ),
          selected: isSelected,
          selectedColor: kPrimaryColor,
          backgroundColor: Colors.white.withOpacity(0.08),
          side: BorderSide(
            color: isSelected
                ? kPrimaryColor.withOpacity(0.9)
                : Colors.white.withOpacity(0.25),
          ),
          onSelected: (_) => onTap(option),
        );
      }).toList(),
    );
  }

  // ---------- SCREEN 1: BASIC ACCOUNT INFO ----------

  Widget _buildScreen1() {
    final textTheme =
    GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Basic Account Info",
          style: textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),

        // Username
        TextFormField(
          controller: _usernameController,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration(
            label: 'Username',
            icon: Icons.person_outline_rounded,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a username';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Full Name
        TextFormField(
          controller: _nameController,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration(
            label: 'Full Name*',
            icon: Icons.badge_outlined,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your Full Name';
            }
            if (value.length < 3) {
              return 'Full name must be at least 3 characters long';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Mobile Number
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration(
            label: 'Mobile Number*',
            icon: Icons.phone_outlined,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your Mobile Number';
            }
            if (value.length < 10) {
              return 'Mobile Number is not valid';
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
            icon: Icons.email_outlined,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your email';
            }
            if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                .hasMatch(value)) {
              return 'Please enter a valid email';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Password
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration(
            label: 'Create Password*',
            icon: Icons.lock_outline_rounded,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.white70,
              ),
              onPressed: () => setState(
                  () => _obscurePassword = !_obscurePassword),
            ),
          ),
          validator: _validatePassword,
        ),
        const SizedBox(height: 16),

        // Confirm Password
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration(
            label: 'Confirm Password',
            icon: Icons.lock,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off
                    : Icons.visibility,
                color: Colors.white70,
              ),
              onPressed: () => setState(() => _obscureConfirmPassword =
                  !_obscureConfirmPassword),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please confirm your password';
            }
            if (value != _passwordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Gender
        DropdownButtonFormField<String>(
          decoration: _inputDecoration(
            label: 'Gender*',
            icon: Icons.wc_rounded,
          ),
          dropdownColor: const Color(0xFF221E36),
          value: _selectedGender,
          items: ['Male', 'Female', 'Other']
              .map((gender) => DropdownMenuItem(
            value: gender,
            child: Text(gender),
          ))
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedGender = value;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select your gender';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Date of Birth
        TextFormField(
          controller: _dateofbirth,
          readOnly: true,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration(
            label: 'Date of Birth (DD-MM-YYYY)*',
            icon: Icons.cake_outlined,
            suffixIcon: const Icon(Icons.calendar_today_rounded,
                color: Colors.white70),
          ),
          onTap: _pickdateofbirth,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select your Date of Birth';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Location
        TextFormField(
          controller: _location,
          readOnly: true,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration(
            label: 'Location (City)',
            icon: Icons.location_on_outlined,
            suffixIcon: _isFetchingLocation
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.my_location_rounded,
                    color: Colors.white70),
          ),
          onTap: _detectCurrentCity,
        ),
      ],
    );
  }

  // ---------- SCREEN 2: PROFESSIONAL DETAILS ----------

  Widget _buildScreen2() {
    final textTheme =
    GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    final professionOptions = [
      'Personal Trainer',
      'Strength & Conditioning Coach',
      'Nutritionist / Dietician',
      'Physiotherapist',
      'Yoga Instructor',
      'Wellness Coach',
      'Mobility Specialist',
      'Sports Therapist',
      'Mindfulness / Meditation Coach',
      'Other',
    ];

    final specializationOptions = [
      'Weight Loss',
      'Muscle Gain',
      'Functional Training',
      'CrossFit',
      'Calisthenics',
      'Bodybuilding',
      'Posture Correction',
      'Rehab & Recovery',
      'Sports Performance',
      'Flexibility & Mobility',
      'Yoga & Breathwork',
      'Stress Management',
      'Nutrition Planning',
      'Strength Training',
      'Injury Prevention',
      'Holistic Wellness',
      'General Fitness',
      'Pain Management',
    ];

    final experienceOptions = [
      'Beginner (0–5 Years)',
      'Experienced (5–15 Years)',
      'Expert (15+ Years)',
    ];

    final languageOptions = [
      'English',
      'Hindi',
      'Tamil',
      'Telugu',
      'Kannada',
      'Malayalam',
      'Marathi',
      'Gujarati',
      'Punjabi',
      'Bengali',
      'Odia',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Professional Details",
          style: textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),

        // Profession
        DropdownButtonFormField<String>(
          decoration: _inputDecoration(
            label: 'Your Profession*',
            icon: Icons.work_outline_rounded,
          ),
          dropdownColor: const Color(0xFF221E36),
          value: _selectedProfessionType,
          items: professionOptions
              .map(
                (p) => DropdownMenuItem(
              value: p,
              child: Text(p),
            ),
          )
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedProfessionType = value;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select your profession';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Area of Specialization
        Text(
          'Area of Specialization*',
          style: textTheme.titleSmall?.copyWith(
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        _buildMultiSelectChips(
          options: specializationOptions,
          selectedValues: _selectedSpecializations,
          onTap: (value) {
            setState(() {
              if (_selectedSpecializations.contains(value)) {
                _selectedSpecializations.remove(value);
              } else {
                _selectedSpecializations.add(value);
              }
            });
          },
        ),
        if (_specializationError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              _specializationError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        const SizedBox(height: 16),

        // Experience Level
        DropdownButtonFormField<String>(
          decoration: _inputDecoration(
            label: 'Experience Level',
            icon: Icons.trending_up_rounded,
          ),
          dropdownColor: const Color(0xFF221E36),
          value: _experienceLevel,
          items: experienceOptions
              .map(
                (exp) => DropdownMenuItem(
              value: exp,
              child: Text(exp),
            ),
          )
              .toList(),
          onChanged: (value) {
            setState(() {
              _experienceLevel = value;
            });
          },
        ),
        const SizedBox(height: 16),

        // Languages Spoken
        Text(
          'Languages Spoken',
          style: textTheme.titleSmall?.copyWith(
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        _buildMultiSelectChips(
          options: languageOptions,
          selectedValues: _selectedLanguages,
          onTap: (value) {
            setState(() {
              if (_selectedLanguages.contains(value)) {
                _selectedLanguages.remove(value);
              } else {
                _selectedLanguages.add(value);
              }
            });
          },
        ),
      ],
    );
  }

  // ---------- SCREEN 3: ADDITIONAL DETAILS (OPTIONAL) ----------

  Widget _buildScreen3() {
    final textTheme =
    GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Additional Details (Optional)",
          style: textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),

        // Hourly Charges
        TextFormField(
          controller: _hourlyfees,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration(
            label: 'Hourly Charges / Fees (₹)',
            icon: Icons.currency_rupee_rounded,
          ),
        ),
        const SizedBox(height: 16),

        // Certifications Upload
        TextFormField(
          controller: _certification,
          readOnly: true,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration(
            label: 'Upload Certifications (PDF/JPEG)',
            icon: Icons.workspace_premium_outlined,
            suffixIcon: GestureDetector(
              onTap: _showFileSourceDialog,
              child: const Icon(
                Icons.arrow_circle_up_outlined,
                color: Colors.white70,
              ),
            ),
          ),
        ),
        if (_selectedFiles.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _selectedFiles.map((filePath) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.insert_drive_file,
                    color: Colors.lightBlueAccent),
                title: Text(
                  filePath.split('/').last,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon:
                      const Icon(Icons.open_in_new, color: Colors.green),
                      onPressed: () => _openFile(filePath),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => _removeFile(filePath),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 16),

        // Availability
        TextFormField(
          controller: _availability,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration(
            label: 'Availability (e.g. Mon–Fri, 6–9 PM)',
            icon: Icons.event_available_outlined,
          ),
        ),
      ],
    );
  }

  // ---------- SCREEN 4: FINAL STEP ----------

  Widget _buildScreen4() {
    final textTheme =
    GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Final Step",
          style: textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Agree to Terms & Conditions*',
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ),
            Switch(
              value: _isFirstToggleOn,
              onChanged: (value) {
                setState(() {
                  _isFirstToggleOn = value;
                });
              },
              activeColor: kPrimaryColor,
              inactiveThumbColor: Colors.grey,
            ),
          ],
        ),
        const SizedBox(height: 8),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Allow promotional emails',
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ),
            Switch(
              value: _isSecondToggleOn,
              onChanged: (value) {
                setState(() {
                  _isSecondToggleOn = value;
                });
              },
              activeColor: kPrimaryColor,
              inactiveThumbColor: Colors.grey,
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ---------- STEP FLOW CONTROL ----------

  Widget _getStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildScreen1();
      case 1:
        return _buildScreen2();
      case 2:
        return _buildScreen3();
      case 3:
      default:
        return _buildScreen4();
    }
  }

  String _getPrimaryButtonText() {
    if (_currentStep == 0) return 'Continue';
    if (_currentStep == 1) return 'Next';
    if (_currentStep == 2) return 'Complete Profile';
    return 'Start Your Journey';
  }

  void _onPrimaryButtonPressed() {
    final isValid = _formKey.currentState?.validate() ?? false;

    if (_currentStep == 1) {
      _specializationError = null;
      if (_selectedSpecializations.isEmpty) {
        _specializationError = 'Please select at least one specialization';
      }
      setState(() {});
      if (!isValid || _specializationError != null) return;
    } else {
      if (!isValid) return;
    }

    if (_currentStep < 3) {
      setState(() {
        _currentStep++;
      });
    } else {
      _register();
    }
  }

  Future<bool> _onWillPop() async {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      return false;
    }
    return true;
  }

  Widget _buildProgress() {
    final progress = (_currentStep + 1) / 4;
    final textTheme =
    GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: Colors.white.withOpacity(0.14),
            valueColor:
            const AlwaysStoppedAnimation<Color>(kPrimaryColor),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Step ${_currentStep + 1} of 4',
          style: textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }

  // ---------- BUILD ----------

  @override
  Widget build(BuildContext context) {
    final textTheme =
    GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Create Guru Account',
          style: textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
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
        child: Column(
          children: [
            const SizedBox(height: kToolbarHeight + 10),
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: _buildProgress(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 8.0),
                child: Form(
                  key: _formKey,
                  child: _getStepContent(),
                ),
              ),
            ),

            // Buttons
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _currentStep--;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: kPrimaryColor),
                          foregroundColor: kPrimaryColor,
                          padding:
                          const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _onPrimaryButtonPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                        padding:
                        const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _getPrimaryButtonText(),
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Login Link
            Padding(
              padding: const EdgeInsets.only(bottom: 18.0),
              child: GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LoginPage(),
                    ),
                  );
                },
                child: Text(
                  'Already have an account? Login',
                  style: textTheme.bodySmall?.copyWith(
                    color: kPrimaryColor,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
