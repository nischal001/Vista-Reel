import 'dart:io';
import 'dart:typed_data';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:math';
import 'package:http/http.dart' as http; // Ensure http package is imported

import 'package:reelsapp/utils/CustomMediaPicker.dart';
import 'package:reelsapp/utils/VideoUtils.dart';

class MediaMerger extends StatefulWidget {
  late List<Map<String, dynamic>> template; // Pass the entire template object

  MediaMerger({Key? key, required this.template}) : super(key: key);

  @override
  _MediaMergerState createState() => _MediaMergerState();
}

class _MediaMergerState extends State<MediaMerger> {
  List<File?> _selectedMedia = [];
  int? selectedBoxIndex;

  // List<Map<String, dynamic>> _durations = [
  //   {
  //     "duration": 2.5,
  //     "hasTransition": "No",
  //     "transitionType": "none",
  //   },
  //   {
  //     "duration": 2.5,
  //     "hasTransition": "Yes",
  //     "transitionType": "pixelize",
  //   },
  //   {
  //     "duration": 3.0,
  //     "hasTransition": "Yes",
  //     "transitionType": "smoothright",
  //   },
  //   {
  //     "duration": 2.0,
  //     "hasTransition": "Yes",
  //     "transitionType": "pixelize",
  //   },
  //   {
  //     "duration": 3.0,
  //     "hasTransition": "No",
  //     "transitionType": "fade",
  //   },
  // ];

  _MediaMergerState() {
    _initializeSelectedMedia();
  }

  void _initializeSelectedMedia() {
    // Initialize selected media based on the number of durations
    // _selectedMedia = List.generate(_durations.length, (_) => null);

    // Initialize durations based on the widget.template
    // _durations = widget.template
    //     .map((template) => {
    //           "duration": template["durations"]
    //               .first["duration"], // Assuming the first duration is used.
    //           "hasTransition": template["durations"].first["hasTransition"],
    //           "transitionType": template["durations"].first["transitionType"],
    //         })
    //     .toList();

    // Optional: Print the template to verify it's correctly received
    // print('Received template: ${widget.template}');
  }

  String _statusMessage = ''; // Status Messsage
  String? _outputPath; //Output Path
  bool _isMerging = false; // Status Message
  double _progress = 0.0; // Progress value

  final ValueNotifier<double> _progressNotifier = ValueNotifier(0.0);

  @override
  void initState() {
    super.initState();

    requestStoragePermission();
    setState(() {
      _selectedMedia =
          List.generate(widget.template[0]['durations'].length, (_) => null);
    });
    print(widget.template);
  }

  @override
  void dispose() {
    _progressNotifier.dispose(); // Dispose the notifier when done
    super.dispose();
  }

  Future<void> requestStoragePermission() async {
    if (await Permission.storage.isDenied) {
      await Permission.storage.request();
    }
    if (await Permission.manageExternalStorage.isDenied) {
      await Permission.manageExternalStorage.request();
    }
  }

  void _selectBox(int index) {
    setState(() {
      selectedBoxIndex = index;
    });
  }

  void _pickImage(File image) {
    int availableIndex = _selectedMedia.indexWhere((media) => media == null);

    if (availableIndex != -1) {
      setState(() {
        _selectedMedia[availableIndex] = image;
      });
    } else {
      setState(() {
        _statusMessage =
            "All media boxes are full. Please merge or remove existing media.";
      });
    }
  }

  void _handlePickerImageSelection(File image) {
    _pickImage(image);
  }

  void _removeMedia(int index) {
    setState(() {
      _selectedMedia[index] = null;
    });
  }

  Future<String> _getMimeType(String filePath) async {
    if (filePath.endsWith('.mp4')) {
      return 'video';
    } else if (filePath.endsWith('.jpg') || filePath.endsWith('.png')) {
      return 'image';
    } else {
      return 'unknown';
    }
  }

  Future<int> _getRotation(String mediaPath) async {
    final process = await Process.run('ffprobe', [
      '-v',
      'error',
      '-select_streams',
      'v:0',
      '-show_entries',
      'stream_tags=rotate',
      '-of',
      'default=noprint_wrappers=1:nokey=1',
      mediaPath
    ]);

    String rotation = process.stdout.trim();
    return int.tryParse(rotation) ?? 0; // Default to 0 if rotation isn't found
  }

