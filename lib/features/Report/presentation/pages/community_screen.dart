import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../Repository/model/report_model.dart';
import '../../../../Repository/model/comment_model.dart';
import '../bloc/report_bloc.dart';
import '../bloc/report_event.dart';
import '../bloc/report_state.dart';
import 'report_detail_screen.dart';
import '../../../../common/widgets/network_error_widget.dart';
import '../../../../common/services/network_service.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> with AutomaticKeepAliveClientMixin {
  final Map<String, TextEditingController> _commentControllers = {};
  final Set<String> _openCommentSections = {};
  Timer? _refreshTimer;
  List<ReportModel> _lastLoadedReports = [];
  bool _isCheckingInternet = true;
  bool _isOffline = false;

  // OPTIMIZED: Increased refresh interval to reduce load
  static const Duration _refreshInterval = Duration(seconds: 60);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    context.read<ReportBloc>().add(const FetchAllReports());
    _startAutoRefresh();
    _checkInternet();
  }

  @override
  void dispose() {
    _commentControllers.forEach((key, controller) => controller.dispose());
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkInternet() async {
    setState(() => _isCheckingInternet = true);
    try {
      final result = await InternetAddress.lookup('google.com');
      final hasConnection = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
      if (mounted) {
        setState(() {
          _isOffline = !hasConnection;
          _isCheckingInternet = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isOffline = true;
          _isCheckingInternet = false;
        });
      }
    }
  }

  void _startAutoRefresh() {
    // OPTIMIZED: Only refresh if no comments are open
    _refreshTimer = Timer.periodic(_refreshInterval, (timer) {
      if (mounted && _openCommentSections.isEmpty) {
        context.read<ReportBloc>().add(const FetchAllReports());
      }
    });
  }

  TextEditingController _getCommentController(String reportId) {
    if (!_commentControllers.containsKey(reportId)) {
      _commentControllers[reportId] = TextEditingController();
    }
    return _commentControllers[reportId]!;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    if (_isCheckingInternet) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isOffline) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Community Reports", style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: NetworkErrorWidget(onRetry: _checkInternet),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Community Reports", style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          bottom: const TabBar(
            labelColor: Colors.blue,
            indicatorColor: Colors.blue,
            tabs: [
              Tab(text: "Pending"),
              Tab(text: "In Progress"),
              Tab(text: "Resolved"),
            ],
          ),
        ),
        body: BlocListener<ReportBloc, ReportState>(
          listener: (context, state) {
            if (state is ReportsLoaded) {
              _lastLoadedReports = state.reports;
            }
            if (state is CommentAdded) {
              final controller = _commentControllers[state.reportId];
              controller?.clear();
              // REMOVED: Don't fetch all reports after comment
            }
          },
          child: BlocBuilder<ReportBloc, ReportState>(
            builder: (context, state) {
              if (state is ReportLoading && _lastLoadedReports.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is ReportsLoaded ||
                  (_lastLoadedReports.isNotEmpty && state is! ReportError)) {
                final reports = state is ReportsLoaded ? state.reports : _lastLoadedReports;

                final pendingReports = reports.where((r) => r.status.toLowerCase() == "pending").toList();
                final inProgressReports = reports.where((r) => r.status.toLowerCase() == "in progress").toList();
                final resolvedReports = reports.where((r) => r.status.toLowerCase() == "resolved").toList();

                return TabBarView(
                  children: [
                    _buildReportsList(pendingReports, "No pending reports"),
                    _buildReportsList(inProgressReports, "No reports in progress"),
                    _buildReportsList(resolvedReports, "No resolved reports"),
                  ],
                );
              } else if (state is ReportError) {
                final isNetworkError = NetworkService.isNetworkError(state.message);
                return isNetworkError
                    ? NetworkErrorWidget(
                        onRetry: () => context.read<ReportBloc>().add(const FetchAllReports()),
                      )
                    : CustomErrorWidget(
                        message: state.message,
                        onRetry: () => context.read<ReportBloc>().add(const FetchAllReports()),
                      );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildReportsList(List<ReportModel> reports, String emptyMessage) {
    if (reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<ReportBloc>().add(const FetchAllReports());
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: reports.length,
        // OPTIMIZED: Add item extent hint for better performance
        itemBuilder: (context, index) => _buildReportCard(reports[index]),
      ),
    );
  }

  Widget _buildReportCard(ReportModel report) {
    final isCommentsOpen = _openCommentSections.contains(report.id);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ReportDetailScreen(report: report)),
          );
          // REMOVED: Don't refetch all reports after navigation
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      report.userId.isNotEmpty ? report.userId[0].toUpperCase() : 'U',
                      style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.username.isNotEmpty
                              ? report.username
                              : "User ${report.userId.length > 8 ? report.userId.substring(0, 8) : report.userId}...",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(_formatDate(report.createdAt),
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(report.status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      report.status,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            // OPTIMIZED: Use CachedNetworkImage for better performance
            if (report.imageUrl.isNotEmpty) _buildImageSection(report),

            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(report.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(report.description, style: TextStyle(color: Colors.grey.shade700, height: 1.4)),
                  const SizedBox(height: 8),

                  // Location
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.red.shade600),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(report.location,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Actions - OPTIMIZED: No loading states shown
                  Row(
                    children: [
                      InkWell(
                        onTap: () => context.read<ReportBloc>().add(ToggleLike(report.id)),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                report.isLiked ? Icons.favorite : Icons.favorite_border,
                                color: report.isLiked ? Colors.red : Colors.grey.shade600,
                                size: 20,
                              ),
                              const SizedBox(width: 4),
                              Text("${report.likesCount}", style: TextStyle(color: Colors.grey.shade700)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      InkWell(
                        onTap: () {
                          setState(() {
                            if (isCommentsOpen) {
                              _openCommentSections.remove(report.id);
                            } else {
                              _openCommentSections.add(report.id);
                              context.read<ReportBloc>().add(FetchComments(report.id));
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                isCommentsOpen ? Icons.comment : Icons.comment_outlined,
                                color: isCommentsOpen ? Colors.blue.shade600 : Colors.grey.shade600,
                                size: 20,
                              ),
                              const SizedBox(width: 4),
                              Text("${report.commentsCount}", style: TextStyle(color: Colors.grey.shade700)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Comments Section
                  if (isCommentsOpen) ...[
                    const Divider(height: 24),
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

  Widget _buildCommentsSection(String reportId) {
    return BlocBuilder<ReportBloc, ReportState>(
      builder: (context, state) {
        Widget commentsWidget = const SizedBox.shrink();

        if (state is CommentsLoaded && state.reportId == reportId) {
          commentsWidget = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.comments.isNotEmpty) ...[
                const Text("Comments:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                ...state.comments.map((comment) => _buildCommentItem(comment)),
              ] else ...[
                Text(
                  "No comments yet. Be the first to comment!",
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
              child: CustomErrorWidget(
                message: "Error loading comments: ${state.message}",
                onRetry: () => context.read<ReportBloc>().add(FetchComments(reportId)),
                icon: Icons.comment_outlined,
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            commentsWidget,
            const SizedBox(height: 12),
            // Comment input
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _getCommentController(reportId),
                      decoration: const InputDecoration(
                        hintText: "Add a comment...",
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (value) => _submitComment(reportId),
                    ),
                  ),
                  BlocBuilder<ReportBloc, ReportState>(
                    builder: (context, state) {
                      final isSubmitting = state is CommentAdding && state.reportId == reportId;
                      return IconButton(
                        onPressed: isSubmitting ? null : () => _submitComment(reportId),
                        icon: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(Icons.send, color: Colors.blue.shade600),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _submitComment(String reportId) {
    final controller = _getCommentController(reportId);
    if (controller.text.trim().isNotEmpty) {
      context.read<ReportBloc>().add(AddComment(
            reportId: reportId,
            content: controller.text.trim(),
          ));
      FocusScope.of(context).unfocus();
    }
  }

  Widget _buildCommentItem(CommentModel comment) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.blue.shade200,
            child: Text(
              comment.userName.isNotEmpty ? comment.userName[0].toUpperCase() : "U",
              style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.userName.isNotEmpty ? comment.userName : "Anonymous User",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(comment.content, style: const TextStyle(fontSize: 14, height: 1.3)),
                const SizedBox(height: 6),
                Text(_formatDate(comment.createdAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'in progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
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

  // OPTIMIZED: Use CachedNetworkImage for better performance
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
          child: const Center(child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey)),
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
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade600, fontSize: 12),
                    ),
                  ),
                ),
                Container(width: 1, height: 16, color: Colors.grey.shade400),
                Expanded(
                  child: Center(
                    child: Text(
                      'AFTER',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade600, fontSize: 12),
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
    final diff = now.difference(date);
    if (diff.inDays > 0) return "${diff.inDays}d ago";
    if (diff.inHours > 0) return "${diff.inHours}h ago";
    if (diff.inMinutes > 0) return "${diff.inMinutes}m ago";
    return "Just now";
  }
}

class CustomErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData? icon;
  final bool isNetworkError;

  const CustomErrorWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.icon,
    this.isNetworkError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? (isNetworkError ? Icons.wifi_off : Icons.error),
              size: 64,
              color: isNetworkError ? Colors.orange : Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              isNetworkError ? 'No internet connection' : 'Something went wrong',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(fontSize: 14, color: Colors.grey), textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isNetworkError ? Colors.orange : Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}