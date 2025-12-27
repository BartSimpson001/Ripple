import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:email_otp/email_otp.dart';
import '../../../../Repository/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  StreamSubscription<User?>? _authStateSubscription;

  AuthBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(AuthInitial()) {
    _authStateSubscription = _authRepository.authStateChanges.listen((user) {
      add(AuthStateChanged(user: user));
    });

    on<AppStarted>(_onAppStarted);
    on<LoginRequested>(_onLoginRequested);
    on<SignUpRequested>(_onSignUpRequested);
    on<CheckUserExistenceAndSendOtp>(_onCheckUserExistenceAndSendOtp);
    on<SendOtpRequested>(_onSendOtpRequested);
    on<VerifyOtpRequested>(_onVerifyOtpRequested);
    on<VerifyOtpAndSignUp>(_onVerifyOtpAndSignUp);
    on<LogoutRequested>(_onLogoutRequested);
    on<PasswordResetRequested>(_onPasswordResetRequested);
    on<AuthStateChanged>(_onAuthStateChanged);
  }

  Future<void> _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final currentUser = _authRepository.getCurrentUser();
      await Future.delayed(const Duration(milliseconds: 500));
      if (currentUser != null) {
        emit(AuthAuthenticated(user: currentUser));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError(message: "App initialization failed: ${e.toString()}"));
    }
  }

  Future<void> _onLoginRequested(
      LoginRequested event,
      Emitter<AuthState> emit,
      ) async {
    emit(AuthLoading());
    try {
      await _authRepository.login(event.email, event.password);

      final user = _authRepository.getCurrentUser();
      if (user != null) {
        await _authRepository.storeFcmToken(user.uid);
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }


  Future<void> _onSignUpRequested(
      SignUpRequested event,
      Emitter<AuthState> emit,
      ) async {
    emit(AuthLoading());
    try {
      await _authRepository.signUp(
        email: event.email,
        password: event.password,
        fullName: event.fullName,
        phone: event.phone,
      );

      final user = _authRepository.getCurrentUser();
      if (user != null) {
        await _authRepository.storeFcmToken(user.uid);
      }

      emit(SignUpSuccess());
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }


  Future<void> _onCheckUserExistenceAndSendOtp(
      CheckUserExistenceAndSendOtp event,
      Emitter<AuthState> emit,
      ) async {
    emit(AuthLoading());
    try {
      // Check if user already exists
      final userExists = await _authRepository.checkUserExists(event.email);

      if (userExists) {
        emit(const AuthError(message: "User already exists with this email. Please try logging in."));
        return;
      }

      // If user doesn't exist, send OTP
      final otpSent = await _sendEmailOTP(event.email);

      if (otpSent) {
        emit(OtpSent(
          email: event.email,
          password: event.password,
          fullName: event.fullName,
          phone: event.phone,
        ));
      } else {
        emit(const AuthError(message: "Failed to send OTP. Please try again."));
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onSendOtpRequested(SendOtpRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final otpSent = await _sendEmailOTP(event.email);

      if (otpSent) {
        emit(OtpSent(email: event.email));
      } else {
        emit(const AuthError(message: "Failed to send OTP. Please try again."));
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onVerifyOtpRequested(VerifyOtpRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final isVerified = _verifyEmailOTP(event.otp);
      if (isVerified) {
        emit(OtpVerified(email: event.email));
      } else {
        emit(const AuthError(message: "Invalid OTP code"));
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onVerifyOtpAndSignUp(VerifyOtpAndSignUp event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      // First verify the OTP
      final isVerified = _verifyEmailOTP(event.otp);

      if (!isVerified) {
        emit(const AuthError(message: "Invalid OTP code"));
        return;
      }

      // If OTP is verified, proceed with sign up
      await _authRepository.signUp(
        email: event.email,
        password: event.password,
        fullName: event.fullName,
        phone: event.phone,
      );

      emit(SignUpSuccess());
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onLogoutRequested(
      LogoutRequested event,
      Emitter<AuthState> emit,
      ) async {
    emit(AuthLoading());
    try {
      await _authRepository.removeFcmToken();
      await _authRepository.signOut();
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onPasswordResetRequested(
      PasswordResetRequested event,
      Emitter<AuthState> emit,
      ) async {
    emit(AuthLoading());
    try {
      await _authRepository.sendPasswordResetEmail(event.email);
      emit(PasswordResetEmailSent());
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  void _onAuthStateChanged(
      AuthStateChanged event,
      Emitter<AuthState> emit,
      ) {
    if (event.user != null) {
      emit(AuthAuthenticated(user: event.user!));
    } else {
      emit(AuthUnauthenticated());
    }
  }

  // Helper method to send email OTP
  Future<bool> _sendEmailOTP(String email) async {
    try {
      EmailOTP.config(
        appName: "Ripple 24/7",
        appEmail: "tharunpoongavanam@gmail.com",
        otpLength: 6,
        otpType: OTPType.numeric,
        expiry: 300000, // 5 minutes
      );

      return await EmailOTP.sendOTP(email: email);
    } catch (e) {
      return false;
    }
  }

  // Helper method to verify email OTP
  bool _verifyEmailOTP(String otp) {
    try {
      return EmailOTP.verifyOTP(otp: otp);
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> close() {
    _authStateSubscription?.cancel();
    return super.close();
  }
}