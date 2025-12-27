import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../Repository/model/report_model.dart';
import '../../../../Repository/model/comment_model.dart';
import '../bloc/report_bloc.dart';
import '../bloc/report_event.dart';
import '../bloc/report_state.dart';

class ReportDetailScreen extends StatefulWidget {
  final ReportModel report;
  final bool readOnlyComments;

  const ReportDetailScreen({
    super.key,
    required this.report,
    this.readOnlyComments = false,
  });

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _currentUserId;
  String? _currentUserName;
  List<CommentModel> _cachedComments = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initializeUser();
    _loadComments();
  }

  void _initializeUser() {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    _currentUserId = user?.uid;
    _currentUserName = user?.displayName ?? user?.email?.split('@').first ?? 'Anonymous';

    if (_currentUserId != null) {
      context.read<ReportBloc>().add(FetchUserPoints(_currentUserId!));
    }
  }

  void _loadComments() {
    context.read<ReportBloc>().add(FetchComments(widget.report.id));
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Report Details"),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadComments,
          ),
        ],
      ),
      body: BlocListener<ReportBloc, ReportState>(
        listener: _handleBlocStateChanges,
        child: RefreshIndicator(
          onRefresh: () async {
            _loadComments();
            await Future.delayed(const Duration(milliseconds: 300));
          },
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReportHeader(),
                _buildReportImage(),
                _buildReportContent(),
                _buildCommentsSection(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleBlocStateChanges(BuildContext context, ReportState state) {
    if (state is CommentsLoaded && state.reportId == widget.report.id) {
      _cachedComments = state.comments;
      setState(() => _isSubmitting = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } else if (state is CommentAdded && state.reportId == widget.report.id) {
      _commentController.clear();
      _showSnackBar('Comment added successfully!', Colors.green);
      setState(() => _isSubmitting = false);

      _loadComments();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } else if (state is CommentDeleted) {
      _showSnackBar('Comment deleted successfully!', Colors.green);
      context.read<ReportBloc>().add(FetchComments(widget.report.id));
    } else if (state is PointsAwarded) {
      _showSnackBar(
        '🎉 You earned ${state.pointsAwarded} points for resolving this report!',
        Colors.green,
        duration: 3,
      );
    } else if (state is ReportSuccess) {
      _showSnackBar(state.message, Colors.green);
    } else if (state is ReportError) {
      _showSnackBar('Error: ${state.message}', Colors.red);
      setState(() => _isSubmitting = false);
    } else if (state is CommentsError && state.reportId == widget.report.id) {
      _showSnackBar('Failed to load comments: ${state.message}', Colors.red);
      setState(() => _isSubmitting = false);
    } else if (state is CommentError) {
      _showSnackBar('Comment error: ${state.message}', Colors.red);
      setState(() => _isSubmitting = false);
    } else if (state is CommentAdding && state.reportId == widget.report.id) {
      setState(() => _isSubmitting = true);
    }
  }

  void _showSnackBar(String message, Color backgroundColor, {int duration = 2}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          duration: Duration(seconds: duration),
        ),
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildReportHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue.shade100,
            child: Text(
              widget.report.userId.isNotEmpty ? widget.report.userId[0].toUpperCase() : 'U',
              style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.report.username.isNotEmpty
                      ? widget.report.username
                      : "User ${widget.report.userId.length > 8 ? widget.report.userId.substring(0, 8) : widget.report.userId}...",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  _formatDate(widget.report.createdAt),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getStatusColor(widget.report.status),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              widget.report.status,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportImage() {
    if (widget.report.imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      height: 250,
      child: CachedNetworkImage(
        imageUrl: widget.report.imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          height: 250,
          color: Colors.grey.shade200,
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          height: 250,
          color: Colors.grey.shade200,
          child: const Center(
            child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildReportContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.report.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            widget.report.description,
            style: TextStyle(color: Colors.grey.shade700, height: 1.5, fontSize: 16),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Icon(Icons.location_on, size: 18, color: Colors.red.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.report.location,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Icon(Icons.favorite, size: 18, color: Colors.red.shade400),
              const SizedBox(width: 4),
              Text(
                '${widget.report.likesCount} likes',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              const SizedBox(width: 24),
              Icon(Icons.comment, size: 18, color: Colors.blue.shade400),
              const SizedBox(width: 4),
              BlocBuilder<ReportBloc, ReportState>(
                builder: (context, state) {
                  int commentCount = widget.report.commentsCount;
                  if (state is CommentsLoaded && state.reportId == widget.report.id) {
                    commentCount = state.comments.length;
                  } else if (_cachedComments.isNotEmpty) {
                    commentCount = _cachedComments.length;
                  }
                  return Text(
                    '$commentCount comments',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  "Comments",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const Spacer(),
                BlocBuilder<ReportBloc, ReportState>(
                  builder: (context, state) {
                    if (state is CommentsLoading && state.reportId == widget.report.id) {
                      return const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
          _buildCommentsList(),
          if (!widget.readOnlyComments && _currentUserId != null) _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildCommentsList() {
    return BlocBuilder<ReportBloc, ReportState>(
      builder: (context, state) {
        List<CommentModel> commentsToShow = [];

        if (state is CommentsLoaded && state.reportId == widget.report.id) {
          commentsToShow = state.comments;
        } else if (_cachedComments.isNotEmpty) {
          // Use cached comments while loading
          commentsToShow = _cachedComments;
        } else if (state is CommentsLoading && state.reportId == widget.report.id) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (state is CommentsError && state.reportId == widget.report.id) {
          return _buildCommentsError(state.message);
        }

        if (commentsToShow.isEmpty) {
          return _buildEmptyComments();
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: commentsToShow.length,
          itemBuilder: (context, index) => _buildCommentItem(commentsToShow[index]),
        );
      },
    );
  }

  Widget _buildEmptyComments() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            "No comments yet",
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Be the first to comment!",
            style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsError(String message) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            "Failed to load comments",
            style: TextStyle(
              color: Colors.red.shade600,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadComments,
            icon: const Icon(Icons.refresh),
            label: const Text("Retry"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(CommentModel comment) {
    final isOwner = comment.userId == _currentUserId;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isOwner ? Colors.blue.shade600 : Colors.blue.shade200,
            child: Text(
              comment.userName.isNotEmpty ? comment.userName[0].toUpperCase() : "U",
              style: TextStyle(
                color: isOwner ? Colors.white : Colors.blue.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.userName.isNotEmpty ? comment.userName : "Anonymous User",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    if (isOwner) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "You",
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(comment.content, style: const TextStyle(fontSize: 14, height: 1.4)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      _formatDate(comment.createdAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    if (isOwner) ...[
                      const Spacer(),
                      InkWell(
                        onTap: () => _showDeleteCommentDialog(comment),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade400),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              enabled: !_isSubmitting,
              decoration: InputDecoration(
                hintText: _isSubmitting ? "Posting comment..." : "Add a comment...",
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                suffixIcon: _isSubmitting
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: _isSubmitting ? null : (value) => _submitComment(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isSubmitting ? null : _submitComment,
            icon: Icon(
              Icons.send,
              color: _isSubmitting ? Colors.grey : Colors.blue.shade600,
            ),
          ),
        ],
      ),
    );
  }

  void _submitComment() {
    final content = _commentController.text.trim();
    if (content.isEmpty) {
      _showSnackBar('Please enter a comment', Colors.orange);
      return;
    }

    if (_currentUserId == null) {
      _showSnackBar('Please log in to comment', Colors.red);
      return;
    }

    // OPTIMISTIC: Add comment to UI immediately
    setState(() => _isSubmitting = true);

    context.read<ReportBloc>().add(AddComment(
          reportId: widget.report.id,
          content: content,
        ));

    FocusScope.of(context).unfocus();
  }

  void _showDeleteCommentDialog(CommentModel comment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ReportBloc>().add(DeleteComment(comment.id));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 0) return "${diff.inDays}d ago";
    if (diff.inHours > 0) return "${diff.inHours}h ago";
    if (diff.inMinutes > 0) return "${diff.inMinutes}m ago";
    return "Just now";
  }
}