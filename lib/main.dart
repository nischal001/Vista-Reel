import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reelsapp/providers/ReelsProvider.dart';
import 'package:reelsapp/providers/UserProvider.dart';
import 'package:reelsapp/screens/Auth/Welcome.dart';
import 'package:reelsapp/screens/CustomMediaPicker.dart';
import 'package:reelsapp/screens/Homepage.dart';
import 'package:reelsapp/screens/ImageMerger.dart';
import 'package:reelsapp/screens/OnboardingScreen.dart';
import 'package:reelsapp/screens/VideoMaker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => UserProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ReelsProvider(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Reels App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: MediaMerger(),
      ),
    );
  }
}
