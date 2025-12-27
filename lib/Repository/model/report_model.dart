class ReportModel {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String contact;
  final String location;
  final String coords;
  final String timestamp;
  final String imageUrl;
  final String resolvedImageUrl;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;
  final String username;

  ReportModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.contact,
    required this.location,
    required this.coords,
    required this.timestamp,
    required this.imageUrl,
    this.resolvedImageUrl = '',
    required this.status,
    required this.createdAt,
    this.updatedAt,
    required this.likesCount,
    required this.commentsCount,
    required this.isLiked,
    required this.username,
  });

  factory ReportModel.fromMap(Map<String, dynamic> data) {
    return ReportModel(
      id: data['id'].toString(),
      userId: data['user_id']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      contact: data['contact']?.toString() ?? '',
      location: data['location']?.toString() ?? '',
      coords: data['coords']?.toString() ?? '',
      timestamp: data['timestamp']?.toString() ?? '',
      imageUrl: data['image_url']?.toString() ?? '',
      resolvedImageUrl: data['resolved_photo']?.toString() ?? '',
      status: data['status']?.toString() ?? 'Pending',
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: data['updated_at'] != null
          ? DateTime.tryParse(data['updated_at'].toString())
          : null,
      likesCount: (data['likes_count'] as num?)?.toInt() ?? 0,
      commentsCount: (data['comments_count'] as num?)?.toInt() ?? 0,
      isLiked: data['is_liked'] == true,
      username: data['username']?.toString() ?? 'Anonymous',
    );
  }

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel.fromMap(json);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'contact': contact,
      'location': location,
      'coords': coords,
      'timestamp': timestamp,
      'image_url': imageUrl,
      'resolved_image_url': resolvedImageUrl,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'is_liked': isLiked,
      'username': username,
    };
  }

  Map<String, dynamic> toJson() => toMap();

  ReportModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    String? contact,
    String? location,
    String? coords,
    String? timestamp,
    String? imageUrl,
    String? resolvedImageUrl,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? likesCount,
    int? commentsCount,
    bool? isLiked,
    String? username,
  }) {
    return ReportModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      contact: contact ?? this.contact,
      location: location ?? this.location,
      coords: coords ?? this.coords,
      timestamp: timestamp ?? this.timestamp,
      imageUrl: imageUrl ?? this.imageUrl,
      resolvedImageUrl: resolvedImageUrl ?? this.resolvedImageUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLiked: isLiked ?? this.isLiked,
      username: username ?? this.username,
    );
  }

  @override
  String toString() {
    return 'ReportModel(id: $id, userId: $userId, title: $title, description: $description, contact: $contact, location: $location, coords: $coords, timestamp: $timestamp, imageUrl: $imageUrl, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, likesCount: $likesCount, commentsCount: $commentsCount, isLiked: $isLiked, username: $username)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReportModel &&
        other.id == id &&
        other.userId == userId &&
        other.title == title &&
        other.description == description &&
        other.contact == contact &&
        other.location == location &&
        other.coords == coords &&
        other.timestamp == timestamp &&
        other.imageUrl == imageUrl &&
        other.status == status &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.likesCount == likesCount &&
        other.commentsCount == commentsCount &&
        other.isLiked == isLiked &&
        other.username == username;
  }

  @override
  int get hashCode {
    return id.hashCode ^
    userId.hashCode ^
    title.hashCode ^
    description.hashCode ^
    contact.hashCode ^
    location.hashCode ^
    coords.hashCode ^
    timestamp.hashCode ^
    imageUrl.hashCode ^
    status.hashCode ^
    createdAt.hashCode ^
    updatedAt.hashCode ^
    likesCount.hashCode ^
    commentsCount.hashCode ^
    isLiked.hashCode ^
    username.hashCode;
  }
}

class EnhancedReportModel extends ReportModel {
  final bool pointsAwarded;

  EnhancedReportModel({
    required super.id,
    required super.userId,
    required super.title,
    required super.description,
    required super.contact,
    required super.location,
    required super.coords,
    required super.timestamp,
    required super.imageUrl,
    required super.status,
    required super.createdAt,
    super.updatedAt,
    required super.likesCount,
    required super.commentsCount,
    required super.isLiked,
    required super.username,
    this.pointsAwarded = false,
  });

  factory EnhancedReportModel.fromMap(Map<String, dynamic> data) {
    return EnhancedReportModel(
      id: data['id'].toString(),
      userId: data['user_id']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      contact: data['contact']?.toString() ?? '',
      location: data['location']?.toString() ?? '',
      coords: data['coords']?.toString() ?? '',
      timestamp: data['timestamp']?.toString() ?? '',
      imageUrl: data['image_url']?.toString() ?? '',
      status: data['status']?.toString() ?? 'Pending',
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: data['updated_at'] != null
          ? DateTime.tryParse(data['updated_at'].toString())
          : null,
      likesCount: (data['likes_count'] as num?)?.toInt() ?? 0,
      commentsCount: (data['comments_count'] as num?)?.toInt() ?? 0,
      isLiked: data['is_liked'] == true,
      username: data['username']?.toString() ?? 'Anonymous',
      pointsAwarded: data['points_awarded'] == true,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map['points_awarded'] = pointsAwarded;
    return map;
  }

  @override
  EnhancedReportModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    String? contact,
    String? location,
    String? coords,
    String? timestamp,
    String? imageUrl,
    String? resolvedImageUrl,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? likesCount,
    int? commentsCount,
    bool? isLiked,
    String? username,
    bool? pointsAwarded,
  }) {
    return EnhancedReportModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      contact: contact ?? this.contact,
      location: location ?? this.location,
      coords: coords ?? this.coords,
      timestamp: timestamp ?? this.timestamp,
      imageUrl: imageUrl ?? this.imageUrl,
      // resolvedImageUrl is a field on the parent; preserve if unchanged
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLiked: isLiked ?? this.isLiked,
      username: username ?? this.username,
      pointsAwarded: pointsAwarded ?? this.pointsAwarded,
    );
  }
}

