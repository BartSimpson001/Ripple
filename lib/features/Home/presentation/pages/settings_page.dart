import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ripple_sih/features/Home/presentation/pages/profile_page.dart';
import 'package:ripple_sih/features/auth/presentation/pages/login_screen.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../../common/widgets/custom_snackbar.dart';
import '../../../../common/services/notification_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  String _userFullName = '';
  String _userEmail = '';
  String _username = '';
  String _userInitial = 'U';
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isChangingPassword = false;
  bool _isDeletingAccount = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          setState(() {
            _userFullName = data['fullName'] ?? user.displayName ?? 'User';
            _userEmail = user.email ?? '';
            _username = data['username'] ?? '@user';
            _userInitial = _userFullName.isNotEmpty
                ? _userFullName[0].toUpperCase()
                : 'U';
          });
        } else {
          setState(() {
            _userFullName = user.displayName ?? 'User';
            _userEmail = user.email ?? '';
            _username = '@user';
            _userInitial = _userFullName.isNotEmpty
                ? _userFullName[0].toUpperCase()
                : 'U';
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      CustomSnackBar.show(
        context,
        message: "New passwords do not match",
        backgroundColor: Colors.red,
        icon: Icons.error,
      );
      return;
    }

    if (_newPasswordController.text.length < 6) {
      CustomSnackBar.show(
        context,
        message: "Password must be at least 6 characters long",
        backgroundColor: Colors.red,
        icon: Icons.error,
      );
      return;
    }

    setState(() {
      _isChangingPassword = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        // Reauthenticate user first
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: _currentPasswordController.text,
        );
        await user.reauthenticateWithCredential(credential);

        // Then update password
        await user.updatePassword(_newPasswordController.text);

        Navigator.pop(context); // Close the dialog
        CustomSnackBar.show(
          context,
          message: "Password changed successfully!",
          backgroundColor: Colors.green,
          icon: Icons.check_circle,
        );

        // Clear the text fields
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        CustomSnackBar.show(
          context,
          message: "Current password is incorrect",
          backgroundColor: Colors.red,
          icon: Icons.error,
        );
      } else if (e.code == 'requires-recent-login') {
        CustomSnackBar.show(
          context,
          message: "Please log in again to change your password",
          backgroundColor: Colors.orange,
          icon: Icons.warning,
        );
      } else {
        CustomSnackBar.show(
          context,
          message: "Failed to change password: ${e.message}",
          backgroundColor: Colors.red,
          icon: Icons.error,
        );
      }
    } catch (e) {
      CustomSnackBar.show(
        context,
        message: "Failed to change password: $e",
        backgroundColor: Colors.red,
        icon: Icons.error,
      );
    } finally {
      setState(() {
        _isChangingPassword = false;
      });
    }
  }

  Future<void> _deleteAccount() async {
    setState(() {
      _isDeletingAccount = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Delete user data from Firestore first
        await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();

        // Then delete the auth account
        await user.delete();

        Navigator.pop(context); // Close the dialog

        // Navigate to auth screen after successful deletion
        context.read<AuthBloc>().add(LogoutRequested());

        CustomSnackBar.show(
          context,
          message: "Account deleted successfully",
          backgroundColor: Colors.green,
          icon: Icons.check_circle,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        CustomSnackBar.show(
          context,
          message: "Please log in again to delete your account",
          backgroundColor: Colors.orange,
          icon: Icons.warning,
        );
      } else {
        CustomSnackBar.show(
          context,
          message: "Failed to delete account: ${e.message}",
          backgroundColor: Colors.red,
          icon: Icons.error,
        );
      }
    } catch (e) {
      CustomSnackBar.show(
        context,
        message: "Failed to delete account: $e",
        backgroundColor: Colors.red,
        icon: Icons.error,
      );
    } finally {
      setState(() {
        _isDeletingAccount = false;
      });
    }
  }

  Widget _buildChangePasswordDialog() {
    return AlertDialog(
      title: const Text("Change Password"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _currentPasswordController,
              obscureText: _obscureCurrentPassword,
              decoration: InputDecoration(
                labelText: "Current Password",
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscureCurrentPassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: () {
                    setState(() {
                      _obscureCurrentPassword = !_obscureCurrentPassword;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _newPasswordController,
              obscureText: _obscureNewPassword,
              decoration: InputDecoration(
                labelText: "New Password",
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscureNewPassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: () {
                    setState(() {
                      _obscureNewPassword = !_obscureNewPassword;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              decoration: InputDecoration(
                labelText: "Confirm New Password",
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isChangingPassword ? null : () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _isChangingPassword ? null : _changePassword,
          child: _isChangingPassword
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(),
          )
              : const Text("Change Password"),
        ),
      ],
    );
  }

  Widget _buildDeleteAccountDialog() {
    return AlertDialog(
      title: const Text("Delete Account"),
      content: const Text(
        "Are you sure you want to permanently delete your account? This action cannot be undone and all your data will be lost.",
      ),
      actions: [
        TextButton(
          onPressed: _isDeletingAccount ? null : () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _isDeletingAccount ? null : _deleteAccount,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: _isDeletingAccount
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(color: Colors.white),
          )
              : const Text("Delete", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Settings",style: TextStyle(fontWeight: FontWeight.bold),),
        elevation: 1,
        centerTitle: true,
      ),
      body: Material(
        elevation: 1,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Profile Header
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Profile Picture with Initial
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue.shade100,
                        border: Border.all(color: Colors.blue.shade300, width: 2),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Text(
                              _userInitial,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade600,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.verified,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // User Name
                    Text(
                      _userFullName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Username
                    Text(
                      _username,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Account Section
              _buildSection(
                title: "Account",
                items: [
                  _buildSettingsItem(
                    icon: Icons.person_outline,
                    title: "Edit Profile",
                    onTap: () => _navigateToEditProfile(),
                  ),
                  _buildSettingsItem(
                    icon: Icons.lock_outline,
                    title: "Change Password",
                    onTap: () => _showChangePasswordDialog(),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Settings Section
              _buildSection(
                title: "Settings",
                items: [
                  _buildSettingsItem(
                    icon: Icons.notifications_outlined,
                    title: "Notifications",
                    trailing: Switch.adaptive(
                      value: _notificationsEnabled,
                      onChanged: (value) {
                        setState(() {
                          _notificationsEnabled = value;
                        });
                        _toggleNotifications(value);
                      },
                      activeColor: Colors.blue.shade600,
                    ),
                    showArrow: false,
                  ),
                  _buildSettingsItem(
                    icon: Icons.privacy_tip_outlined,
                    title: "Privacy",
                    onTap: () => _navigateToPrivacy(),
                  ),
                  _buildSettingsItem(
                    icon: Icons.language_outlined,
                    title: "Language",
                    trailing: Text(
                      "English",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                    onTap: () => _showLanguageDialog(),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Support Section
              _buildSection(
                title: "Support",
                items: [
                  _buildSettingsItem(
                    icon: Icons.help_outline,
                    title: "Help Center",
                    onTap: () => _navigateToHelpCenter(),
                  ),
                  _buildSettingsItem(
                    icon: Icons.contact_support_outlined,
                    title: "Contact Us",
                    onTap: () => _navigateToContactUs(),
                  ),
                  _buildSettingsItem(
                    icon: Icons.info_outline,
                    title: "About",
                    onTap: () => _showAboutDialog(),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Danger Zone
              _buildSection(
                title: "Account Actions",
                items: [
                  _buildSettingsItem(
                    icon: Icons.logout,
                    title: "Sign Out",
                    onTap: () => _showSignOutDialog(),
                    textColor: Colors.red.shade600,
                  ),
                  _buildSettingsItem(
                    icon: Icons.delete_outline,
                    title: "Delete Account",
                    onTap: () => _showDeleteAccountDialog(),
                    textColor: Colors.red.shade600,
                  ),
                ],
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> items,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          ...items.map((item) => item),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
    Color? textColor,
    bool showArrow = true,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.shade100,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: textColor ?? Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textColor ?? Colors.black87,
                ),
              ),
            ),
            if (trailing != null) ...[
              trailing,
              const SizedBox(width: 8),
            ],
            if (showArrow && trailing == null)
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
          ],
        ),
      ),
    );
  }

  // Navigation methods
  void _navigateToEditProfile() {
    Navigator.push(context, MaterialPageRoute(builder: (context)=>ProfilePage()));
  }

  void _navigateToPrivacy() {
    CustomSnackBar.show(
      context,
      message: "Privacy settings - Coming soon",
      backgroundColor: Colors.blue,
      icon: Icons.info,
    );
  }

  void _navigateToHelpCenter() {
    CustomSnackBar.show(
      context,
      message: "Help Center - Coming soon",
      backgroundColor: Colors.blue,
      icon: Icons.info,
    );
  }

  void _navigateToContactUs() {
    CustomSnackBar.show(
      context,
      message: "Contact Us - Coming soon",
      backgroundColor: Colors.blue,
      icon: Icons.info,
    );
  }

  // Dialog methods
  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => _buildChangePasswordDialog(),
    );
  }
  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Language"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text("English"),
              trailing: const Icon(Icons.check, color: Colors.blue),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: const Text("Tamil"),
              onTap: () {
                Navigator.pop(context);
                CustomSnackBar.show(
                  context,
                  message: "Tamil language support - Coming soon",
                  backgroundColor: Colors.blue,
                  icon: Icons.info,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("About Ripple 24/7"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Version: 1.0.0"),
            SizedBox(height: 8),
            Text("Build: 1"),
            SizedBox(height: 8),
            Text("A community-driven platform for reporting and resolving local issues."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleNotifications(bool enabled) async {
    try {
      if (enabled) {
        await NotificationService().initialize();
        CustomSnackBar.show(
          context,
          message: "Notifications enabled",
          backgroundColor: Colors.green,
          icon: Icons.notifications_active,
        );
      } else {
        CustomSnackBar.show(
          context,
          message: "Notifications disabled",
          backgroundColor: Colors.orange,
          icon: Icons.notifications_off,
        );
      }
    } catch (e) {
      CustomSnackBar.show(
        context,
        message: "Error toggling notifications: $e",
        backgroundColor: Colors.red,
        icon: Icons.error,
      );
    }
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Sign Out"),
        content: const Text("Are you sure you want to sign out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthBloc>().add(LogoutRequested());


              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Sign Out", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text(
          "Are you sure you want to permanently delete your account? This action cannot be undone and all your data will be lost.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              CustomSnackBar.show(
                context,
                message: "Account deletion not implemented yet",
                backgroundColor: Colors.orange,
                icon: Icons.warning,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}