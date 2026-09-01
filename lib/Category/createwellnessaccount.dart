import 'package:halo/utils/search_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart';

import 'package:halo/core/halo_toast.dart';
import 'package:halo/core/halo_theme.dart';
import 'package:halo/features/auth/presentation/onboarding_ui.dart';
import 'package:halo/features/auth/presentation/session_controller.dart';

class CreateWellnessAccount extends ConsumerStatefulWidget {
  @override
  ConsumerState<CreateWellnessAccount> createState() => _CreateWellnessAccount();
}

class _CreateWellnessAccount extends ConsumerState<CreateWellnessAccount> {
  final _formKey = GlobalKey<FormState>();

  // ---------- Controllers ----------

  // Basic business details
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _nameController = TextEditingController(); // Business Name
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _location = TextEditingController();
  final TextEditingController _yearOfCommencement = TextEditingController();

  // Services & operations
  final TextEditingController _membershipPlans = TextEditingController();
  final TextEditingController _workingHours = TextEditingController();
  final TextEditingController _certification = TextEditingController();

  // Extras
  final TextEditingController _offers = TextEditingController();
  final TextEditingController _productsOffered = TextEditingController();

  String? _selectedBusinessType;
  bool _isFirstToggleOn = true; // Terms & Conditions
  bool _isSecondToggleOn = true; // Promotional emails

  final ImagePicker _imagePicker = ImagePicker();
  final List<String> _selectedFiles = []; // Certifications
  final List<String> _selectedFacilities = [];

  int _currentStep = 0;
  String? selectedDate;
  bool _isFetchingLocation = false;
  bool _isSubmitting = false;

  // ---------- Helpers ----------

