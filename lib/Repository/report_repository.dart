import 'package:supabase/supabase.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';
import 'model/report_model.dart';
import 'model/comment_model.dart';
import '../common/services/network_service.dart';

class ReportRepository {
  final SupabaseClient supabase;

  ReportRepository({required this.supabase});

  String? _getCurrentUserId() {
    return firebase_auth.FirebaseAuth.instance.currentUser?.uid;
  }

  void _ensureAuthenticated() {
    if (_getCurrentUserId() == null) {
      throw Exception('User not authenticated');
    }
  }

  /// Handle network errors and throw user-friendly exceptions
  Exception _handleError(dynamic error) {
    if (NetworkService.isNetworkError(error)) {
      return Exception(NetworkService.getNetworkErrorMessage(error));
    }
    return Exception('Failed to fetch data: ${error.toString()}');
  }

  Future<void> syncUserProfile({
    required String uid,
    required String fullName,
    required String email,
  }) async {
    try {
      await supabase.from('user_profiles').upsert({
        'id': uid,
        'full_name': fullName,
        'email': email,
      });
    } catch (e) {
      throw Exception('Failed to sync user profile: $e');
    }
  }

  Future<List<ReportModel>> fetchAllReports() async {
    try {
      final response = await supabase
          .from('reports')
          .select('''
            *,
            user_profiles(full_name)
          ''')
          .order('created_at', ascending: false);

      if (response.isEmpty) return [];

      final currentUserId = _getCurrentUserId();
      final List<ReportModel> reports = [];

      for (final json in response) {
        final likesCount = await _getLikesCount(json['id']);
        final commentsCount = await _getCommentsCount(json['id']);

        bool isLiked = false;
        if (currentUserId != null) {
          final likeResponse = await supabase
              .from('likes')
              .select()
              .eq('report_id', json['id'])
              .eq('user_id', currentUserId);
          isLiked = likeResponse.isNotEmpty;
        }

        final report = ReportModel(
          id: json['id'].toString(),
          userId: json['user_id']?.toString() ?? '',
          title: json['title']?.toString() ?? '',
          description: json['description']?.toString() ?? '',
          contact: json['contact']?.toString() ?? '',
          location: json['location']?.toString() ?? '',
          coords: json['coords']?.toString() ?? '',
          timestamp: json['timestamp']?.toString() ?? '',
          imageUrl: json['image_url']?.toString() ?? '',
          resolvedImageUrl: json['resolved_image_url']?.toString() ?? '',
          status: json['status']?.toString() ?? 'Pending',
          createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
          updatedAt: json['updated_at'] != null
              ? DateTime.tryParse(json['updated_at'].toString())
              : null,
          likesCount: likesCount,
          commentsCount: commentsCount,
          isLiked: isLiked,
          username: (json['user_profiles'] as Map<String, dynamic>?)?['full_name']?.toString() ?? 'Anonymous',
        );

        reports.add(report);
      }

      return reports;
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<int> _getLikesCount(dynamic reportId) async {
    try {
      final response = await supabase
          .from('likes')
          .select('id')
          .eq('report_id', reportId);

      return response.length;
    } catch (e) {
      print('Error getting likes count: $e');
      return 0;
    }
  }

  Future<int> _getCommentsCount(dynamic reportId) async {
    try {
      final response = await supabase
          .from('comments')
          .select('id')
          .eq('report_id', reportId);

      return response.length;
    } catch (e) {
      print('Error getting comments count: $e');
      return 0;
    }
  }

  Future<void> toggleLike(String reportId, String userId) async {
    try {
      _ensureAuthenticated();

      final response = await supabase
          .from('likes')
          .select()
          .eq('report_id', reportId)
          .eq('user_id', userId);

      if (response.isNotEmpty) {
        // Unlike - remove the like
        await supabase
            .from('likes')
            .delete()
            .eq('report_id', reportId)
            .eq('user_id', userId);
      } else {
        // Like - add the like
        await supabase.from('likes').insert({
          'report_id': reportId,
          'user_id': userId,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      final newLikesCount = await _getLikesCount(reportId);
      await supabase
          .from('reports')
          .update({'likes_count': newLikesCount})
          .eq('id', reportId);

    } catch (e) {
      throw Exception('Failed to toggle like: $e');
    }
  }

  Future<void> addComment({
    required String reportId,
    required String userId,
    required String userName,
    required String content,
  }) async {
    try {
      _ensureAuthenticated();

      // Add a small delay to simulate network latency
      await Future.delayed(const Duration(milliseconds: 500));

      await supabase.from('comments').insert({
        'report_id': reportId,
        'user_id': userId,
        'user_name': userName,
        'content': content,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Update the comments count in reports table (optional - for caching)
      final newCommentsCount = await _getCommentsCount(reportId);
      await supabase
          .from('reports')
          .update({'comments_count': newCommentsCount})
          .eq('id', reportId);

    } catch (e) {
      throw Exception('Failed to add comment: $e');
    }
  }

  Future<List<CommentModel>> fetchComments(String reportId) async {
    try {
      final response = await supabase
          .from('comments')
          .select()
          .eq('report_id', reportId)
          .order('created_at', ascending: true);

      if (response.isEmpty) return [];

      return (response as List)
          .map((json) => CommentModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch comments: $e');
    }
  }

  Future<void> deleteComment(String commentId) async {
    try {
      _ensureAuthenticated();

      final currentUserId = _getCurrentUserId();

      // Check if user owns the comment
      final response = await supabase
          .from('comments')
          .select('user_id, report_id')
          .eq('id', commentId)
          .single();

      if (response['user_id'] != currentUserId) {
        throw Exception('Unauthorized: Cannot delete this comment');
      }

      // Delete the comment
      await supabase.from('comments').delete().eq('id', commentId);

      // Update the comments count in reports table
      final reportId = response['report_id'];
      final newCommentsCount = await _getCommentsCount(reportId);
      await supabase
          .from('reports')
          .update({'comments_count': newCommentsCount})
          .eq('id', reportId);
    } catch (e) {
      throw Exception('Failed to delete comment: $e');
    }
  }

  Future<void> submitReport({
    required String title,
    required String description,
    required String contact,
    required String location,
    required String coords,
    required String timestamp,
    required XFile imageFile,
    required String userId,
  }) async {
    try {
      _ensureAuthenticated();

      final user = firebase_auth.FirebaseAuth.instance.currentUser!;
      await syncUserProfile(
        uid: user.uid,
        fullName: user.displayName ?? user.email?.split('@').first ?? 'Anonymous User',
        email: user.email ?? '',
      );

      final String imageUrl = await _uploadImage(imageFile);

      await supabase.from('reports').insert({
        'title': title,
        'description': description,
        'contact': contact,
        'location': location,
        'coords': coords,
        'timestamp': timestamp,
        'image_url': imageUrl,
        'user_id': userId,
        'status': 'Pending',
        'created_at': DateTime.now().toIso8601String(),
        'likes_count': 0,
        'comments_count': 0,
      });
    } catch (e) {
      throw Exception('Failed to submit report: $e');
    }
  }

  Future<String> _uploadImage(XFile imageFile) async {
    try {
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.name)}';

      await supabase.storage
          .from('reports')
          .uploadBinary(fileName, await imageFile.readAsBytes());

      final String publicUrl =
      supabase.storage.from('reports').getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  Future<void> deleteReport(String reportId) async {
    try {
      _ensureAuthenticated();

      final currentUserId = _getCurrentUserId();

      final response = await supabase
          .from('reports')
          .select('user_id, image_url')
          .eq('id', reportId)
          .single();

      if (response['user_id'] != currentUserId) {
        throw Exception('Unauthorized: Cannot delete this report');
      }

      // Delete associated likes and comments first
      await supabase.from('likes').delete().eq('report_id', reportId);
      await supabase.from('comments').delete().eq('report_id', reportId);

      // Delete image from storage
      if (response['image_url'] != null &&
          response['image_url'].toString().isNotEmpty) {
        try {
          final imageUrl = response['image_url'] as String;
          final fileName = imageUrl.split('/').last;
          await supabase.storage.from('reports').remove([fileName]);
        } catch (e) {
          print('Warning: Failed to delete image file: $e');
        }
      }

      // Delete the report
      await supabase.from('reports').delete().eq('id', reportId);
    } catch (e) {
      throw Exception('Failed to delete report: $e');
    }
  }

  Future<void> updateReportStatus(String reportId, String newStatus) async {
    try {
      _ensureAuthenticated();

      await supabase
          .from('reports')
          .update({
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String()
      })
          .eq('id', reportId);
    } catch (e) {
      throw Exception('Failed to update report status: $e');
    }
  }

  /// Fetch only current user's reports
  Future<List<ReportModel>> fetchUserReports(String userId) async {
    try {
      _ensureAuthenticated();

      final response = await supabase
          .from('reports')
          .select('''
            *,
            user_profiles(full_name)
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (response.isEmpty) return [];

      final currentUserId = _getCurrentUserId();
      final List<ReportModel> reports = [];

      for (final json in response) {
        // Get actual counts from database - use UUID directly
        final likesCount = await _getLikesCount(json['id']);
        final commentsCount = await _getCommentsCount(json['id']);

        bool isLiked = false;
        if (currentUserId != null) {
          final likeResponse = await supabase
              .from('likes')
              .select()
              .eq('report_id', json['id'])
              .eq('user_id', currentUserId);
          isLiked = likeResponse.isNotEmpty;
        }

        final report = ReportModel(
          id: json['id'].toString(),
          userId: json['user_id']?.toString() ?? '',
          title: json['title']?.toString() ?? '',
          description: json['description']?.toString() ?? '',
          contact: json['contact']?.toString() ?? '',
          location: json['location']?.toString() ?? '',
          coords: json['coords']?.toString() ?? '',
          timestamp: json['timestamp']?.toString() ?? '',
          imageUrl: json['image_url']?.toString() ?? '',
          status: json['status']?.toString() ?? 'Pending',
          createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
          updatedAt: json['updated_at'] != null
              ? DateTime.tryParse(json['updated_at'].toString())
              : null,
          likesCount: likesCount,
          commentsCount: commentsCount,
          isLiked: isLiked,
          username: (json['user_profiles'] as Map<String, dynamic>?)?['full_name']?.toString() ?? 'Anonymous',
        );

        reports.add(report);
      }

      return reports;
    } catch (e) {
      throw Exception('Failed to fetch user reports: $e');
    }
  }
}