  Future<String> _getMediaRotationFilter(String mediaPath, bool isImage) async {
    try {
      // Use FFprobeKit to get media information
      final session = await FFprobeKit.getMediaInformation(mediaPath);
      final information = session.getMediaInformation();

      if (information == null) return '';

      if (isImage) {
        // Special handling for images
        final tags = information.getTags() ?? {};

        // Check for different orientation metadata fields
        final orientation = tags['Orientation'] ??
            tags['orientation'] ??
            tags['ORIENTATION'] ??
            '1'; // Default orientation if not found

        print('Image orientation detected: $orientation for $mediaPath');

        // Convert EXIF orientation to FFmpeg filter
        // EXIF orientation values:
        // 1 = 0° - nothing
        // 3 = 180° rotate left
        // 6 = 90° clockwise
        // 8 = 270° clockwise
        switch (orientation) {
          case '3':
            return 'transpose=2,transpose=2'; // 180 degrees
          case '6':
            return 'transpose=1'; // 90 degrees clockwise
          case '8':
            return 'transpose=2'; // 270 degrees clockwise
          default:
            return ''; // No rotation needed or unknown orientation
        }
      } else {
        // Existing video rotation handling (since it works correctly)
        final streams = information.getStreams() ?? [];
        String? rotation;

        if (streams.isNotEmpty) {
          final streamProperties = streams[0].getAllProperties();
          if (streamProperties!.containsKey('rotation')) {
            rotation = streamProperties['rotation'];
          }
        }

        final rotationDegrees = int.tryParse(rotation ?? '0') ?? 0;
        final normalizedRotation = rotationDegrees % 360;

        print(
            'Video rotation detected: $normalizedRotation degrees for $mediaPath');

        switch (normalizedRotation) {
          case 90:
            return 'transpose=1';
          case 180:
            return 'transpose=2,transpose=2';
          case 270:
          case -90:
            return 'transpose=2';
          default:
            return '';
        }
      }
    } catch (e) {
      print('Error reading media rotation: $e');
      return '';
    }
  }

