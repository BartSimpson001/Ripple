import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:image_picker/image_picker.dart';
import 'package:rxdart/rxdart.dart';
import 'dart:async';
import '../../../../Repository/model/report_model.dart';
import '../../../../Repository/report_repository.dart';
import '../../../../common/services/point_service.dart';
import 'report_event.dart';
import 'report_state.dart';

class ReportBloc extends Bloc<ReportEvent, ReportState> {
  final ReportRepository reportRepository;
  Timer? _debounceTimer;
  DateTime? _lastFetchTime;
  static const _cacheDuration = Duration(seconds: 5);

  ReportBloc({required this.reportRepository}) : super(ReportInitial()) {
    on<AddReport>(_onAddReport);
    on<FetchAllReports>(_onFetchAllReports);
    on<FetchUserReports>(_onFetchUserReports);
    on<ToggleLike>(_onToggleLike, transformer: _debounce(const Duration(milliseconds: 500)));
    on<AddComment>(_onAddComment, transformer: _debounce(const Duration(milliseconds: 500)));
    on<FetchComments>(_onFetchComments);
    on<DeleteReport>(_onDeleteReport);
    on<DeleteComment>(_onDeleteComment);
    on<UpdateReportStatus>(_onUpdateReportStatus);
    on<AwardPointsForReport>(_onAwardPointsForReport);
    on<FetchUserPoints>(_onFetchUserPoints);
    on<FetchLeaderboard>(_onFetchLeaderboard);
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }

  // Debounce transformer to prevent rapid-fire events
  EventTransformer<T> _debounce<T>(Duration duration) {
    return (events, mapper) {
      return events
          .debounceTime(duration)
          .asyncExpand(mapper);
    };
  }

  /// OPTIMIZED: Toggle Like with immediate UI update
  Future<void> _onToggleLike(ToggleLike event, Emitter<ReportState> emit) async {
    try {
      final userId = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
      if (userId == null || userId.isEmpty) {
        emit(const ReportError('User not authenticated.'));
        return;
      }

      bool wasLiked = false;
      
      // OPTIMISTIC UPDATE - Update UI immediately
      if (state is ReportsLoaded) {
        final currentReports = (state as ReportsLoaded).reports;
        final reportIndex = currentReports.indexWhere((r) => r.id == event.reportId);
        
        if (reportIndex != -1) {
          wasLiked = currentReports[reportIndex].isLiked;
          final updatedReport = currentReports[reportIndex].copyWith(
            likesCount: wasLiked
                ? currentReports[reportIndex].likesCount - 1
                : currentReports[reportIndex].likesCount + 1,
            isLiked: !wasLiked,
          );

          final updatedReports = List<ReportModel>.from(currentReports);
          updatedReports[reportIndex] = updatedReport;
          
          // Emit immediately for instant UI feedback
          emit(ReportsLoaded(updatedReports));
        }
      }

      // Perform background operations without blocking UI
      _performLikeOperations(event.reportId, userId, wasLiked);

    } catch (e) {
      emit(ReportError('Failed to like/unlike report: $e'));
    }
  }

  // Background operations for like
  Future<void> _performLikeOperations(String reportId, String userId, bool wasLiked) async {
    try {
      // Toggle like in database
      await reportRepository.toggleLike(reportId, userId);

      // Award points only for new likes
      if (!wasLiked) {
        try {
          final reports = await reportRepository.fetchAllReports();
          final report = reports.firstWhere(
            (r) => r.id == reportId,
            orElse: () => throw Exception('Report not found'),
          );
          await PointsService.awardPointsForLikeReceived(report.userId, reportId);
        } catch (e) {
          print('Error awarding like points: $e');
        }
      }
    } catch (e) {
      print('Background like operation failed: $e');
    }
  }

  /// OPTIMIZED: Add Comment with immediate UI update
  Future<void> _onAddComment(AddComment event, Emitter<ReportState> emit) async {
    emit(CommentAdding(event.reportId));

    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        emit(const ReportError('User not authenticated.'));
        return;
      }

      final userName = user.displayName ?? user.email?.split('@').first ?? 'Anonymous';

      // Add comment to database
      await reportRepository.addComment(
        reportId: event.reportId,
        userId: user.uid,
        userName: userName,
        content: event.content,
      );

      // Emit success immediately
      emit(CommentAdded(event.reportId));

