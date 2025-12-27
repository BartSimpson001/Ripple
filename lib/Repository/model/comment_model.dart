class CommentModel {
  final String id;
  final String reportId;
  final String userId;
  final String userName;
  final String content;
  final DateTime createdAt;

  CommentModel({
    required this.id,
    required this.reportId,
    required this.userId,
    required this.userName,
    required this.content,
    required this.createdAt,
  });

  factory CommentModel.fromMap(Map<String, dynamic> data) {
    return CommentModel(
      id: data['id'].toString(),
      reportId: data['report_id']?.toString() ?? '',
      userId: data['user_id']?.toString() ?? '',
      userName: data['user_name']?.toString() ?? 'Anonymous',
      content: data['content']?.toString() ?? '',
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel.fromMap(json);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'report_id': reportId,
      'user_id': userId,
      'user_name': userName,
      'content': content,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() => toMap();

  CommentModel copyWith({
    String? id,
    String? reportId,
    String? userId,
    String? userName,
    String? content,
    DateTime? createdAt,
  }) {
    return CommentModel(
      id: id ?? this.id,
      reportId: reportId ?? this.reportId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'CommentModel(id: $id, reportId: $reportId, userId: $userId, userName: $userName, content: $content, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CommentModel &&
        other.id == id &&
        other.reportId == reportId &&
        other.userId == userId &&
        other.userName == userName &&
        other.content == content &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
    reportId.hashCode ^
    userId.hashCode ^
    userName.hashCode ^
    content.hashCode ^
    createdAt.hashCode;
  }
}