  Future<void> mergeMediaIntoVideo() async {
    const int outputWidth = 720;
    const int outputHeight = 1280;
    const int frameRate = 60;
    const double transitionDuration = 0.40;

    if (_selectedMedia.any((media) => media == null)) {
      setState(() {
        _statusMessage = 'Please select all media files.';
      });
      return;
    }

    setState(() {
      _statusMessage = '';
      _progressNotifier.value = 0.0;
      _isMerging = true;
    });

    String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    Directory appDocDir = Directory('/storage/emulated/0/VistaReels');
    if (!await appDocDir.exists()) {
      await appDocDir.create(recursive: true);
    }
    String outputPath = '${appDocDir.path}/vistareel_output_$timestamp.mp4';

    setState(() {
      _statusMessage = 'Downloading Audio';
    });
    String audioUrl = widget.template[0]["templateAudio"];
    String httpsAudioUrl = audioUrl;

    final audioResponse = await http.get(Uri.parse(httpsAudioUrl));
    print("Fetching audio from: $httpsAudioUrl");

    if (audioResponse.statusCode == 200) {
      final Uint8List audioBytes = audioResponse.bodyBytes;
      final audioTempDir = await getTemporaryDirectory();
      final audioTempFile =
          File('${audioTempDir.path}/temp_audio_$timestamp.mp3');
      await audioTempFile.writeAsBytes(audioBytes);

      List<String> inputFiles = [];
      List<double> durations = [];
      double totalDuration = 0.0;

      // Prepare input files and calculate durations
      for (int i = 0; i < _selectedMedia.length; i++) {
        String mediaPath = _selectedMedia[i]!.path;
        double duration = widget.template[0]["durations"][i]['duration'];
        durations.add(duration);
        totalDuration += duration;

        if (await _getMimeType(mediaPath) == 'image') {
          inputFiles.add("-loop 1 -t $duration -i '$mediaPath'");
        } else {
          // Add -an flag for videos to mute their audio
          inputFiles.add("-an -i '$mediaPath'");
        }
      }

      inputFiles.add("-i '${audioTempFile.path}'");

      String filterComplex = '';

      // Process each media file with rotation handling
      for (int i = 0; i < _selectedMedia.length; i++) {
        String mediaPath = _selectedMedia[i]!.path;
        bool isImage = await _getMimeType(mediaPath) == 'image';

        // Add rotation detection and correction
        String rotationFilter = '';
        if (!isImage) {
          // For videos, use metadata to auto-rotate
          rotationFilter = ',transpose=dir=2:passthrough=portrait';
        }

        String baseFilters =
            "scale=$outputWidth:$outputHeight:force_original_aspect_ratio=decrease,"
            "pad=$outputWidth:$outputHeight:(ow-iw)/2:(oh-ih)/2";

        String filters = isImage
            ? "$baseFilters,setsar=1,fps=$frameRate"
            : "$baseFilters$rotationFilter,fps=$frameRate,setsar=1";

        filterComplex += "[$i:v]$filters,trim=duration=${durations[i]}[v$i];";
      }

      // Handle transitions and concatenation
      if (_selectedMedia.length > 1) {
        List<String> segments = [];
        String lastOutput = "[v0]";
        double offset = durations[0] - transitionDuration;

        for (int i = 1; i < _selectedMedia.length; i++) {
          String nextOutput =
              (i == _selectedMedia.length - 1) ? "[outv]" : "[x$i]";
          bool hasTransition =
              widget.template[0]["durations"][i]['hasTransition'] == "Yes";
          String transitionType =
              widget.template[0]["durations"][i]['transitionType'];

          if (hasTransition && transitionType != "none") {
            filterComplex +=
                "$lastOutput[v$i]xfade=transition=$transitionType:duration=$transitionDuration:offset=$offset$nextOutput;";
          } else {
            if (segments.isEmpty) {
              segments.add(lastOutput);
            }
            segments.add("[v$i]");

            if (i == _selectedMedia.length - 1) {
              filterComplex +=
                  "${segments.join('')}concat=n=${segments.length}:v=1:a=0[outv];";
            }
          }

          lastOutput = nextOutput;
          offset += durations[i] - (hasTransition ? transitionDuration : 0);
        }
      } else {
        filterComplex += "[v0]copy[outv];";
      }

      if (filterComplex.endsWith(";")) {
        filterComplex = filterComplex.substring(0, filterComplex.length - 1);
      }

      String fullCommand =
          "${inputFiles.join(' ')} -filter_complex \"$filterComplex\" "
          "-map \"[outv]\" -map \"${_selectedMedia.length}:a\" "
          "-metadata:s:v rotate=0 " // Add this line to clear rotation metadata
          "-b:v 5000k -shortest -y '$outputPath'";

      print("FFmpeg Command: $fullCommand");
      setState(() {
        _statusMessage = 'Merging Video';
      });

      // Rest of the code remains the same...
      FFmpegKitConfig.enableLogCallback((log) {
        String message = log.getMessage();
        RegExp regExp = RegExp(r'time=\s*([0-9:.]+)');
        Match? match = regExp.firstMatch(message);
        if (match != null) {
          String timeStr = match.group(1)!;
          double progressTime = _parseTimeToSeconds(timeStr);
          _progressNotifier.value = progressTime / totalDuration;
        }
      });

      final session = await FFmpegKit.execute(fullCommand);
      final returnCode = await session.getReturnCode();
      final log = await session.getLogs();

      setState(() {
        _isMerging = false;
        if (ReturnCode.isSuccess(returnCode)) {
          _outputPath = outputPath;
          _statusMessage =
              'Media merged successfully into video at $outputPath';
          _progressNotifier.value = 1.0;
        } else {
          _statusMessage = 'Failed to merge media';
          _progressNotifier.value = 0.0;
          log.forEach((logEntry) {
            print(logEntry.getMessage());
          });
        }
      });
    } else {
      setState(() {
        _statusMessage = 'Failed to download audio';
        _isMerging = false;
      });
    }
  }

