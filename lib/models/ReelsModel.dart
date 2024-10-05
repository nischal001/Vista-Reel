class ReelsModel {
  final String reelId;
  final String userId;
  final String videoUrl;

  final int likes;

  ReelsModel(
      {required this.reelId,
      required this.userId,
      required this.videoUrl,
      required this.likes});

  factory ReelsModel.fromMap(Map<String, dynamic> data) {
    return ReelsModel(
      reelId: data['reelId'] ?? '',
      userId: data['userId'] ?? '',
      videoUrl: data['videoUrl'] ?? '',
      likes: data['likes'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reelId': reelId,
      'userId': userId,
      'videoUrl': videoUrl,
      'likes': likes,
    };
  }
}
