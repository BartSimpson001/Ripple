import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../Repository/model/report_model.dart';
import '../../../../Repository/model/comment_model.dart';
import '../bloc/report_bloc.dart';
import '../bloc/report_event.dart';
import '../bloc/report_state.dart';
import 'report_detail_screen.dart';
import '../../../../common/widgets/network_error_widget.dart';
import '../../../../common/services/network_service.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> 
    with AutomaticKeepAliveClientMixin {
  final Map<String, TextEditingController> _commentControllers = {};
  final Set<String> _openCommentSections = {};
  List<ReportModel> _cachedReports = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final userId = firebase_auth.FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isNotEmpty) {
      context.read<ReportBloc>().add(FetchUserReports(userId));
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ReportBloc>().add(FetchUserPoints(userId));
      });
    }
  }

  @override
  void dispose() {
    _commentControllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Reports", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: BlocListener<ReportBloc, ReportState>(
        listener: (context, state) {
          if (state is PointsAwarded) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('🎉 You earned ${state.pointsAwarded} points!'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          } else if (state is ReportSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
            // OPTIMIZED: Only refresh user reports, not all reports
            final userId = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
            if (userId != null) {
              context.read<ReportBloc>().add(FetchUserReports(userId));
            }
          } else if (state is ReportError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is UserReportsLoaded) {
            _cachedReports = state.reports;
          }
        },
        child: BlocBuilder<ReportBloc, ReportState>(
          builder: (context, state) {
            if (state is ReportLoading && _cachedReports.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is UserReportsLoaded) {
              return _buildUserReportsList(state.reports);
            } else if (state is ReportsLoaded) {
              final currentUserId = firebase_auth.FirebaseAuth.instance.currentUser?.uid ?? '';
              final userReports = state.reports
                  .where((report) => report.userId == currentUserId)
                  .toList();
              return _buildUserReportsList(userReports);
            } else if (_cachedReports.isNotEmpty) {
              // Use cached data while loading
              return _buildUserReportsList(_cachedReports);
            } else if (state is ReportError) {
              final isNetworkError = NetworkService.isNetworkError(state.message);
              return isNetworkError
                  ? NetworkErrorWidget(
                      onRetry: () {
                        final userId = firebase_auth.FirebaseAuth.instance.currentUser?.uid ?? '';
                        if (userId.isNotEmpty) {
                          context.read<ReportBloc>().add(FetchUserReports(userId));
                        }
                      },
                    )
                  : ErrorWidget(
                      message: state.message,
                      onRetry: () {
                        final userId = firebase_auth.FirebaseAuth.instance.currentUser?.uid ?? '';
                        if (userId.isNotEmpty) {
                          context.read<ReportBloc>().add(FetchUserReports(userId));
                        }
                      },
                    );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildUserReportsList(List<ReportModel> reports) {
    if (reports.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.report_problem_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text("No reports yet", style: TextStyle(fontSize: 18, color: Colors.grey)),
            Text("Start reporting issues in your community!", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final userId = firebase_auth.FirebaseAuth.instance.currentUser?.uid ?? '';
        context.read<ReportBloc>().add(FetchUserReports(userId));
        await Future.delayed(const Duration(milliseconds: 300));
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: reports.length,
        itemBuilder: (context, index) => _buildReportCard(reports[index]),
      ),
    );
  }

  Widget _buildReportCard(ReportModel report) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReportDetailScreen(
                report: report,
                readOnlyComments: true,
              ),
            ),
          );
          // REMOVED: Don't refetch after navigation - use cached data
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(report.createdAt),
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        final status = report.status.toLowerCase();
                        if (status == 'resolved' || status == 'in progress') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cannot delete a report that is Resolved or In Progress.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        _showDeleteDialog(report);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'delete',
                        enabled: !(report.status.toLowerCase() == 'resolved' ||
                            report.status.toLowerCase() == 'in progress'),
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete,
                              color: (report.status.toLowerCase() == 'resolved' ||
                                      report.status.toLowerCase() == 'in progress')
                                  ? Colors.grey
                                  : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Delete',
                              style: TextStyle(
                                color: (report.status.toLowerCase() == 'resolved' ||
                                        report.status.toLowerCase() == 'in progress')
                                    ? Colors.grey
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // OPTIMIZED: Use CachedNetworkImage
            if (report.imageUrl.isNotEmpty) _buildImageSection(report),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.description,
                    style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.red.shade600),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          report.location,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Icon(Icons.favorite, size: 16, color: Colors.red.shade400),
                      const SizedBox(width: 4),
                      Text(
                        '${report.likesCount} likes',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                      const SizedBox(width: 16),
                      InkWell(
                        onTap: () {
                          setState(() {
                            if (_openCommentSections.contains(report.id)) {
                              _openCommentSections.remove(report.id);
                            } else {
                              _openCommentSections.add(report.id);
                              context.read<ReportBloc>().add(FetchComments(report.id));
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Row(
                            children: [
                              Icon(
                                _openCommentSections.contains(report.id)
                                    ? Icons.comment
                                    : Icons.comment_outlined,
                                size: 16,
                                color: _openCommentSections.contains(report.id)
                                    ? Colors.blue.shade600
                                    : Colors.blue.shade400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${report.commentsCount} comments',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (_openCommentSections.contains(report.id)) ...[
                    const SizedBox(height: 12),
                    _buildCommentsSection(report.id),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(ReportModel report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report'),
        content: const Text('Are you sure you want to delete this report? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ReportBloc>().add(DeleteReport(report.id));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection(String reportId) {
    return BlocBuilder<ReportBloc, ReportState>(
      builder: (context, state) {
        Widget commentsWidget = const SizedBox.shrink();

        if (state is CommentsLoaded && state.reportId == reportId) {
          commentsWidget = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.comments.isNotEmpty) ...[
                const Text("Comments:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                ...state.comments.map((comment) => _buildCommentItem(comment)),
              ] else ...[
                Text(
                  "No comments yet.",
                  style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          );
        } else if (state is CommentsLoading && state.reportId == reportId) {
          commentsWidget = const Center(
            child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()),
          );
        } else if (state is CommentsError && state.reportId == reportId) {
          commentsWidget = Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    "Error loading comments: ${state.message}",
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => context.read<ReportBloc>().add(FetchComments(reportId)),
                    child: const Text("Retry"),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [commentsWidget],
        );
      },
    );
  }

  Widget _buildCommentItem(CommentModel comment) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.blue.shade200,
            child: Text(
              comment.userName.isNotEmpty ? comment.userName[0].toUpperCase() : "U",
              style: TextStyle(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.userName.isNotEmpty ? comment.userName : "Anonymous User",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(comment.content, style: const TextStyle(fontSize: 12, height: 1.3)),
                const SizedBox(height: 4),
                Text(
                  _formatDate(comment.createdAt),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection(ReportModel report) {
    final isResolved = report.status.toLowerCase() == 'resolved';
    final hasResolvedPhoto = report.resolvedImageUrl.isNotEmpty;

    if (isResolved && hasResolvedPhoto) {
      return _buildBeforeAfterImages(report);
    } else {
      return _buildCachedImage(report.imageUrl, height: 200);
    }
  }

  Widget _buildCachedImage(String imageUrl, {required double height}) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          height: height,
          color: Colors.grey.shade200,
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          height: height,
          color: Colors.grey.shade200,
          child: const Center(
            child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildBeforeAfterImages(ReportModel report) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      'BEFORE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                Container(width: 1, height: 16, color: Colors.grey.shade400),
                Expanded(
                  child: Center(
                    child: Text(
                      'AFTER',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12)),
                  child: _buildCachedImage(report.imageUrl, height: 180),
                ),
              ),
              Container(width: 1, height: 180, color: Colors.grey.shade400),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(bottomRight: Radius.circular(12)),
                  child: _buildCachedImage(report.resolvedImageUrl, height: 180),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}