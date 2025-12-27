import 'package:equatable/equatable.dart';
import '../../../../Repository/model/comment_model.dart';
import '../../../../Repository/model/report_model.dart';
import '../../../../Repository/model/user_point_model.dart';

abstract class ReportState extends Equatable {
  const ReportState();

  @override
  List<Object?> get props => [];
}

class ReportInitial extends ReportState {}

class ReportLoading extends ReportState {
  final bool isInitialLoad;
  const ReportLoading({this.isInitialLoad = true});

  @override
  List<Object?> get props => [isInitialLoad];
}

class ReportSuccess extends ReportState {
  final String message;
  const ReportSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class ReportError extends ReportState {
  final String message;
  const ReportError(this.message);

  @override
  List<Object?> get props => [message];
}

class ReportAuthRequired extends ReportState {
  final String message;
  const ReportAuthRequired(this.message);

  @override
  List<Object?> get props => [message];
}

// Report Lists States
class ReportsLoaded extends ReportState {
  final List<ReportModel> reports;
  const ReportsLoaded(this.reports);

  @override
  List<Object?> get props => [reports];
}

class UserReportsLoaded extends ReportState {
  final List<ReportModel> reports;
  const UserReportsLoaded(this.reports);

  @override
  List<Object?> get props => [reports];
}

// Comment States
class CommentsLoading extends ReportState {
  final String reportId;
  const CommentsLoading(this.reportId);

  @override
  List<Object?> get props => [reportId];
}

class CommentsLoaded extends ReportState {
  final String reportId;
  final List<CommentModel> comments;

  const CommentsLoaded(this.reportId, this.comments);

  @override
  List<Object?> get props => [reportId, comments];
}

class CommentsError extends ReportState {
  final String reportId;
  final String message;
  const CommentsError(this.reportId, this.message);

  @override
  List<Object?> get props => [reportId, message];
}

class CommentAdding extends ReportState {
  final String reportId;
  const CommentAdding(this.reportId);

  @override
  List<Object?> get props => [reportId];
}

class CommentAdded extends ReportState {
  final String reportId;
  const CommentAdded(this.reportId);

  @override
  List<Object?> get props => [reportId];
}

class CommentError extends ReportState {
  final String message;
  const CommentError(this.message);

  @override
  List<Object?> get props => [message];
}

class CommentDeleted extends ReportState {
  final String commentId;
  final String reportId;
  const CommentDeleted(this.commentId, this.reportId);

  @override
  List<Object?> get props => [commentId, reportId];
}

// Like States
class LikeToggled extends ReportState {
  final String reportId;
  final bool isLiked;
  const LikeToggled(this.reportId, this.isLiked);

  @override
  List<Object?> get props => [reportId, isLiked];
}

// Points and Awards States
class PointsLoading extends ReportState {
  const PointsLoading();
}

class PointsAwarded extends ReportState {
  final int pointsAwarded;
  final String reportId;
  final String userId;

  const PointsAwarded({
    required this.pointsAwarded,
    required this.reportId,
    required this.userId,
  });

  @override
  List<Object?> get props => [pointsAwarded, reportId, userId];
}

class UserPointsLoaded extends ReportState {
  final UserPoints userPoints;

  const UserPointsLoaded(this.userPoints);

  @override
  List<Object?> get props => [userPoints];
}

class LeaderboardLoaded extends ReportState {
  final List<UserPoints> leaderboard;

  const LeaderboardLoaded(this.leaderboard);

  @override
  List<Object?> get props => [leaderboard];
}

class PointsError extends ReportState {
  final String message;

  const PointsError(this.message);

  @override
  List<Object?> get props => [message];
}