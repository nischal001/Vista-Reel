import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart'; // Add this package

// Add these methods to your _MediaMergerState class:

class VideoUtils {
  Future<bool> isVideo(File file) async {
    String path = file.path.toLowerCase();
    return path.endsWith('.mp4') ||
        path.endsWith('.mov') ||
        path.endsWith('.avi') ||
        path.endsWith('.wmv');
  }

  Future<String?> generateVideoThumbnail(String videoPath) async {
    try {
      final thumbnail = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 150,
        quality: 75,
      );
      return thumbnail;
    } catch (e) {
      print('Error generating thumbnail: $e');
      return null;
    }
  }

  Future<Duration?> getVideoDuration(String videoPath) async {
    try {
      final controller = VideoPlayerController.file(File(videoPath));
      await controller.initialize();
      final duration = controller.value.duration;
      await controller.dispose();
      return duration;
    } catch (e) {
      print('Error getting video duration: $e');
      return null;
    }
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
