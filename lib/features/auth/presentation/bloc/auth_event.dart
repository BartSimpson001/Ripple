import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AppStarted extends AuthEvent {}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;

  const LoginRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class SignUpRequested extends AuthEvent {
  final String email;
  final String password;
  final String fullName;
  final String phone;

  const SignUpRequested({
    required this.email,
    required this.password,
    required this.fullName,
    required this.phone,
  });

  @override
  List<Object?> get props => [email, password, fullName, phone];
}

class CheckUserExistenceAndSendOtp extends AuthEvent {
  final String email;
  final String password;
  final String fullName;
  final String phone;

  const CheckUserExistenceAndSendOtp({
    required this.email,
    required this.password,
    required this.fullName,
    required this.phone,
  });

  @override
  List<Object?> get props => [email, password, fullName, phone];
}

class SendOtpRequested extends AuthEvent {
  final String email;

  const SendOtpRequested({required this.email});

  @override
  List<Object?> get props => [email];
}

class VerifyOtpRequested extends AuthEvent {
  final String otp;
  final String email;

  const VerifyOtpRequested({required this.otp, required this.email});

  @override
  List<Object?> get props => [otp, email];
}

class VerifyOtpAndSignUp extends AuthEvent {
  final String otp;
  final String email;
  final String password;
  final String fullName;
  final String phone;

  const VerifyOtpAndSignUp({
    required this.otp,
    required this.email,
    required this.password,
    required this.fullName,
    required this.phone,
  });

  @override
  List<Object?> get props => [otp, email, password, fullName, phone];
}

class LogoutRequested extends AuthEvent {}

class PasswordResetRequested extends AuthEvent {
  final String email;

  const PasswordResetRequested({required this.email});

  @override
  List<Object?> get props => [email];
}

class AuthStateChanged extends AuthEvent {
  final User? user;

  const AuthStateChanged({required this.user});

  @override
  List<Object?> get props => [user];
}