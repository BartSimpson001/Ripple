import 'dart:io';

import 'package:email_otp/email_otp.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';
import '../common/services/supabase_function.dart';
import '../common/services/point_service.dart';

class AuthRepository {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SupabaseClient _supabase = SupabaseService.client;

  // Token storage keys
  static const String _idTokenKey = 'firebase_id_token';
  static const String _refreshTokenKey = 'firebase_refresh_token';
  static const String _userUidKey = 'user_uid';

  /// Stream to listen for auth state changes
  Stream<firebase_auth.User?> get authStateChanges => _auth.authStateChanges();

  /// Get current user
  firebase_auth.User? getCurrentUser() => _auth.currentUser;

  /// Check if user exists in Firestore
  Future<bool> checkUserExists(String email) async {
    try {
      final QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      return userQuery.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Initialize and check for existing session
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedUid = prefs.getString(_userUidKey);

      if (storedUid != null) {
        final user = _auth.currentUser;
        if (user != null) {
          final idToken = await user.getIdToken(true);
          if (idToken != null) {
            await _saveTokens(idToken, user.refreshToken ?? '', user.uid);
          }

          await _syncUserProfile(user);
        }
      }
    } catch (e) {
      await _clearTokens();
      throw Exception("Session initialization failed: $e");
    }
  }

  Future<void> _saveTokens(
      String idToken, String refreshToken, String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_idTokenKey, idToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
    await prefs.setString(_userUidKey, uid);
  }

  Future<void> storeFcmToken(String userId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _supabase.from('user_devices').upsert({
        'user_id': userId,
        'fcm_token': token,
        'platform': Platform.operatingSystem,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('FCM store failed: $e');
    }
  }

  Future<void> removeFcmToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      await _firestore.collection('users').doc(user.uid).update({
        'fcmToken': FieldValue.delete(),
      });


      await _supabase
          .from('user_devices')
          .delete()
          .eq('fcm_token', token);
    } catch (e) {
      print('FCM remove failed: $e');
    }
  }




  /// Clear tokens
  Future<void> _clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_idTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userUidKey);
  }

  /// Sync profile with Supabase
  Future<void> _syncUserProfile(firebase_auth.User user) async {
    try {
      await _supabase.from('user_profiles').upsert({
        'id': user.uid,
        'full_name':
        user.displayName ?? user.email?.split('@').first ?? 'Anonymous User',
        'email': user.email ?? '',
      });
    } catch (e) {
      print('Warning: Failed to sync user profile with Supabase: $e');
    }
  }

  /// Initialize user points
  Future<void> _initializeUserPoints(String userId, String username) async {
    try {
      final existingPoints = await _supabase
          .from('user_points')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (existingPoints == null) {
        await _supabase.from('user_points').insert({
          'user_id': userId,
          'username': username,
          'total_points': 0,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        print('✅ User points initialized for user: $userId');
      }
    } catch (e) {
      print('Warning: Failed to initialize user points: $e');
    }
  }

  /// Migration
  Future<void> _runMigrationIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const migrationKey = 'migration_completed_v1';
      final migrationCompleted = prefs.getBool(migrationKey) ?? false;

      if (migrationCompleted) {
        print('✅ Migration already completed, skipping...');
        return;
      }

      print('🔄 Running migration...');
      await PointsService.migrateCurrentUser();

      await prefs.setBool(migrationKey, true);
      print('✅ Migration completed.');
    } catch (e) {
      print('❌ Migration failed: $e');
    }
  }

  /// Get ID token
  Future<String?> getIdToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_idTokenKey);
  }

  /// Check if tokens are valid
  Future<bool> hasValidTokens() async {
    final prefs = await SharedPreferences.getInstance();
    final idToken = prefs.getString(_idTokenKey);

    if (idToken != null && idToken.isNotEmpty) {
      try {
        final user = _auth.currentUser;
        if (user != null) {
          final currentToken = await user.getIdToken();
          return currentToken?.isNotEmpty ?? false;
        }
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Sign up
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': email,
          'fullName': fullName,
          'phone': phone,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await user.updateDisplayName(fullName);

        await _syncUserProfile(user);
        await _initializeUserPoints(user.uid, fullName);

        final idToken = await user.getIdToken();
        if (idToken != null) {
          await _saveTokens(idToken, user.refreshToken ?? '', user.uid);
        }
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      await _clearTokens();
      throw Exception(_handleAuthException(e));
    } catch (e) {
      await _clearTokens();
      throw Exception("Failed to store user data: $e");
    }
  }

  /// Login
  Future<void> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        await _syncUserProfile(user);
        await _initializeUserPoints(
          user.uid,
          user.displayName ?? user.email?.split('@').first ?? 'Anonymous User',
        );
        await _runMigrationIfNeeded();

        final idToken = await user.getIdToken();
        if (idToken != null) {
          await _saveTokens(idToken, user.refreshToken ?? '', user.uid);
        }
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      await _clearTokens();
      throw Exception(_handleAuthException(e));
    } catch (e) {
      await _clearTokens();
      throw Exception("Unexpected error: $e");
    }
  }

  /// Refresh token
  Future<String> refreshIdToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("No user logged in");

      final idToken = await user.getIdToken(true);
      if (idToken == null) throw Exception("Failed to refresh token");

      await _saveTokens(idToken, user.refreshToken ?? '', user.uid);
      return idToken;
    } catch (e) {
      await _clearTokens();
      throw Exception("Token refresh failed: $e");
    }
  }

  /// Reset password
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _clearTokens();
    } catch (e) {
      await _clearTokens();
      throw Exception("Sign out failed: $e");
    }
  }

  /// OTP
  Future<void> sendOTP(String email) async {
    try {
      EmailOTP.config(
        appName: "Ripple-24/7",
        appEmail: "tharunpoongavanam@email.com",
        otpLength: 6,
        otpType: OTPType.numeric,
        expiry: 300000,
      );

      final result = await EmailOTP.sendOTP(email: email);
      if (!result) throw Exception("Failed to send OTP");
    } catch (e) {
      throw Exception("OTP sending failed: $e");
    }
  }

  Future<bool> verifyOTP(String otp) async {
    try {
      return EmailOTP.verifyOTP(otp: otp);
    } catch (e) {
      throw Exception("OTP verification failed: $e");
    }
  }

  /// Error handler
  String _handleAuthException(firebase_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'The password is too weak. Please choose a stronger password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This operation is not allowed. Please contact support.';
      case 'invalid-credential':
        return 'Invalid credentials. Please check your email and password.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
