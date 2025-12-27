import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> syncFirebaseUser() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await client.from('user_profiles').upsert({
        'id': user.uid,
        'full_name': user.displayName ?? user.email?.split('@').first ?? 'Anonymous User',
        'email': user.email ?? '',
      });
      print('✅ User profile synced: ${user.uid}');
    } catch (e) {
      print('❌ Failed to sync user profile: $e');
    }
  }

  static Future<bool> testConnection() async {
    try {
      await client.from('reports').select().limit(1);
      print('✅ Supabase connection successful');
      return true;
    } catch (e) {
      print('❌ Supabase connection error: $e');
      return false;
    }
  }
}