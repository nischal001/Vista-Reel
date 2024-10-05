import 'dart:io';
import 'dart:typed_data';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:math';

class MediaMerger extends StatefulWidget {
  @override
  _MediaMergerState createState() => _MediaMergerState();
}

class _MediaMergerState extends State<MediaMerger> {
  List<File?> _selectedMedia = [];
  int? selectedBoxIndex;
  List<double> _durations = [
    2.5,
    1.5,
    3,
    2.5,
  ]; // Duration for each image in seconds

  _MediaMergerState() {
    _initializeSelectedMedia();
  }

  void _initializeSelectedMedia() {
    _selectedMedia = List.generate(_durations.length, (_) => null);
  }

  String _statusMessage = ''; // Status Messsage
  String? _outputPath; //Output Path
  bool _isMerging = false; // Status Message
  double _progress = 0.0; // Progress value

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

  void _selectBox(int index) {
    setState(() {
      selectedBoxIndex = index;
    });
  }

  void _pickImage(File image) {
    if (selectedBoxIndex != null) {
      setState(() {
        _selectedMedia[selectedBoxIndex!] = image;
      });
    }
  }

  void _handlePickerImageSelection(File image) {
    _pickImage(image);
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

  Future<void> mergeMediaIntoVideo() async {
    const int outputWidth = 1280;
    const int outputHeight = 720;
    const int frameRate = 30; // Set your desired frame rate
    const double transitionDuration = 0.5;

    if (_selectedMedia.any((media) => media == null)) {
      setState(() {
        _statusMessage = 'Please select all media files.';
      });
      return;
    }

    Directory appDocDir = Directory('/storage/emulated/0/VistaReels');
    if (!await appDocDir.exists()) {
      await appDocDir.create(recursive: true);
    }

    String outputPath = '${appDocDir.path}/merged_media.mp4';

    String audioAssetPath = 'assets/audio/2.mp3';
    String audioPath = '${appDocDir.path}/2.mp3'; // Path to copy the audio file

    ByteData data = await rootBundle.load(audioAssetPath);
    List<int> bytes = data.buffer.asUint8List();
    File audioFile = File(audioPath);
    await audioFile.writeAsBytes(bytes);

    String ffmpegCommand = '';
    for (int i = 0; i < _selectedMedia.length; i++) {
      String mediaPath = 'file:${_selectedMedia[i]!.path}';
      double duration = _durations[i];

      // Add different command based on whether it's an image or video
      if (await _getMimeType(_selectedMedia[i]!.path) == 'image') {
        ffmpegCommand += "-loop 1 -t $duration -i '$mediaPath' ";
      } else {
        ffmpegCommand += "-i '$mediaPath' "; // Just read the video input
      }
    }

    ffmpegCommand += "-i '$audioPath' "; // Add audio input

    double totalDuration = _durations.reduce((a, b) => a + b);

    String filterComplex = '';
    List<String> inputs = [];

    for (int i = 0; i < _selectedMedia.length; i++) {
      String inputLabel = "[$i:v]";
      String outputLabel = "[v$i]";

      if (await _getMimeType(_selectedMedia[i]!.path) == 'image') {
        filterComplex +=
            "${inputLabel}loop=loop=-1:size=1:start=0,setpts=PTS-STARTPTS[img$i]; " +
                "[img$i]scale=$outputWidth:$outputHeight:force_original_aspect_ratio=decrease," +
                "pad=$outputWidth:$outputHeight:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=$frameRate";
      } else {
        filterComplex +=
            "${inputLabel}scale=$outputWidth:$outputHeight:force_original_aspect_ratio=decrease," +
                "pad=$outputWidth:$outputHeight:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=$frameRate";
      }

      filterComplex += ",trim=duration=${_durations[i]}$outputLabel; ";

      inputs.add(outputLabel);
      totalDuration += _durations[i];
    }

    // Apply cross-fade transitions
    String xfadeComplex = '';
    for (int i = 1; i < _selectedMedia.length; i++) {
      String prevOutput = i == 1 ? "[v0]" : "[xf${i - 1}]";
      xfadeComplex +=
          "${prevOutput}[v$i]xfade=transition=wipeleft:duration=$transitionDuration:offset=${_durations[i - 1] - transitionDuration}[xf$i]; ";
    }

    // Concatenate all clips with transitions
    filterComplex += xfadeComplex;
    String finalOutput =
        _selectedMedia.length > 1 ? "[xf${_selectedMedia.length - 1}]" : "[v0]";
    filterComplex += "${finalOutput}format=yuv420p[outv]; ";

    // Process audio
    filterComplex +=
        "[${_selectedMedia.length}:a]atrim=0:$totalDuration,asetpts=N/SR/TB[aout]";

    String fullCommand = "$ffmpegCommand "
        "-filter_complex \"$filterComplex\" "
        "-map \"[outv]\" -map \"[aout]\" -b:v 5000k -y '$outputPath'";

    print("FFmpeg Command: $fullCommand");

    setState(() {
      _isMerging = true;
      _statusMessage = 'Merging media into video...';
      _progress = 0.0; // Reset progress
    });

    FFmpegKitConfig.enableLogCallback((log) {
      String message = log.getMessage();
      RegExp regExp = RegExp(r'time=\s*([0-9:.]+)');
      Match? match = regExp.firstMatch(message);
      if (match != null) {
        String timeStr = match.group(1)!;
        double progressTime = _parseTimeToSeconds(timeStr);
        double totalTime = totalDuration; // Use the calculated total duration
        setState(() {
          _progress = progressTime / totalTime;
        });
      }
    });

    final session = await FFmpegKit.execute(fullCommand);
    final returnCode = await session.getReturnCode();
    final log = await session.getLogs();

    if (returnCode!.isValueSuccess()) {
      setState(() {
        _isMerging = false;
        _outputPath = outputPath;
        _statusMessage = 'Media merged successfully into video at $outputPath';
        _progress = 1.0; // Merging complete
      });
    } else {
      setState(() {
        _isMerging = false;
        _statusMessage = 'Failed to merge media';
      });
      log.forEach((logEntry) {
        print(logEntry.getMessage());
      });
    }
  }

// Example function to validate media files
  Future<bool> _isMediaFileValid(String mediaPath) async {
    // Implement logic to check if the media file exists and has sufficient duration
    return true; // Replace this with actual validation
  }

  void _trackProgress() {
    FFmpegKitConfig.enableLogCallback((log) {
      String message = log.getMessage();
      RegExp regExp = RegExp(r'time=\s*([0-9:.]+)');
      Match? match = regExp.firstMatch(message);
      if (match != null) {
        // Extract the timestamp and calculate progress
        String timeStr = match.group(1)!;
        double progressTime = _parseTimeToSeconds(timeStr);
        double totalTime = _durations.reduce((a, b) => a + b) +
            _selectedMedia.length; // Add transition duration
        setState(() {
          _progress = progressTime / totalTime;
        });
      }
    });
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
                  onImageSelected: _handlePickerImageSelection),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_durations.length, (index) {
                final isSelected = selectedBoxIndex == index;
                return Column(
                  children: [
                    GestureDetector(
                      onTap: () => _selectBox(index), // Set the selected box
                      child: Container(
                        margin: EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Colors.green
                                : Colors
                                    .transparent, // Change border color based on selection
                            width: isSelected
                                ? 3.0
                                : 1.0, // Change border width based on selection
                          ),
                        ),
                        height: 150,
                        width: 100,
                        child: _selectedMedia[index] != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  _selectedMedia[index]!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Center(child: Text('Pick Media ${index + 1}')),
                      ),
                    ),
                    Text(
                      '${_durations[index].toString()} secs',
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
              ? Column(
                  children: [
                    LinearProgressIndicator(
                      value: _progress,
                      color: Colors.green,
                    ),
                    Text(
                      '${(_progress * 100).toStringAsFixed(0)}% completed',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                      ),
                    ),
                  ],
                )
              : Container(),
        ],
      ),
    );
  }
}

