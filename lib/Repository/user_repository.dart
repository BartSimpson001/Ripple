import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase/supabase.dart';
import 'model/user_model.dart';
import '../common/services/supabase_function.dart';

class UserRepository {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SupabaseClient _supabase = SupabaseService.client;


  Future<firebase_auth.User?> getCurrentUser() async => _auth.currentUser;


  Future<UserModel?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print("Error fetching from Firestore: $e");
      return null;
    }
  }

  Future<void> updateUserProfile(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set(
        user.toMap(),
        SetOptions(merge: true),
      );

      await _supabase.from('user_profiles').upsert({
        'id': user.uid,
        'full_name': user.fullName,
        'email': user.email,
      });
    } catch (e) {
      print("Error updating profile: $e");
      rethrow;
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.updatePassword(newPassword);
      }
    } catch (e) {
      print("Error updating password: $e");
      rethrow;
    }
  }

  Future<void> deleteUserAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).delete();

        await _supabase.from('user_profiles').delete().eq('id', user.uid);

        await user.delete();
      }
    } catch (e) {
      print("Error deleting account: $e");
      rethrow;
    }
  }
}
