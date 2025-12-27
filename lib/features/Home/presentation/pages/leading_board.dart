import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../Repository/model/user_point_model.dart';
import '../../../Report/presentation/bloc/report_bloc.dart';
import 'package:flutter/material.dart' hide ErrorWidget;
import '../../../Report/presentation/bloc/report_event.dart';
import '../../../Report/presentation/bloc/report_state.dart';
import '../../../../common/widgets/network_error_widget.dart';
import '../../../../common/services/network_service.dart';
import 'dart:async';

class LeaderboardWidget extends StatefulWidget {
  const LeaderboardWidget({super.key});

  @override
  State<LeaderboardWidget> createState() => _LeaderboardWidgetState();
}

class _LeaderboardWidgetState extends State<LeaderboardWidget> {
  Timer? _autoRefreshTimer;
  List<UserPoints> _cachedLeaderboard = [];

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
    // OPTIMIZED: Auto-refresh every 30 seconds instead of on every action
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _loadLeaderboard() {
    context.read<ReportBloc>().add(const FetchLeaderboard());
  }

  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadLeaderboard();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Leaderboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.indigo[600],
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLeaderboard,
          ),
        ],
      ),
      body: BlocConsumer<ReportBloc, ReportState>(
        listener: (context, state) {
          if (state is PointsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${state.message}'),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is PointsAwarded) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('🎉 +${state.pointsAwarded} points awarded!'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
            // OPTIMIZED: Small delay before refresh
            Future.delayed(const Duration(milliseconds: 500), _loadLeaderboard);
          } else if (state is LeaderboardLoaded) {
            _cachedLeaderboard = state.leaderboard;
          }
        },
        builder: (context, state) {
          if (state is PointsLoading && _cachedLeaderboard.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is LeaderboardLoaded) {
            return RefreshIndicator(
              onRefresh: () async {
                _loadLeaderboard();
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: _buildLeaderboardContent(state.leaderboard),
            );
          } else if (_cachedLeaderboard.isNotEmpty) {
            // Show cached data while loading
            return RefreshIndicator(
              onRefresh: () async {
                _loadLeaderboard();
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: _buildLeaderboardContent(_cachedLeaderboard),
            );
          } else if (state is PointsError) {
            final isNetworkError = NetworkService.isNetworkError(state.message);
            return isNetworkError
                ? NetworkErrorWidget(onRetry: _loadLeaderboard)
                : ErrorWidget(message: state.message, onRetry: _loadLeaderboard);
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildLeaderboardContent(List<UserPoints> leaderboard) {
    if (leaderboard.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "No rankings yet",
              style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              "Start resolving reports to see the leaderboard!",
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadLeaderboard,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    // Sort by total points descending
    final sortedLeaderboard = List<UserPoints>.from(leaderboard)
      ..sort((a, b) => b.totalPoints.compareTo(a.totalPoints));

    return Column(
      children: [
        // Top 3 podium section
        if (sortedLeaderboard.length >= 3)
          Container(
            constraints: BoxConstraints(
              minHeight: 200,
              maxHeight: MediaQuery.of(context).size.height * 0.35,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo[600]!, Colors.indigo[400]!],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: _buildPodium(sortedLeaderboard.take(3).toList()),
          ),

        // Stats header
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard('Total Users', sortedLeaderboard.length.toString(), Icons.people),
              _buildStatCard(
                'Top Score',
                sortedLeaderboard.isNotEmpty ? '${sortedLeaderboard.first.totalPoints}' : '0',
                Icons.star,
              ),
            ],
          ),
        ),

        // Rest of the leaderboard
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedLeaderboard.length,
              itemBuilder: (context, index) {
                final userPoints = sortedLeaderboard[index];
                final rank = index + 1;
                return _buildLeaderboardItem(userPoints, rank);
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.indigo[600], size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodium(List<UserPoints> top3) {
    if (top3.length < 3) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildPodiumPlace(top3[1], 2, 80, Colors.grey[300]!),
          _buildPodiumPlace(top3[0], 1, 100, Colors.amber[300]!),
          _buildPodiumPlace(top3[2], 3, 60, Colors.orange[300]!),
        ],
      ),
    );
  }

  Widget _buildPodiumPlace(UserPoints userPoints, int rank, double height, Color color) {
    final displayName = userPoints.username.isNotEmpty
        ? userPoints.username
        : (userPoints.userId.length > 5 ? userPoints.userId.substring(0, 5) : userPoints.userId);

    IconData medalIcon;
    Color medalColor;
    switch (rank) {
      case 1:
        medalIcon = Icons.emoji_events;
        medalColor = Colors.amber;
        break;
      case 2:
        medalIcon = Icons.emoji_events;
        medalColor = Colors.grey[400]!;
        break;
      case 3:
        medalIcon = Icons.emoji_events;
        medalColor = Colors.orange[300]!;
        break;
      default:
        medalIcon = Icons.emoji_events;
        medalColor = Colors.grey;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Medal icon
        Icon(medalIcon, color: medalColor, size: rank == 1 ? 32 : 24),
        const SizedBox(height: 4),
        // Avatar
        Container(
          width: rank == 1 ? 60 : 50,
          height: rank == 1 ? 60 : 50,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: rank == 1 ? Colors.amber : Colors.grey[300]!,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
              style: TextStyle(
                fontSize: rank == 1 ? 24 : 20,
                fontWeight: FontWeight.bold,
                color: Colors.indigo[600],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Name
        SizedBox(
          width: 80,
          child: Text(
            displayName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Points
        Text(
          "${userPoints.totalPoints} pts",
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        // Podium base
        Container(
          width: 70,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              rank.toString(),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardItem(UserPoints userPoints, int rank) {
    final displayName = userPoints.username.isNotEmpty
        ? userPoints.username
        : (userPoints.userId.length > 10 ? userPoints.userId.substring(0, 10) : userPoints.userId);

    final isTopThree = rank <= 3;
    final rankColor = isTopThree ? Colors.amber[700] : Colors.indigo[600];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isTopThree ? Colors.amber[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTopThree ? Colors.amber[200]! : Colors.grey[200]!,
        ),
        boxShadow: isTopThree
            ? [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isTopThree ? Colors.amber[100] : Colors.indigo[100],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                rank.toString(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: rankColor,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Center(
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo[600],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Name and details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Rank #$rank',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Score
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isTopThree ? Colors.amber[600] : Colors.indigo[600],
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (isTopThree ? Colors.amber : Colors.indigo).withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              "${userPoints.totalPoints}",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}