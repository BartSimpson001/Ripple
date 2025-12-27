import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../Repository/model/user_point_model.dart';

class PointsService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static const int REPORT_RESOLVED_POINTS = 10;
  static const int COMMENT_POINTS = 2;
  static const int LIKE_POINTS = 1;
  static const int REPORT_SUBMITTED_POINTS = 5;

  static String? _getCurrentUserId() {
    return firebase_auth.FirebaseAuth.instance.currentUser?.uid;
  }

  static void _ensureAuthenticated() {
    if (_getCurrentUserId() == null) {
      throw Exception('User not authenticated');
    }
  }

  /// Award points to a user for a resolved report
  static Future<void> awardPointsForResolvedReport(
      String userId,
      String reportId
      ) async {
    try {
      _ensureAuthenticated();

      // Check if points already awarded for this report
      final existingPoints = await _supabase
          .from('point_history')
          .select()
          .eq('user_id', userId)
          .eq('report_id', reportId)
          .eq('action', 'report_resolved');

      if (existingPoints.isNotEmpty) {
        print('Points already awarded for this report');
        return; // Points already awarded
      }

      // Get user info - try to get from user_profiles first, then fallback to Firebase user
      String username = 'Anonymous';
      try {
        final userProfile = await _supabase
            .from('user_profiles')
            .select('full_name')
            .eq('id', userId)
            .maybeSingle();
        
        if (userProfile != null && userProfile['full_name'] != null) {
          username = userProfile['full_name'];
        } else {
          // Fallback to Firebase user info
          final user = firebase_auth.FirebaseAuth.instance.currentUser;
          username = user?.displayName ?? user?.email?.split('@').first ?? 'Anonymous';
        }
      } catch (e) {
        // Fallback to Firebase user info if Supabase query fails
        final user = firebase_auth.FirebaseAuth.instance.currentUser;
        username = user?.displayName ?? user?.email?.split('@').first ?? 'Anonymous';
      }

      // Get current points
      final userPointsResponse = await _supabase
          .from('user_points')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      int currentPoints = userPointsResponse?['total_points'] ?? 0;
      int newPoints = currentPoints + REPORT_RESOLVED_POINTS;

      // Update or insert user points
      await _supabase.from('user_points').upsert({
        'user_id': userId,
        'username': username,
        'total_points': newPoints,
        'updated_at': DateTime.now().toIso8601String(),
      });

      print('✅ Points awarded successfully: +$REPORT_RESOLVED_POINTS points to user $userId (now has $newPoints total points)');

      // Add to point history
      await _supabase.from('point_history').insert({
        'user_id': userId,
        'report_id': reportId,
        'action': 'report_resolved',
        'points_awarded': REPORT_RESOLVED_POINTS,
        'reason': 'Report was resolved',
        'created_at': DateTime.now().toIso8601String(),
      });

      print('Successfully awarded $REPORT_RESOLVED_POINTS points to user $userId');
    } catch (e) {
      print('Error awarding points for resolved report: $e');
      throw Exception('Failed to award points: $e');
    }
  }

  /// Award points for submitting a report
  static Future<void> awardPointsForReportSubmission(
      String userId,
      String reportId
      ) async {
    try {
      _ensureAuthenticated();

      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      final username = user?.displayName ?? user?.email?.split('@').first ?? 'Anonymous';

      // Get current points
      final userPointsResponse = await _supabase
          .from('user_points')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      int currentPoints = userPointsResponse?['total_points'] ?? 0;
      int newPoints = currentPoints + REPORT_SUBMITTED_POINTS;

      // Update or insert user points
      await _supabase.from('user_points').upsert({
        'user_id': userId,
        'username': username,
        'total_points': newPoints,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Add to point history
      await _supabase.from('point_history').insert({
        'user_id': userId,
        'report_id': reportId,
        'action': 'report_submitted',
        'points_awarded': REPORT_SUBMITTED_POINTS,
        'reason': 'Report submitted',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error awarding points for report submission: $e');
      // Don't throw error for submission points
    }
  }

  /// Award points for commenting (limit once per report per user)
  static Future<void> awardPointsForComment(
      String userId,
      String reportId,
      String commentId
      ) async {
    try {
      _ensureAuthenticated();

      // Check if user already got points for commenting on this report
      final existingPoints = await _supabase
          .from('point_history')
          .select()
          .eq('user_id', userId)
          .eq('report_id', reportId)
          .eq('action', 'comment_added');

      if (existingPoints.isNotEmpty) {
        return; // Already awarded points for commenting on this report
      }

      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      final username = user?.displayName ?? user?.email?.split('@').first ?? 'Anonymous';

      // Get current points
      final userPointsResponse = await _supabase
          .from('user_points')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      int currentPoints = userPointsResponse?['total_points'] ?? 0;
      int newPoints = currentPoints + COMMENT_POINTS;

      // Update user points
      await _supabase.from('user_points').upsert({
        'user_id': userId,
        'username': username,
        'total_points': newPoints,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Add to point history
      await _supabase.from('point_history').insert({
        'user_id': userId,
        'report_id': reportId,
        'comment_id': commentId,
        'action': 'comment_added',
        'points_awarded': COMMENT_POINTS,
        'reason': 'Comment added',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error awarding points for comment: $e');
      // Don't throw error for comment points
    }
  }

  /// Award points for receiving a like (limit once per report per user)
  static Future<void> awardPointsForLikeReceived(
      String userId,
      String reportId
      ) async {
    try {
      _ensureAuthenticated();

      // Check if user already got points for receiving a like on this report
      final existingPoints = await _supabase
          .from('point_history')
          .select()
          .eq('user_id', userId)
          .eq('report_id', reportId)
          .eq('action', 'like_received');

      if (existingPoints.isNotEmpty) {
        return; // Already awarded points for receiving a like on this report
      }

      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      final username = user?.displayName ?? user?.email?.split('@').first ?? 'Anonymous';

      // Get current points
      final userPointsResponse = await _supabase
          .from('user_points')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      int currentPoints = userPointsResponse?['total_points'] ?? 0;
      int newPoints = currentPoints + LIKE_POINTS;

      // Update user points
      await _supabase.from('user_points').upsert({
        'user_id': userId,
        'username': username,
        'total_points': newPoints,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Add to point history
      await _supabase.from('point_history').insert({
        'user_id': userId,
        'report_id': reportId,
        'action': 'like_received',
        'points_awarded': LIKE_POINTS,
        'reason': 'Report received a like',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error awarding points for like received: $e');
      // Don't throw error for like points
    }
  }

  /// Fetch user points
  static Future<UserPoints> fetchUserPoints(
      String userId,
      String authToken // Ignored for Supabase
      ) async {
    try {
      final userPointsResponse = await _supabase
          .from('user_points')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (userPointsResponse != null) {
        // Calculate rank
        final rank = await _calculateUserRank(userPointsResponse['total_points'] ?? 0);

        return UserPoints(
          userId: userId,
          username: userPointsResponse['username'] ?? 'Unknown User',
          totalPoints: userPointsResponse['total_points'] ?? 0,
          rank: rank,
          lastUpdated: DateTime.tryParse(userPointsResponse['updated_at'] ?? ''),
        );
      } else {
        // Return default user points
        return UserPoints(
          userId: userId,
          username: 'New User',
          totalPoints: 0,
          rank: await _calculateUserRank(0),
        );
      }
    } catch (e) {
      print('Error fetching user points: $e');
      return UserPoints(
        userId: userId,
        username: 'Unknown User',
        totalPoints: 0,
        rank: 0,
      );
    }
  }

  /// Calculate user rank based on points
  static Future<int> _calculateUserRank(int userPoints) async {
    try {
      final usersWithHigherPoints = await _supabase
          .from('user_points')
          .select('user_id')
          .gt('total_points', userPoints);

      return usersWithHigherPoints.length + 1;
    } catch (e) {
      print('Error calculating rank: $e');
      return 0;
    }
  }

  /// Fetch leaderboard
  static Future<List<UserPoints>> fetchLeaderboard(String authToken) async {
    try {
      final response = await _supabase
          .from('user_points')
          .select()
          .order('total_points', ascending: false)
          .limit(50);

      List<UserPoints> leaderboard = [];
      int rank = 1;

      for (var data in response) {
        leaderboard.add(UserPoints(
          userId: data['user_id'],
          username: data['username'] ?? 'Unknown User',
          totalPoints: data['total_points'] ?? 0,
          rank: rank,
          lastUpdated: DateTime.tryParse(data['updated_at'] ?? ''),
        ));
        rank++;
      }

      return leaderboard;
    } catch (e) {
      print('Error fetching leaderboard: $e');
      return [];
    }
  }

  /// Get current user points (helper method)
  static Future<int> getCurrentUserPoints(String userId) async {
    try {
      final userPoints = await fetchUserPoints(userId, '');
      return userPoints.totalPoints;
    } catch (e) {
      print('Error getting current user points: $e');
      return 0;
    }
  }

  /// Initialize user points when they first sign up
  static Future<void> initializeUserPoints(String userId, String username) async {
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
      print('Error initializing user points: $e');
    }
  }

  /// Migration: Initialize all existing users with 0 points if they don't have points record
  static Future<void> migrateExistingUsers() async {
    try {
      print('🔄 Starting migration for existing users...');
      
      // Check if user is authenticated
      final currentUser = _getCurrentUserId();
      if (currentUser == null) {
        print('⚠️ No authenticated user found. Skipping migration.');
        return;
      }

      // Get all users from user_profiles
      final allUsers = await _supabase
          .from('user_profiles')
          .select('id, full_name');

      // Get all existing user_points user_ids
      final existingUserPoints = await _supabase
          .from('user_points')
          .select('user_id');
      
      final existingUserIds = existingUserPoints
          .map((point) => point['user_id'] as String)
          .toSet();

      int migratedCount = 0;
      int skippedCount = 0;
      
      for (var user in allUsers) {
        final userId = user['id'] as String;
        
        // Check if user already has points record
        if (!existingUserIds.contains(userId)) {
          try {
            // Use upsert instead of insert to avoid RLS issues
            await _supabase.from('user_points').upsert({
              'user_id': userId,
              'username': user['full_name'] ?? 'Anonymous User',
              'total_points': 0,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            });
            migratedCount++;
            print('✅ Migrated user: $userId');
          } catch (e) {
            print('❌ Failed to migrate user $userId: $e');
            skippedCount++;
          }
        } else {
          skippedCount++;
        }
      }
      
      print('🎉 Migration completed! Migrated $migratedCount users, skipped $skippedCount users.');
    } catch (e) {
      print('❌ Error during migration: $e');
      print('💡 Note: Migration requires proper RLS policies or admin access.');
    }
  }

  /// Simple migration: Just initialize current user's points if they don't exist
  static Future<void> migrateCurrentUser() async {
    try {
      final currentUser = _getCurrentUserId();
      if (currentUser == null) {
        print('⚠️ No authenticated user found. Skipping migration.');
        return;
      }

      // Check if current user has points record
      final existingPoints = await _supabase
          .from('user_points')
          .select()
          .eq('user_id', currentUser)
          .maybeSingle();

      if (existingPoints == null) {
        // Get user info
        final userProfile = await _supabase
            .from('user_profiles')
            .select('full_name')
            .eq('id', currentUser)
            .maybeSingle();

        final username = userProfile?['full_name'] ?? 'Anonymous User';

        // Initialize with 0 points
        await _supabase.from('user_points').insert({
          'user_id': currentUser,
          'username': username,
          'total_points': 0,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        print('✅ Current user points initialized: $currentUser');
      } else {
        print('✅ Current user already has points record');
      }
    } catch (e) {
      print('❌ Error migrating current user: $e');
    }
  }
}