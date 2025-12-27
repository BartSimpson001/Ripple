import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final User user;

  const AuthAuthenticated({required this.user});

  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;

  const AuthError({required this.message});

  @override
  List<Object?> get props => [message];
}

class SignUpSuccess extends AuthState {}

class OtpSent extends AuthState {
  final String email;
  final String? password;
  final String? fullName;
  final String? phone;

  const OtpSent({
    required this.email,
    this.password,
    this.fullName,
    this.phone,
  });

  @override
  List<Object?> get props => [email, password, fullName, phone];
}

class OtpVerified extends AuthState {
  final String email;

  const OtpVerified({required this.email});

  @override
  List<Object?> get props => [email];
}

class PasswordResetEmailSent extends AuthState {}

class UserAlreadyExists extends AuthState {
  final String message;

  const UserAlreadyExists({required this.message});

  @override
  List<Object?> get props => [message];
}