  // Helper function to parse time in hh:mm:ss format to seconds
  double _parseTimeToSeconds(String time) {
    List<String> parts = time.split(':');
    double hours = double.parse(parts[0]);
    double minutes = double.parse(parts[1]);
    double seconds = double.parse(parts[2]);
    return hours * 3600 + minutes * 60 + seconds;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Select Media',
          style: GoogleFonts.poppins(
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              color: Colors.black.withOpacity(0.25),
              child: CustomMediaPicker(
                onImageSelected: _handlePickerImageSelection,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(widget.template[0]['durations'].length,
                  (index) {
                return Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          margin: EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.transparent,
                              width: 1.0,
                            ),
                          ),
                          height: 150,
                          width: 100,
                          child: _selectedMedia[index] != null
                              ? FutureBuilder<bool>(
                                  future: VideoUtils()
                                      .isVideo(_selectedMedia[index]!),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                        ),
                                      );
                                    }

                                    bool isVideo = snapshot.data!;
                                    return Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: isVideo
                                              ? FutureBuilder<String?>(
                                                  future: VideoUtils()
                                                      .generateVideoThumbnail(
                                                          _selectedMedia[index]!
                                                              .path),
                                                  builder:
                                                      (context, thumbSnapshot) {
                                                    if (thumbSnapshot.data ==
                                                        null) {
                                                      return Center(
                                                        child: Icon(
                                                            Icons.error_outline,
                                                            color:
                                                                Colors.white),
                                                      );
                                                    }

                                                    return Image.file(
                                                      File(thumbSnapshot.data!),
                                                      fit: BoxFit.cover,
                                                    );
                                                  },
                                                )
                                              : Image.file(
                                                  _selectedMedia[index]!,
                                                  fit: BoxFit.cover,
                                                ),
                                        ),
                                        if (isVideo)
                                          Positioned(
                                            bottom: 0,
                                            left: 0,
                                            right: 0,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.bottomCenter,
                                                  end: Alignment.topCenter,
                                                  colors: [
                                                    Colors.black
                                                        .withOpacity(0.7),
                                                    Colors.transparent,
                                                  ],
                                                ),
                                              ),
                                              padding: EdgeInsets.all(4),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.play_circle_outline,
                                                    color: Colors.white,
                                                    size: 16,
                                                  ),
                                                  SizedBox(width: 4),
                                                  FutureBuilder<Duration?>(
                                                    future: VideoUtils()
                                                        .getVideoDuration(
                                                            _selectedMedia[
                                                                    index]!
                                                                .path),
                                                    builder: (context,
                                                        durationSnapshot) {
                                                      if (!durationSnapshot
                                                          .hasData) {
                                                        return SizedBox();
                                                      }
                                                      return Text(
                                                        VideoUtils()
                                                            .formatDuration(
                                                                durationSnapshot
                                                                    .data!),
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12,
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                )
                              : Center(
                                  child: Text(
                                    'Empty ${index + 1}',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white.withOpacity(
                                        0.25,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                        if (_selectedMedia[index] != null)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _removeMedia(index),
                              child: Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      '${widget.template[0]["durations"][index]['duration']} secs',
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                  ],
                );
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: InkWell(
              onTap: mergeMediaIntoVideo,
              child: Container(
                height: 50,
                width: 150,
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'Merge',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_statusMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _statusMessage,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                ),
              ),
            ),
          _isMerging == true
              ? ValueListenableBuilder<double>(
                  valueListenable: _progressNotifier,
                  builder: (context, progress, child) {
                    return Column(
                      children: [
                        LinearProgressIndicator(
                          value: progress,
                          color: Colors.green,
                        ),
                        // Use this to ensure Text updates on progress change
                        AnimatedBuilder(
                          animation: _progressNotifier,
                          builder: (context, _) {
                            return Text(
                              '${(_progressNotifier.value * 100).toStringAsFixed(0)}% completed',
                              style: TextStyle(
                                  color: Colors
                                      .white), // Styling as per your app theme
                            );
                          },
                        ),
                      ],
                    );
                  },
                )
              : Container(),
        ],
      ),
    );
  }
}
