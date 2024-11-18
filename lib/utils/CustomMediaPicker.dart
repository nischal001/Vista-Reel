import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

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
    if (_mediaList.isEmpty) {
      _loadMedia();
    }
  }

  Future<void> _loadMedia() async {
    if (_mediaList.isNotEmpty)
      return; // Skip reloading if media is already loaded

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
        ? const Center(
            child: CircularProgressIndicator(),
          )
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