      // Fetch updated comments (only for this report, not all reports)
      final comments = await reportRepository.fetchComments(event.reportId);
      emit(CommentsLoaded(event.reportId, comments));

      // Update comment count in reports list
      _updateCommentCountInReports(event.reportId);

      // Award points in background
      _awardCommentPoints(user.uid, event.reportId, event.content);

    } catch (e) {
      emit(ReportError('Failed to add comment: $e'));
    }
  }

  // Update comment count without refetching all reports
  void _updateCommentCountInReports(String reportId) {
    if (state is ReportsLoaded) {
      final currentReports = (state as ReportsLoaded).reports;
      final reportIndex = currentReports.indexWhere((r) => r.id == reportId);
      
      if (reportIndex != -1) {
        final updatedReport = currentReports[reportIndex].copyWith(
          commentsCount: currentReports[reportIndex].commentsCount + 1,
        );

        final updatedReports = List<ReportModel>.from(currentReports);
        updatedReports[reportIndex] = updatedReport;
        emit(ReportsLoaded(updatedReports));
      }
    }
  }

  // Award points in background
  Future<void> _awardCommentPoints(String userId, String reportId, String content) async {
    try {
      final comments = await reportRepository.fetchComments(reportId);
      final newComment = comments.firstWhere(
        (comment) => comment.content == content && comment.userId == userId,
        orElse: () => throw Exception('Comment not found'),
      );
      await PointsService.awardPointsForComment(userId, reportId, newComment.id);
    } catch (e) {
      print('Error awarding comment points: $e');
    }
  }

  /// OPTIMIZED: Fetch all reports with caching
  Future<void> _onFetchAllReports(FetchAllReports event, Emitter<ReportState> emit) async {
    // Check cache - don't refetch if recently fetched
    if (_lastFetchTime != null && 
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
      return; // Use cached data
    }

    // Only show loading for initial load
    if (state is! ReportsLoaded) {
      emit(const ReportLoading());
    }

    try {
      final reports = await reportRepository.fetchAllReports();
      _lastFetchTime = DateTime.now();
      emit(ReportsLoaded(reports));
    } catch (e) {
      emit(ReportError('Failed to fetch reports: $e'));
    }
  }

  /// Add a new report
  Future<void> _onAddReport(AddReport event, Emitter<ReportState> emit) async {
    emit(const ReportLoading());
    try {
      final userId = firebase_auth.FirebaseAuth.instance.currentUser?.uid ?? event.userId;

      if (userId.isEmpty) {
        emit(const ReportError('User not authenticated.'));
        return;
      }

      final imageFile = XFile(event.imagePath);

      await reportRepository.submitReport(
        title: event.title,
        description: event.description,
        contact: event.contact,
        location: event.address,
        coords: event.coords,
        timestamp: event.timestamp,
        imageFile: imageFile,
        userId: userId,
      );

      // Award points in background
      _awardReportSubmissionPoints(userId, event.title, event.description);

      emit(const ReportSuccess('Report submitted successfully!'));
      
      // Invalidate cache and refresh
      _lastFetchTime = null;
      add(FetchUserReports(userId));
    } catch (e) {
      emit(ReportError('Failed to add report: $e'));
    }
  }

  Future<void> _awardReportSubmissionPoints(String userId, String title, String description) async {
    try {
      final reports = await reportRepository.fetchUserReports(userId);
      final newReport = reports.firstWhere(
        (report) => report.title == title && report.description == description,
        orElse: () => throw Exception('Report not found'),
      );
      await PointsService.awardPointsForReportSubmission(userId, newReport.id);
    } catch (e) {
      print('Error awarding submission points: $e');
    }
  }

  /// Fetch user reports
  Future<void> _onFetchUserReports(FetchUserReports event, Emitter<ReportState> emit) async {
    emit(const ReportLoading());
    try {
      final userId = firebase_auth.FirebaseAuth.instance.currentUser?.uid ?? event.userId;

      if (userId.isEmpty) {
        emit(const ReportError('User not authenticated.'));
        return;
      }

      final reports = await reportRepository.fetchUserReports(userId);
      emit(UserReportsLoaded(reports));
    } catch (e) {
      emit(ReportError('Failed to fetch user reports: $e'));
    }
  }

  /// Fetch comments
  Future<void> _onFetchComments(FetchComments event, Emitter<ReportState> emit) async {
    emit(CommentsLoading(event.reportId));

    try {
      final comments = await reportRepository.fetchComments(event.reportId);
      emit(CommentsLoaded(event.reportId, comments));
    } catch (e) {
      emit(CommentsError(event.reportId, 'Failed to fetch comments: $e'));
    }
  }

  /// Delete report
  Future<void> _onDeleteReport(DeleteReport event, Emitter<ReportState> emit) async {
    emit(const ReportLoading());
    try {
      final userId = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
      if (userId == null || userId.isEmpty) {
        emit(const ReportError('User not authenticated.'));
        return;
      }

      await reportRepository.deleteReport(event.reportId);
      emit(const ReportSuccess('Report deleted successfully!'));
      
      _lastFetchTime = null;
      add(FetchUserReports(userId));
    } catch (e) {
      emit(ReportError('Failed to delete report: $e'));
    }
  }

  /// Delete comment
  Future<void> _onDeleteComment(DeleteComment event, Emitter<ReportState> emit) async {
    try {
      final userId = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
      if (userId == null || userId.isEmpty) {
        emit(const ReportError('User not authenticated.'));
        return;
      }

      String? reportId;
      if (state is CommentsLoaded) {
        final comments = (state as CommentsLoaded).comments;
        final comment = comments.firstWhere(
          (c) => c.id == event.commentId,
          orElse: () => throw Exception('Comment not found'),
        );
        reportId = comment.reportId;
      }

      await reportRepository.deleteComment(event.commentId);
      emit(CommentDeleted(event.commentId, reportId ?? ''));

      if (reportId != null) {
        final comments = await reportRepository.fetchComments(reportId);
        emit(CommentsLoaded(reportId, comments));
      }
    } catch (e) {
      emit(ReportError('Failed to delete comment: $e'));
    }
  }

  /// Update report status
  Future<void> _onUpdateReportStatus(UpdateReportStatus event, Emitter<ReportState> emit) async {
    emit(const ReportLoading());
    try {
      final userId = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
      if (userId == null || userId.isEmpty) {
        emit(const ReportError('User not authenticated.'));
        return;
      }

      await reportRepository.updateReportStatus(event.reportId, event.newStatus);

      if (event.newStatus.toLowerCase() == 'resolved') {
        _awardResolvedReportPoints(event.reportId);
      }

      emit(const ReportSuccess('Report status updated successfully!'));
      
      _lastFetchTime = null;
      add(const FetchAllReports());
      add(FetchUserReports(userId));
    } catch (e) {
      emit(ReportError('Failed to update report status: $e'));
    }
  }

  Future<void> _awardResolvedReportPoints(String reportId) async {
    try {
      final reports = await reportRepository.fetchAllReports();
      final report = reports.firstWhere(
        (r) => r.id == reportId,
        orElse: () => throw Exception('Report not found'),
      );
      await PointsService.awardPointsForResolvedReport(report.userId, reportId);
      add(FetchUserPoints(report.userId));
      add(const FetchLeaderboard());
    } catch (e) {
      print('Error awarding points: $e');
    }
  }

  /// Award points
  Future<void> _onAwardPointsForReport(AwardPointsForReport event, Emitter<ReportState> emit) async {
    emit(const PointsLoading());
    try {
      await PointsService.awardPointsForResolvedReport(event.userId, event.reportId);

      emit(PointsAwarded(
        pointsAwarded: PointsService.REPORT_RESOLVED_POINTS,
        reportId: event.reportId,
        userId: event.userId,
      ));

      add(FetchUserPoints(event.userId));
      
      _lastFetchTime = null;
      add(const FetchAllReports());
      add(FetchUserReports(event.userId));
    } catch (e) {
      emit(PointsError('Failed to award points: $e'));
    }
  }

  /// Fetch user points
  Future<void> _onFetchUserPoints(FetchUserPoints event, Emitter<ReportState> emit) async {
    try {
      final userPoints = await PointsService.fetchUserPoints(event.userId, '');
      emit(UserPointsLoaded(userPoints));
    } catch (e) {
      emit(PointsError('Failed to fetch user points: $e'));
    }
  }

  /// Fetch leaderboard
  Future<void> _onFetchLeaderboard(FetchLeaderboard event, Emitter<ReportState> emit) async {
    emit(const PointsLoading());
    try {
      final leaderboard = await PointsService.fetchLeaderboard('');
      emit(LeaderboardLoaded(leaderboard));
    } catch (e) {
      emit(PointsError('Failed to fetch leaderboard: $e'));
    }
  }
}