class CustomMediaPicker extends StatefulWidget {
  final Function(File) onImageSelected;

  const CustomMediaPicker({Key? key, required this.onImageSelected})
      : super(key: key);

  @override
  _CustomMediaPickerState createState() => _CustomMediaPickerState();
}

class _CustomMediaPickerState extends State<CustomMediaPicker> {
  List<AssetEntity> _mediaList = [];
  bool _isLoading = true;
  bool _hasPermission = true;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    final PermissionState permission =
        await PhotoManager.requestPermissionExtend();

    if (permission.isAuth) {
      List<AssetPathEntity> albums =
          await PhotoManager.getAssetPathList(type: RequestType.common);

      if (albums.isNotEmpty) {
        List<AssetEntity> media =
            await albums[0].getAssetListPaged(page: 0, size: 50);
        setState(() {
          _mediaList = media;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No media found')),
        );
      }
    } else {
      setState(() {
        _isLoading = false;
        _hasPermission = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : !_hasPermission
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Permission denied'),
                    ElevatedButton(
                      onPressed: () {
                        PhotoManager.openSetting();
                      },
                      child: const Text('Open Settings'),
                    ),
                  ],
                ),
              )
            : _mediaList.isEmpty
                ? const Center(child: Text('No media found'))
                : Column(
                    children: [
                      Expanded(
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 4,
                            mainAxisSpacing: 4,
                          ),
                          itemCount: _mediaList.length,
                          itemBuilder: (context, index) {
                            return FutureBuilder<Uint8List?>(
                              future: _mediaList[index].thumbnailData,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                        ConnectionState.done &&
                                    snapshot.hasData) {
                                  return GestureDetector(
                                    onTap: () async {
                                      final AssetEntity entity =
                                          _mediaList[index];
                                      final file = await entity.file;
                                      if (file != null) {
                                        widget.onImageSelected(file);
                                      }
                                    },
                                    child: Image.memory(
                                      snapshot.data!,
                                      fit: BoxFit.cover,
                                    ),
                                  );
                                }
                                return Container(
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  );
  }
}
