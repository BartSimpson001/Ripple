import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ripple_sih/features/auth/presentation/pages/username_screen.dart';
import '../../../../common/widgets/custom_snackbar.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String? password;
  final String? fullName;
  final String? phone;
  final bool isSignUp;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    this.password,
    this.fullName,
    this.phone,
    this.isSignUp = false,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController otpController = TextEditingController();
  final List<TextEditingController> otpControllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> otpFocusNodes = List.generate(6, (index) => FocusNode());

  bool isEmailEditable = false;
  bool isLoading = false;
  bool canResendOTP = false;
  int resendCountdown = 60;
  Timer? countdownTimer;

  @override
  void initState() {
    super.initState();
    emailController.text = widget.email;
    startResendCountdown();
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    emailController.dispose();
    otpController.dispose();
    for (var controller in otpControllers) {
      controller.dispose();
    }
    for (var focusNode in otpFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void startResendCountdown() {
    setState(() {
      canResendOTP = false;
      resendCountdown = 60;
    });

    countdownTimer?.cancel();
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendCountdown == 0) {
        timer.cancel();
        setState(() => canResendOTP = true);
      } else {
        setState(() => resendCountdown--);
      }
    });
  }

  void toggleEmailEdit() {
    setState(() {
      isEmailEditable = !isEmailEditable;
    });
  }

  void resendOtp() {
    final email = emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      CustomSnackBar.show(
        context,
        message: "Please enter a valid email",
        backgroundColor: Colors.orange,
        icon: Icons.email_outlined,
      );
      return;
    }

    // Clear previous OTP
    for (var controller in otpControllers) {
      controller.clear();
    }

    if (widget.isSignUp) {
      context.read<AuthBloc>().add(SendOtpRequested(email: email));
    } else {
      context.read<AuthBloc>().add(SendOtpRequested(email: email));
    }

    setState(() => isEmailEditable = false);
  }

  void verifyOtpAndProceed() {
    final otp = otpControllers.map((controller) => controller.text).join();
    final email = emailController.text.trim();

    if (otp.length != 6) {
      CustomSnackBar.show(
        context,
        message: "Please enter the complete 6-digit OTP",
        backgroundColor: Colors.orange,
        icon: Icons.sms_failed,
      );
      return;
    }

    if (widget.isSignUp) {
      context.read<AuthBloc>().add(
        VerifyOtpAndSignUp(
          otp: otp,
          email: email,
          password: widget.password!,
          fullName: widget.fullName!,
          phone: widget.phone!,
        ),
      );
    } else {
      context.read<AuthBloc>().add(
        VerifyOtpRequested(otp: otp, email: email),
      );
    }
  }

  Widget buildOtpField(int index) {
    return Container(
      width: 50,
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(
        controller: otpControllers[index],
        focusNode: otpFocusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: "",
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.blue, width: 2),
          ),
          fillColor: Colors.grey[100],
          filled: true,
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            otpFocusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            otpFocusNodes[index - 1].requestFocus();
          }
        },
      ),
    );
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
          CustomSnackBar.show(
            context,
            message: "OTP sent to ${state.email}",
            backgroundColor: Colors.green,
            icon: Icons.check_circle_outline,
          );
          startResendCountdown();
        } else if (state is OtpVerified) {
          CustomSnackBar.show(
            context,
            message: "OTP verified successfully!",
            backgroundColor: Colors.green,
            icon: Icons.verified_outlined,
          );
          // Handle based on the flow (password reset, etc.)
          Navigator.pop(context, true);
        } else if (state is SignUpSuccess) {
          CustomSnackBar.show(
            context,
            message: "Account created successfully!",
            backgroundColor: Colors.green,
            icon: Icons.check_circle_outline,
          );
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
          title: const Text("Verify OTP"),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const Icon(
                    Icons.email_outlined,
                    size: 80,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Verification Code",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "We've sent a 6-digit verification code to:",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  // Email display with edit option
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.email, color: Colors.grey),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: emailController,
                            enabled: isEmailEditable,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isEmailEditable ? Colors.black : Colors.grey[700],
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: toggleEmailEdit,
                          icon: Icon(
                            isEmailEditable ? Icons.check : Icons.edit,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  // OTP input fields
                  const Text(
                    "Enter verification code",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (index) => buildOtpField(index)),
                  ),
                  const SizedBox(height: 30),
                  // Verify button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : verifyOtpAndProceed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                        widget.isSignUp ? "Verify & Create Account" : "Verify OTP",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Resend OTP section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Didn't receive the code? "),
                      TextButton(
                        onPressed: canResendOTP ? resendOtp : null,
                        child: Text(
                          canResendOTP ? "Resend" : "Resend in ${resendCountdown}s",
                          style: TextStyle(
                            color: canResendOTP ? Colors.blue : Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
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