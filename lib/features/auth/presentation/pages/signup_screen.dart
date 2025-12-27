import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ripple_sih/features/auth/presentation/pages/username_screen.dart';
import 'package:ripple_sih/features/auth/presentation/pages/otp_verification_screen.dart';
import '../../../../common/widgets/custom_snackbar.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool isLoading = false;

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Widget buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool obscureText = false,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
    VoidCallback? onTap,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        readOnly: readOnly,
        keyboardType: keyboardType,
        onTap: onTap,
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25.0),
          ),
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  void sendOtpForSignUp() {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();
    final fullName = nameController.text.trim();
    final phone = phoneController.text.trim();

    // Validation
    if (fullName.isEmpty || phone.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      CustomSnackBar.show(
        context,
        message: "Please fill all fields",
        backgroundColor: Colors.redAccent,
        icon: Icons.warning_amber_rounded,
      );
      return;
    }

    if (!email.contains('@')) {
      CustomSnackBar.show(
        context,
        message: "Invalid email format",
        backgroundColor: Colors.orange,
        icon: Icons.email_outlined,
      );
      return;
    }

    if (password != confirmPassword) {
      CustomSnackBar.show(
        context,
        message: "Passwords do not match",
        backgroundColor: Colors.redAccent,
        icon: Icons.lock_outline,
      );
      return;
    }

    if (password.length < 6) {
      CustomSnackBar.show(
        context,
        message: "Password must be at least 6 characters",
        backgroundColor: Colors.orange,
        icon: Icons.lock_outline,
      );
      return;
    }

    // Check if user exists and send OTP
    context.read<AuthBloc>().add(CheckUserExistenceAndSendOtp(
      email: email,
      password: password,
      fullName: fullName,
      phone: phone,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthLoading) {
          setState(() => isLoading = true);
        } else {
          setState(() => isLoading = false);
        }

        if (state is OtpSent) {
          // Navigate to OTP verification screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpVerificationScreen(
                email: state.email,
                password: state.password,
                fullName: state.fullName,
                phone: state.phone,
                isSignUp: true,
              ),
            ),
          );
        } else if (state is SignUpSuccess) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const UsernameScreen()),
                (Route<dynamic> route) => false,
          );
        } else if (state is AuthError) {
          CustomSnackBar.show(
            context,
            message: state.message,
            backgroundColor: Colors.redAccent,
            icon: Icons.error_outline,
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios, size: 30.0),
          ),
          title: const Text("Sign Up"),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  buildTextField(
                    controller: nameController,
                    label: "Full Name",
                    icon: Icons.person,
                  ),
                  buildTextField(
                    controller: phoneController,
                    label: "Phone Number",
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                  ),
                  buildTextField(
                    controller: emailController,
                    label: "Email",
                    hint: "abc@gmail.com",
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  buildTextField(
                    controller: passwordController,
                    label: "Password",
                    hint: "Enter your password",
                    icon: Icons.lock_outline,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  buildTextField(
                    controller: confirmPasswordController,
                    label: "Confirm Password",
                    hint: "Re-enter your password",
                    icon: Icons.lock_outline,
                    obscureText: _obscureConfirmPassword,
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () {
                        setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                      },
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : sendOtpForSignUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                        "Send OTP",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
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