class UserPoints {
  final String userId;
  final String username;
  final int totalPoints;
  final int rank;
  final String? avatarUrl;
  final DateTime? lastUpdated;

  UserPoints({
    required this.userId,
    required this.username,
    required this.totalPoints,
    required this.rank,
    this.avatarUrl,
    this.lastUpdated,
  });

  factory UserPoints.fromJson(Map<String, dynamic> json) {
    return UserPoints(
      userId: json['user_id']?.toString() ?? '',
      username: json['username']?.toString() ?? 'Unknown User',
      totalPoints: json['total_points']?.toInt() ?? 0,
      rank: json['rank']?.toInt() ?? 0,
      avatarUrl: json['avatar_url']?.toString(),
      lastUpdated: json['last_updated'] != null
          ? DateTime.tryParse(json['last_updated'].toString())
          : null,
    );
  }

  factory UserPoints.fromMap(Map<String, dynamic> data) {
    return UserPoints.fromJson(data);
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'total_points': totalPoints,
      'rank': rank,
      'avatar_url': avatarUrl,
      'last_updated': lastUpdated?.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() => toJson();

  UserPoints copyWith({
    String? userId,
    String? username,
    int? totalPoints,
    int? rank,
    String? avatarUrl,
    DateTime? lastUpdated,
  }) {
    return UserPoints(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      totalPoints: totalPoints ?? this.totalPoints,
      rank: rank ?? this.rank,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  String toString() {
    return 'UserPoints(userId: $userId, username: $username, totalPoints: $totalPoints, rank: $rank)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserPoints &&
        other.userId == userId &&
        other.username == username &&
        other.totalPoints == totalPoints &&
        other.rank == rank &&
        other.avatarUrl == avatarUrl &&
        other.lastUpdated == lastUpdated;
  }

  @override
  int get hashCode {
    return userId.hashCode ^
    username.hashCode ^
    totalPoints.hashCode ^
    rank.hashCode ^
    (avatarUrl?.hashCode ?? 0) ^
    (lastUpdated?.hashCode ?? 0);
  }
}