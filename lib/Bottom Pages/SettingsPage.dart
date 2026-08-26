import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:halo/app_theme_mode.dart';

import 'package:halo/core/halo_toast.dart';

// HALO Theme Colors
const Color kPrimaryColor = Color(0xFFA58CE3); // Lavender
const Color kSecondaryColor = Color(0xFF5B3FA3); // Deep Purple
const Color kBackgroundColor = Color(0xFFF4F1FB); // Soft lavender background
const Color kChipBg = Color(0xFFEDE7F6); // Light lavender chip background

/// App version; keep in sync with pubspec.yaml version.
const String kAppVersion = '1.0.0';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? currentUser;

  // Settings state
  bool _notificationsEnabled = true;
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _darkMode = false;
  bool _showOnlineStatus = true;
  bool _allowTagging = true;
  bool _allowComments = true;
  bool _showActivityStatus = true;
  bool _twoFactorEnabled = false;

  @override
  void initState() {
    super.initState();
    currentUser = _auth.currentUser;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (currentUser == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final doc = await _firestore.collection('users').doc(currentUser!.uid).get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _notificationsEnabled = data['notificationsEnabled'] ?? true;
          _emailNotifications = data['emailNotifications'] ?? true;
          _pushNotifications = data['pushNotifications'] ?? true;
          _showOnlineStatus = data['showOnlineStatus'] ?? true;
          _allowTagging = data['allowTagging'] ?? true;
          _allowComments = data['allowComments'] ?? true;
          _showActivityStatus = data['showActivityStatus'] ?? true;
          _twoFactorEnabled = data['twoFactorEnabled'] ?? false;
          // Dark mode: prefs is source of truth so theme matches what user last chose on this device
          _darkMode = prefs.getBool('darkMode') ?? (data['darkMode'] ?? false);
        });
      } else {
        setState(() {
          _darkMode = prefs.getBool('darkMode') ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    if (currentUser == null) return;

    try {
      // set(merge: true) so new/social-login users don't crash (update() requires doc to exist)
      await _firestore.collection('users').doc(currentUser!.uid).set({
        'notificationsEnabled': _notificationsEnabled,
        'emailNotifications': _emailNotifications,
        'pushNotifications': _pushNotifications,
        'darkMode': _darkMode,
        'showOnlineStatus': _showOnlineStatus,
        'allowTagging': _allowTagging,
        'allowComments': _allowComments,
        'showActivityStatus': _showActivityStatus,
        'twoFactorEnabled': _twoFactorEnabled,
      }, SetOptions(merge: true));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('darkMode', _darkMode);

      // Apply theme immediately so UI switches light/dark
      setAppThemeMode(_darkMode);

      if (mounted) {
        HaloToast.show('Settings saved successfully!');
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
      if (mounted) {
        HaloToast.show('Something went wrong. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: Text(
              'Save',
              style: GoogleFonts.poppins(
                color: kPrimaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account Section
            _buildSectionHeader('Account', Icons.person),
            _buildSettingsCard([
              _buildSettingsItem(
                'Edit Profile',
                'Update your personal information',
                Icons.edit,
                    () {
                  // Navigate to edit profile
                  Navigator.pop(context, 'edit_profile');
                },
              ),
              _buildSettingsItem(
                'Change Password',
                'Update your account password',
                Icons.lock,
                    () {
                  _showChangePasswordDialog();
                },
              ),
              _buildSettingsItem(
                'Account Information',
                'View your account details',
                Icons.info,
                    () {
                  _showAccountInfo();
                },
              ),
            ]),

            SizedBox(height: 20),

            // Privacy & Security Section
            _buildSectionHeader('Privacy & Security', Icons.security),
            _buildSettingsCard([
              _buildSettingsItem(
                'Privacy Settings',
                'Control who can see your content',
                Icons.visibility,
                    () {
                  Navigator.pop(context, 'privacy');
                },
              ),
              _buildSettingsItem(
                'Blocked Users',
                'Manage blocked accounts',
                Icons.block,
                    () {
                  _showBlockedUsers();
                },
              ),
              _buildSettingsItem(
                'Two-Factor Authentication (preference)',
                'Not real 2FA — saves a preference only',
                Icons.security,
                    () {
                  _showTwoFactorAuth();
                },
              ),
            ]),

            SizedBox(height: 20),

            // Notifications Section
            _buildSectionHeader('Notifications', Icons.notifications),
            _buildSettingsCard([
              _buildSwitchItem(
                'Push Notifications',
                'Receive notifications on your device',
                Icons.notifications_active,
                _pushNotifications,
                    (value) => setState(() => _pushNotifications = value),
              ),
              _buildSwitchItem(
                'Email Notifications',
                'Receive notifications via email',
                Icons.email,
                _emailNotifications,
                    (value) => setState(() => _emailNotifications = value),
              ),
              _buildSwitchItem(
                'Activity Status',
                'Show when you were last active',
                Icons.access_time,
                _showActivityStatus,
                    (value) => setState(() => _showActivityStatus = value),
              ),
            ]),

            SizedBox(height: 20),

            // Content & Interactions Section
            _buildSectionHeader('Content & Interactions', Icons.content_copy),
            _buildSettingsCard([
              _buildSwitchItem(
                'Allow Tagging',
                'Let others tag you in posts',
                Icons.label,
                _allowTagging,
                    (value) => setState(() => _allowTagging = value),
              ),
              _buildSwitchItem(
                'Allow Comments',
                'Let others comment on your posts',
                Icons.comment,
                _allowComments,
                    (value) => setState(() => _allowComments = value),
              ),
              _buildSwitchItem(
                'Show Online Status',
                'Display when you are online',
                Icons.circle,
                _showOnlineStatus,
                    (value) => setState(() => _showOnlineStatus = value),
              ),
            ]),

            SizedBox(height: 20),

            // Display Section
            _buildSectionHeader('Display', Icons.palette),
            _buildSettingsCard([
              _buildSwitchItem(
                'Dark Mode',
                'Use dark theme throughout the app',
                Icons.dark_mode,
                _darkMode,
                    (value) => setState(() => _darkMode = value),
              ),
            ]),

            SizedBox(height: 20),

            // Support Section
            _buildSectionHeader('Support', Icons.help),
            _buildSettingsCard([
              _buildSettingsItem(
                'Help Center',
                'Get help and support',
                Icons.help_center,
                    () {
                  _showHelpCenter();
                },
              ),
              _buildSettingsItem(
                'Contact Us',
                'Send feedback or report issues',
                Icons.contact_support,
                    () {
                  _showContactUs();
                },
              ),
              _buildSettingsItem(
                'About',
                'App version and information',
                Icons.info_outline,
                    () {
                  _showAbout();
                },
              ),
            ]),

            SizedBox(height: 30),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _showLogoutConfirmation();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 16),
                  elevation: 2,
                ),
                child: Text(
                  'Logout',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),

            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.0, left: 4),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kPrimaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: kPrimaryColor, size: 20),
          ),
          SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: kSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsItem(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: kPrimaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: kPrimaryColor, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.poppins(
          fontSize: 13,
          color: Colors.grey[600],
        ),
      ),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: kPrimaryColor.withOpacity(0.6)),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget _buildSwitchItem(String title, String subtitle, IconData icon, bool value, Function(bool) onChanged) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: kPrimaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: kPrimaryColor, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.poppins(
          fontSize: 13,
          color: Colors.grey[600],
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: kPrimaryColor,
        activeTrackColor: kPrimaryColor.withOpacity(0.3),
        inactiveThumbColor: Colors.grey[400],
        inactiveTrackColor: Colors.grey.withOpacity(0.3),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  void _showChangePasswordDialog() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Change Password',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: kSecondaryColor,
            ),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: oldPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      labelStyle: GoogleFonts.poppins(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(Icons.lock, color: kPrimaryColor),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: kPrimaryColor, width: 2),
                      ),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your current password';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: newPasswordController,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      labelStyle: GoogleFonts.poppins(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(Icons.lock_outline, color: kPrimaryColor),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: kPrimaryColor, width: 2),
                      ),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a new password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      labelStyle: GoogleFonts.poppins(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(Icons.lock_outline, color: kPrimaryColor),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: kPrimaryColor, width: 2),
                      ),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your new password';
                      }
                      if (value != newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading
                  ? null
                  : () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                if (!formKey.currentState!.validate()) return;

                setDialogState(() => isLoading = true);

                try {
                  final credential = EmailAuthProvider.credential(
                    email: currentUser!.email!,
                    password: oldPasswordController.text,
                  );
                  await currentUser!.reauthenticateWithCredential(credential);
                  await currentUser!.updatePassword(newPasswordController.text);

                  if (context.mounted) {
                    Navigator.pop(context);
                    HaloToast.show('Password changed successfully!');
                  }
                } on FirebaseAuthException catch (e) {
                  setDialogState(() => isLoading = false);
                  String errorMessage = 'An error occurred';
                  if (e.code == 'wrong-password') {
                    errorMessage = 'Current password is incorrect';
                  } else if (e.code == 'weak-password') {
                    errorMessage = 'New password is too weak';
                  } else {
                    errorMessage = e.message ?? 'An error occurred';
                  }
                  if (context.mounted) {
                    HaloToast.show(errorMessage);
                  }
                } catch (e) {
                  setDialogState(() => isLoading = false);
                  if (context.mounted) {
                    HaloToast.show('Something went wrong. Please try again.');
                  }
                }
              },
              child: Text('Save'),
            ),
          ],
        ),
      ),
    ).then((_) {
      oldPasswordController.dispose();
      newPasswordController.dispose();
      confirmPasswordController.dispose();
    });
  }

  void _showAccountInfo() {
    String formatDate(DateTime? date) {
      if (date == null) return 'Not available';
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Account Information',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: kSecondaryColor,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Email', currentUser?.email ?? 'Not available'),
            SizedBox(height: 12),
            _buildInfoRow('User ID', currentUser?.uid ?? 'Not available'),
            SizedBox(height: 12),
            _buildInfoRow(
              'Account Created',
              formatDate(currentUser?.metadata.creationTime),
            ),
            SizedBox(height: 12),
            _buildInfoRow(
              'Last Sign In',
              formatDate(currentUser?.metadata.lastSignInTime),
            ),
            SizedBox(height: 12),
            _buildInfoRow(
              'Email Verified',
              currentUser?.emailVerified == true ? 'Yes' : 'No',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: kSecondaryColor,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  void _showBlockedUsers() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BlockedUsersPage()),
    );
  }

  void _showTwoFactorAuth() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Two-Factor Authentication (preference)',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: kSecondaryColor,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'This is not real 2FA. Your account is not protected by SMS or an authenticator app. This toggle only saves a preference.',
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.orange.shade900),
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Real two-factor authentication would require backend setup with SMS or authenticator app integration.',
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Enable 2FA',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  Spacer(),
                  Switch(
                    value: _twoFactorEnabled,
                    onChanged: (value) {
                      setDialogState(() {
                        _twoFactorEnabled = value;
                      });
                    },
                  ),
                ],
              ),
              if (_twoFactorEnabled) ...[
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Note:',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: kSecondaryColor,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Full 2FA implementation requires backend setup with SMS or authenticator app integration. This toggle saves your preference.',
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                try {
                  await _firestore
                      .collection('users')
                      .doc(currentUser!.uid)
                      .set(
                        {'twoFactorEnabled': _twoFactorEnabled},
                        SetOptions(merge: true),
                      );
                  setState(() {});
                  if (context.mounted) {
                    HaloToast.show(_twoFactorEnabled
                              ? 'Preference saved (not real 2FA).'
                              : 'Preference saved.');
                    Navigator.pop(context);
                  }
                } catch (e) {
                  debugPrint('Two-factor preference save error: $e');
                  if (context.mounted) {
                    HaloToast.show('Something went wrong. Please try again.');
                  }
                }
              },
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpCenter() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => HelpCenterPage()),
    );
  }

  void _showContactUs() {
    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Contact Us',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: kSecondaryColor,
            ),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: subjectController,
                    decoration: InputDecoration(
                      labelText: 'Subject',
                      labelStyle: GoogleFonts.poppins(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(Icons.subject, color: kPrimaryColor),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: kPrimaryColor, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a subject';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: messageController,
                    decoration: InputDecoration(
                      labelText: 'Message',
                      labelStyle: GoogleFonts.poppins(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(Icons.message, color: kPrimaryColor),
                      alignLabelWithHint: true,
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: kPrimaryColor, width: 2),
                      ),
                    ),
                    maxLines: 5,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your message';
                      }
                      if (value.length < 10) {
                        return 'Message must be at least 10 characters';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading
                  ? null
                  : () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                if (!formKey.currentState!.validate()) return;

                setDialogState(() => isLoading = true);

                try {
                  // Save feedback to Firestore
                  await _firestore.collection('feedback').add({
                    'userId': currentUser!.uid,
                    'email': currentUser!.email,
                    'subject': subjectController.text,
                    'message': messageController.text,
                    'timestamp': FieldValue.serverTimestamp(),
                    'status': 'pending',
                  });

                  // Try to open email client
                  final email = 'support@haloapp.in';
                  final subject = Uri.encodeComponent(subjectController.text);
                  final body = Uri.encodeComponent(
                      'From: ${currentUser!.email}\n\n${messageController.text}');
                  final uri = Uri.parse('mailto:$email?subject=$subject&body=$body');

                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }

                  if (context.mounted) {
                    Navigator.pop(context);
                    HaloToast.show('Feedback submitted successfully!');
                  }
                } catch (e) {
                  debugPrint('Contact Us submit error: $e');
                  setDialogState(() => isLoading = false);
                  if (context.mounted) {
                    HaloToast.show('Something went wrong. Please try again.');
                  }
                }
              },
              child: isLoading
                  ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : Text(
                      'Send',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'About Halo',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: kSecondaryColor,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: $kAppVersion'),
            SizedBox(height: 8),
            Text('Build: 2024.01.01'),
            SizedBox(height: 8),
            Text('A social fitness platform for wellness enthusiasts.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Confirm Logout',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: kSecondaryColor,
          ),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context); // close dialog
              await _auth.signOut(); // ensure Firebase user is signed out
              if (context.mounted) {
                Navigator.pop(context, 'logout');
              }
            },
            child: Text(
              'Logout',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// Blocked Users Page
class BlockedUsersPage extends StatefulWidget {
  @override
  _BlockedUsersPageState createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final blockedRef = _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('blockedUsers');

      final snapshot = await blockedRef.get();
      final blockedIds = snapshot.docs.map((d) => d.id).toList();
      final blockedAtMap = {
        for (var d in snapshot.docs) d.id: d.data()['blockedAt']
      };

      final List<Map<String, dynamic>> blockedList = [];
      const int batchSize = 30; // Firestore 'in' query limit
      for (var i = 0; i < blockedIds.length; i += batchSize) {
        final batch = blockedIds
            .skip(i)
            .take(batchSize)
            .toList();
        if (batch.isEmpty) break;
        final usersSnap = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        for (var userDoc in usersSnap.docs) {
          final userData = userDoc.data();
          blockedList.add({
            'userId': userDoc.id,
            'name': userData['name'] ?? 'Unknown User',
            'username': userData['username'] ?? '',
            'profilePic': userData['profilePic'],
            'blockedAt': blockedAtMap[userDoc.id],
          });
        }
      }

      setState(() {
        _blockedUsers = blockedList;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading blocked users: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _unblockUser(String userId, String userName) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Unblock User',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: kSecondaryColor,
          ),
        ),
        content: Text(
          'Are you sure you want to unblock $userName?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Unblock',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('blockedUsers')
          .doc(userId)
          .delete();

      setState(() {
        _blockedUsers.removeWhere((user) => user['userId'] == userId);
      });

      HaloToast.show('$userName has been unblocked');
    } catch (e) {
      debugPrint('Error unblocking user: $e');
      if (mounted) {
        HaloToast.show('Something went wrong. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Blocked Users',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _blockedUsers.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
                      Text(
                        'No blocked users',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
            SizedBox(height: 8),
                      Text(
                        'Users you block will appear here',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
          ],
        ),
      )
          : ListView.builder(
        itemCount: _blockedUsers.length,
        itemBuilder: (context, index) {
          final user = _blockedUsers[index];
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 2,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user['profilePic'] != null
                              ? NetworkImage(user['profilePic'])
                              : null,
                          child: user['profilePic'] == null
                              ? Icon(Icons.person, color: kPrimaryColor)
                              : null,
                        ),
                        title: Text(
                          user['name'],
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        subtitle: user['username'].isNotEmpty
                            ? Text(
                                '@${user['username']}',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              )
                            : null,
                        trailing: ElevatedButton(
                          onPressed: () => _unblockUser(
                            user['userId'],
                            user['name'],
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Unblock',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    );
        },
      ),
    );
  }
}

// Help Center Page
class HelpCenterPage extends StatelessWidget {
  final List<Map<String, String>> _faqs = [
    {
      'question': 'How do I edit my profile?',
      'answer':
      'Go to Settings > Account > Edit Profile. You can update your name, username, bio, and profile picture from there.',
    },
    {
      'question': 'How do I change my password?',
      'answer':
      'Go to Settings > Account > Change Password. Enter your current password and your new password to update it.',
    },
    {
      'question': 'How do I block a user?',
      'answer':
      'Visit the user\'s profile and tap the menu icon, then select "Block User". You can manage blocked users in Settings > Privacy & Security > Blocked Users.',
    },
    {
      'question': 'How do I enable two-factor authentication?',
      'answer':
      'Go to Settings > Privacy & Security > Two-Factor Authentication and toggle it on. This adds an extra layer of security to your account.',
    },
    {
      'question': 'How do I report inappropriate content?',
      'answer':
      'Tap the three dots on any post or comment and select "Report". Our team will review the content and take appropriate action.',
    },
    {
      'question': 'How do I delete my account?',
      'answer':
      'Please contact our support team through Settings > Support > Contact Us to request account deletion.',
    },
    {
      'question': 'How do I manage notifications?',
      'answer':
      'Go to Settings > Notifications to control which notifications you receive. You can toggle push notifications, email notifications, and activity status.',
    },
    {
      'question': 'How do I change my privacy settings?',
      'answer':
      'Go to Settings > Privacy & Security > Privacy Settings to control who can see your content, tag you, and comment on your posts.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Help Center',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Card(
            elevation: 2,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.help_outline, color: kPrimaryColor, size: 28),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Frequently Asked Questions',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: kSecondaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Find answers to common questions about using Halo.',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),
          ..._faqs.asMap().entries.map((entry) {
            final index = entry.key;
            final faq = entry.value;
            return _buildFAQItem(faq['question']!, faq['answer']!, index);
          }),
          SizedBox(height: 20),
          Card(
            elevation: 2,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.contact_support, color: kPrimaryColor),
              ),
              title: Text(
                'Still need help?',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              subtitle: Text(
                'Contact our support team',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              trailing: Icon(Icons.arrow_forward_ios, size: 16, color: kPrimaryColor.withOpacity(0.6)),
              onTap: () {
                Navigator.pop(context);
                // The parent SettingsPage will handle opening Contact Us
              },
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer, int index) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(
          question,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        iconColor: kPrimaryColor,
        collapsedIconColor: kPrimaryColor,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              answer,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