  Future<void> _pickYearOfCommencement() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (ctx, child) => OnboardingUi.datePickerTheme(ctx, child),
    );
    if (pickedDate != null) {
      String formattedDate = DateFormat('dd-MM-yyyy').format(pickedDate);
      setState(() {
        _yearOfCommencement.text = formattedDate;
        selectedDate = formattedDate;
      });
    }
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

  // ---------- File picking (Certifications) ----------

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
      HaloToast.show('No document selected.');
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
      HaloToast.show('No image selected.');
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
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final textTheme =
        GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            "Upload Certification",
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
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

  // ---------- Firestore + Auth ----------

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!_isFirstToggleOn) {
      HaloToast.show('You must agree to terms & conditions');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final username = _usernameController.text.trim();
      final available = await ref
          .read(onboardingControllerProvider.notifier)
          .isUsernameAvailable(username);
      if (!available) {
        HaloToast.show('Username already exists! Choose another one.');
        return;
      }

      final businessName = _nameController.text.trim();
      final ok = await ref
          .read(onboardingControllerProvider.notifier)
          .completeOnboarding({
        'category': 'Wellness',
        'accountType': 'wellness',
        'profileType': 'wellness',
        'username': username,
        'username_lower': username.toLowerCase(),
        'business_name': businessName,
        'searchTerms':
            buildSearchTerms(username: username, businessName: businessName),
        'phone': _phoneController.text.trim(),
        'mobile': _phoneController.text.trim(),
        'business_type': _selectedBusinessType,
        'location': _location.text.trim(),
        'year_of_commencement': _yearOfCommencement.text.trim(),
        'facilities_services': _selectedFacilities,
        'certifications': _selectedFiles,
        'membership_plans': _membershipPlans.text.trim(),
        'working_hours': _workingHours.text.trim(),
        'special_offers': _offers.text.trim(),
        'products_services_offered': _productsOffered.text.trim(),
        'terms_accepted': _isFirstToggleOn,
        'promotional_emails': _isSecondToggleOn,
      });
      if (!mounted) return;
      if (ok) {
        HaloToast.show('Profile saved. Welcome to HALO!');
      } else {
        HaloToast.show('Could not save your profile. Please try again.');
      }
    } catch (e) {
      HaloToast.show('Could not save profile: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String msg) {
    HaloToast.show(msg);
  }

  // ---------- UI HELPERS ----------

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    IconData? icon,
    Widget? suffixIcon,
    bool readOnly = false,
  }) {
    return OnboardingUi.field(
      context: context,
      label: label,
      hint: hint,
      icon: icon,
      suffixIcon: suffixIcon,
    );
  }

  Widget _buildMultiSelectChips({
    required List<String> options,
    required List<String> selectedValues,
    required Function(String) onTap,
  }) {
    final textTheme = GoogleFonts.poppinsTextTheme(
      Theme.of(context).textTheme,
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = selectedValues.contains(option);
        return ChoiceChip(
          label: Text(
            option,
            style: textTheme.bodySmall?.copyWith(
              color: isSelected ? Colors.black : OnboardingUi.muted,
            ),
          ),
          selected: isSelected,
          selectedColor: kPrimaryColor,
          backgroundColor: OnboardingUi.fieldFill,
          side: BorderSide(
            color: isSelected
                ? kPrimaryColor.withValues(alpha: 0.9)
                : OnboardingUi.fieldBorder,
          ),
          onSelected: (_) => onTap(option),
        );
      }).toList(),
    );
  }

  // ---------- SCREEN 1: BASIC BUSINESS DETAILS ----------

  Widget _buildScreen1() {
    final businessTypes = [
      'Gym',
      'Yoga Studio',
      'Fitness Studio',
      'Diet Clinic',
      'Physiotherapy Clinic',
      'Spa / Wellness Center',
      'Sports Rehab Center',
      'Martial Arts Academy',
      'Supplement Store',
      'Café/Restaurant',
      'Other',
    ];

    final headingStyle = GoogleFonts.poppins(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: OnboardingUi.text,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Business Details", style: headingStyle),
        const SizedBox(height: 18),

        // Username
        TextFormField(
          controller: _usernameController,
          style: const TextStyle(color: OnboardingUi.text),
          decoration: _inputDecoration(
            label: 'Username',
            icon: Icons.person,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a username';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Business Name
        TextFormField(
          controller: _nameController,
          style: const TextStyle(color: OnboardingUi.text),
          decoration: _inputDecoration(
            label: 'Business Name*',
            icon: Icons.storefront,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your Business Name';
            }
            if (value.length < 3) {
              return 'Business name must be at least 3 characters long';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Mobile Number
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: OnboardingUi.text),
          decoration: _inputDecoration(
            label: 'Mobile Number*',
            icon: Icons.phone,
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

        // Business Type
        DropdownButtonFormField<String>(
          dropdownColor: Colors.white,
          value: _selectedBusinessType,
          decoration: _inputDecoration(
            label: 'Business Type',
            icon: Icons.business_center,
          ),
          items: businessTypes
              .map(
                (bt) => DropdownMenuItem(
              value: bt,
              child: Text(bt),
            ),
          )
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedBusinessType = value;
            });
          },
        ),
        const SizedBox(height: 16),

        // Location
        TextFormField(
          controller: _location,
          readOnly: true,
          style: const TextStyle(color: OnboardingUi.text),
          decoration: _inputDecoration(
            label: 'Location (City)',
            icon: Icons.location_on,
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
                    color: OnboardingUi.muted),
          ),
          onTap: _detectCurrentCity,
        ),
        const SizedBox(height: 16),

        // Year of Commencement (optional)
        TextFormField(
          controller: _yearOfCommencement,
          readOnly: true,
          style: const TextStyle(color: OnboardingUi.text),
          decoration: _inputDecoration(
            label: 'Year of Commencement (DD-MM-YYYY)',
            icon: Icons.calendar_today,
          ),
          onTap: _pickYearOfCommencement,
        ),
      ],
    );
  }

  // ---------- SCREEN 2: SERVICES & OPERATIONS ----------

  Widget _buildScreen2() {
    final facilitiesOptions = [
      'Cardio Equipment',
      'Strength Equipment',
      'Personal Training',
      'Yoga Classes',
      'Group Classes',
      'Physiotherapy',
      'Massage Therapy',
      'Steam / Sauna',
      'Nutrition Consultation',
      'Food and drinks',
      'Supplements Available',
      'Online Classes',
      'Rehab & Recovery Sessions',
    ];

    final headingStyle = GoogleFonts.poppins(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: OnboardingUi.text,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Services & Operations", style: headingStyle),
        const SizedBox(height: 18),

        Text(
          'Facilities / Services',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: OnboardingUi.muted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),

        _buildMultiSelectChips(
          options: facilitiesOptions,
          selectedValues: _selectedFacilities,
          onTap: (value) {
            setState(() {
              if (_selectedFacilities.contains(value)) {
                _selectedFacilities.remove(value);
              } else {
                _selectedFacilities.add(value);
              }
            });
          },
        ),
        const SizedBox(height: 18),

        // Upload Certifications
        TextFormField(
          controller: _certification,
          readOnly: true,
          style: const TextStyle(color: OnboardingUi.text),
          decoration: _inputDecoration(
            label: 'Upload Certifications (PDF/JPEG)',
            icon: Icons.workspace_premium,
            suffixIcon: GestureDetector(
              onTap: _showFileSourceDialog,
              child: const Icon(
                Icons.arrow_circle_up_outlined,
                color: OnboardingUi.muted,
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
                    color: OnboardingUi.text,
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
        const SizedBox(height: 18),

        // Membership Plans (optional)
        TextFormField(
          controller: _membershipPlans,
          style: const TextStyle(color: OnboardingUi.text),
          decoration: _inputDecoration(
            label: 'Membership Plans (optional)',
            icon: Icons.card_membership,
          ),
        ),
        const SizedBox(height: 16),

        // Working Hours
        TextFormField(
          controller: _workingHours,
          style: const TextStyle(color: OnboardingUi.text),
          decoration: _inputDecoration(
            label: 'Working Hours (e.g. 6 AM–10 PM, Mon–Sat)',
            icon: Icons.access_time,
          ),
        ),
      ],
    );
  }

  // ---------- SCREEN 3: EXTRAS ----------

  Widget _buildScreen3() {
    final headingStyle = GoogleFonts.poppins(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: OnboardingUi.text,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Extras", style: headingStyle),
        const SizedBox(height: 18),

        // Special Offers / Discounts
        TextFormField(
          controller: _offers,
          style: const TextStyle(color: OnboardingUi.text),
          decoration: _inputDecoration(
            label: 'Special Offers / Discounts',
            icon: Icons.local_offer,
          ),
        ),
        const SizedBox(height: 16),

        // Products / Services Offered
        TextFormField(
          controller: _productsOffered,
          style: const TextStyle(color: OnboardingUi.text),
          decoration: _inputDecoration(
            label: 'Products / Services Offered',
            icon: Icons.local_mall_outlined,
          ),
        ),
      ],
    );
  }

  // ---------- SCREEN 4: FINAL STEP ----------

  Widget _buildScreen4() {
    final headingStyle = GoogleFonts.poppins(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: OnboardingUi.text,
    );

    final labelStyle = GoogleFonts.poppins(
      fontSize: 15,
      color: OnboardingUi.muted,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Final Step", style: headingStyle),
        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Agree to Terms & Conditions*',
                style: labelStyle,
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
                style: labelStyle,
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
    if (!isValid) return;

    if (_currentStep < 3) {
      setState(() {
        _currentStep++;
      });
    } else {
      _register();
    }
  }

  Future<void> _handleBack() async {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      return;
    }
    await ref.read(authActionProvider.notifier).clearAccountType();
  }

  // ---------- BUILD ----------

  @override
  Widget build(BuildContext context) {
    final progress = (_currentStep + 1) / 4;
    final textTheme =
        GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);
    final padding = OnboardingUi.pagePadding(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: OnboardingUi.pageBg,
        appBar: AppBar(
          backgroundColor: OnboardingUi.pageBg,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: OnboardingUi.text),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: _handleBack,
          ),
          title: Text(
            'Wellness profile',
            style: textTheme.titleMedium?.copyWith(
              color: OnboardingUi.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: OnboardingUi.maxWidth),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: padding),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: OnboardingUi.fieldBorder,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          kPrimaryColor,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      'Step ${_currentStep + 1} of 4',
                      style: textTheme.bodySmall?.copyWith(
                        color: OnboardingUi.muted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(padding, 8, padding, 16),
                      child: Form(
                        key: _formKey,
                        child: _getStepContent(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(padding, 8, padding, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSubmitting ? null : _handleBack,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: kPrimaryColor),
                              foregroundColor: kPrimaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              _currentStep == 0 ? 'Change type' : 'Back',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed:
                                _isSubmitting ? null : _onPrimaryButtonPressed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryColor,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
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
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
