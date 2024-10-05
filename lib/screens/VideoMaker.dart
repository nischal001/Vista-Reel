import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

class VideoImageMerger extends StatefulWidget {
  @override
  _VideoImageMergerState createState() => _VideoImageMergerState();
}

class _VideoImageMergerState extends State<VideoImageMerger> {
  File? _imageFile;
  File? _videoFile;
  final picker = ImagePicker();
  String? _outputPath;
  bool _isMerging = false;
  String _statusMessage = '';
  VideoPlayerController? _videoPlayerController;

  @override
  void initState() {
    super.initState();
    requestStoragePermission();
  }

  Future<void> requestStoragePermission() async {
    if (await Permission.storage.isDenied) {
      await Permission.storage.request();
    }
    if (await Permission.manageExternalStorage.isDenied) {
      await Permission.manageExternalStorage.request();
    }
  }

  Future<void> pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      if (pickedFile != null) {
        _imageFile = File(pickedFile.path);
        _statusMessage = 'Image selected';
      } else {
        _statusMessage = 'Image selection cancelled';
      }
    });
  }

  Future<void> pickVideo() async {
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
    setState(() {
      if (pickedFile != null) {
        _videoFile = File(pickedFile.path);
        _statusMessage = 'Video selected';
      } else {
        _statusMessage = 'Video selection cancelled';
      }
    });
  }

  Future<void> createImageVideo() async {
    if (_imageFile == null) {
      setState(() {
        _statusMessage = 'Please select an image.';
      });
      return;
    }

    // Get the directory to store the video
    Directory appDocDir =
        await getExternalStorageDirectory() ?? await getTemporaryDirectory();
    String appDocPath = appDocDir.path;

    // Create the folder if it doesn't exist
    Directory outputDir = Directory('$appDocPath/my_folder');
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    String imagePath = 'file:${_imageFile!.path}';
    String imageVideoPath = '${outputDir.path}/image_clip.mp4';

    final imageVideoFile = File(imageVideoPath);
    if (imageVideoFile.existsSync()) {
      imageVideoFile.deleteSync();
    }

    // FFmpeg command to create the video from the image
    String createImageVideoCommand =
        "-loop 1 -i '$imagePath' -t 3 -vf scale=1280:720 -pix_fmt yuv420p -r 25 -y '$imageVideoPath'";

    final session = await FFmpegKit.execute(createImageVideoCommand);
    final returnCode = await session.getReturnCode();
    final log = await session.getLogs();

    if (returnCode!.isValueSuccess()) {
      setState(() {
        _statusMessage = 'Image video created successfully at $imageVideoPath';
      });
    } else {
      setState(() {
        _statusMessage = 'Failed to create image video';
      });
      log.forEach((logEntry) {
        print(logEntry.getMessage());
      });
    }
  }

  Future<void> mergeVideoWithImage() async {
    if (_videoFile == null || _imageFile == null) {
      setState(() {
        _statusMessage = 'Please select both video and image.';
      });
      return;
    }

    String videoPath = 'file:${_videoFile!.path}';
    String imagePath = 'file:${_imageFile!.path}';
    String outputPath = '/storage/emulated/0/my_folder/output_video.mp4';

    setState(() {
      _isMerging = true;
      _statusMessage = 'Merging image with video...';
    });

    // Modify the FFmpeg command to overlay the image on the video for the first 3 seconds, then show the rest of the video
    String mergeCommand =
        "-i '$videoPath' -i '$imagePath' -filter_complex \"[0:v]scale=1280:720[video]; [1:v]scale=1280:720[image]; [video][image]overlay=(main_w-overlay_w)/2:(main_h-overlay_h)/2:enable='between(t,4,10)'\" -c:a copy -y '$outputPath'";

    final session = await FFmpegKit.execute(mergeCommand);
    final returnCode = await session.getReturnCode();
    final log = await session.getLogs();

    if (returnCode!.isValueSuccess()) {
      setState(() {
        _isMerging = false;
        _outputPath = outputPath;
        _statusMessage = 'Video merged successfully at $outputPath';
      });
      await playMergedVideo();
    } else {
      setState(() {
        _isMerging = false;
        _statusMessage = 'Failed to merge video';
      });
      log.forEach((logEntry) {
        print(logEntry.getMessage());
      });
    }
  }

  Future<void> playMergedVideo() async {
    _videoPlayerController = VideoPlayerController.file(
      File('storage/emulated/0/my_folder/output_video.mp4'),
    );
    await _videoPlayerController!.initialize();
    _videoPlayerController!.play();
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Merge Video and Image'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: pickVideo,
              child: Text('Pick Video'),
            ),
            ElevatedButton(
              onPressed: pickImage,
              child: Text('Pick Image'),
            ),
            if (_statusMessage.isNotEmpty) Text(_statusMessage),
            _isMerging
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: mergeVideoWithImage,
                    child: Text('Merge Video and Image with Transition'),
                  ),
            if (_outputPath != null && _videoPlayerController != null)
              _videoPlayerController!.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: _videoPlayerController!.value.aspectRatio,
                      child: VideoPlayer(_videoPlayerController!),
                    )
                  : Text("Loading video..."),
          ],
        ),
      ),
    );
  }
}
