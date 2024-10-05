import 'package:flutter/material.dart';
import 'package:reelsapp/models/ReelsModel.dart';

class ReelsProvider with ChangeNotifier {
  List<ReelsModel> _reels = [];

  List<ReelsModel> get reels => _reels;

  void setReels(List<ReelsModel> reels) {
    _reels = reels;
    notifyListeners();
  }

  void addReel(ReelsModel reel) {
    _reels.add(reel);
    notifyListeners();
  }
}
