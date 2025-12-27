import 'package:equatable/equatable.dart';

abstract class ReportEvent extends Equatable {
  const ReportEvent();

  @override
  List<Object?> get props => [];
}

/// Add a new report
class AddReport extends ReportEvent {
  final String userId;
  final String title;
  final String description;
  final String contact;
  final String address;
  final String coords;
  final String timestamp;
  final String imagePath;
  final String? authToken;

  const AddReport({
    required this.userId,
    required this.title,
    required this.description,
    required this.contact,
    required this.address,
    required this.coords,
    required this.timestamp,
    required this.imagePath,
    this.authToken,
  });

  @override
  List<Object?> get props => [
    userId,
    title,
    description,
    contact,
    address,
    coords,
    timestamp,
    imagePath,
    authToken,
  ];
}

/// Fetch all reports
class FetchAllReports extends ReportEvent {
  final String? authToken;

  const FetchAllReports({this.authToken});

  @override
  List<Object?> get props => [authToken];
}

/// Fetch reports for a specific user
class FetchUserReports extends ReportEvent {
  final String userId;
  final String? authToken;

  const FetchUserReports(this.userId, {this.authToken});

  @override
  List<Object?> get props => [userId, authToken];
}

/// Toggle like on a report
class ToggleLike extends ReportEvent {
  final String reportId;
  final String? authToken;

  const ToggleLike(this.reportId, {this.authToken});

  @override
  List<Object?> get props => [reportId, authToken];
}

/// Add a comment to a report
class AddComment extends ReportEvent {
  final String reportId;
  final String content;
  final String? authToken;

  const AddComment({
    required this.reportId,
    required this.content,
    this.authToken,
  });

  @override
  List<Object?> get props => [reportId, content, authToken];
}

/// Fetch comments for a report
class FetchComments extends ReportEvent {
  final String reportId;
  final String? authToken;

  const FetchComments(this.reportId, {this.authToken});

  @override
  List<Object?> get props => [reportId, authToken];
}

/// Delete a report
class DeleteReport extends ReportEvent {
  final String reportId;
  final String? authToken;

  const DeleteReport(this.reportId, {this.authToken});

  @override
  List<Object?> get props => [reportId, authToken];
}

/// Delete a comment
class DeleteComment extends ReportEvent {
  final String commentId;
  final String? authToken;

  const DeleteComment(this.commentId, {this.authToken});

  @override
  List<Object?> get props => [commentId, authToken];
}

/// Update a report's status (resolved / pending / in progress / rejected)
class UpdateReportStatus extends ReportEvent {
  final String reportId;
  final String newStatus;
  final String? authToken;

  const UpdateReportStatus(
      this.reportId,
      this.newStatus, {
        this.authToken,
      });

  @override
  List<Object?> get props => [reportId, newStatus, authToken];
}

/// Award points when report is resolved
class AwardPointsForReport extends ReportEvent {
  final String reportId;
  final String userId;
  final String? authToken;

  const AwardPointsForReport({
    required this.reportId,
    required this.userId,
    this.authToken,
  });

  @override
  List<Object?> get props => [reportId, userId, authToken];
}

/// Fetch user points
class FetchUserPoints extends ReportEvent {
  final String userId;
  final String? authToken;

  const FetchUserPoints(this.userId, {this.authToken});

  @override
  List<Object?> get props => [userId, authToken];
}

/// Fetch leaderboard data
class FetchLeaderboard extends ReportEvent {
  final String? authToken;

  const FetchLeaderboard({this.authToken});

  @override
  List<Object?> get props => [authToken];
}