// providers/user_provider.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:reelsapp/models/UserModel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reelsapp/screens/Auth/RegisterPage.dart';
import 'package:reelsapp/screens/Homepage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _verificationId;
  UserModel? _user;

  UserModel? get user => _user;

  void setUser(UserModel user) {
    _user = user;
    notifyListeners();
  }

  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          throw e;
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          onCodeSent(
              verificationId); // Call the callback function with the verificationId
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      throw e;
    }
  }

  Future<void> verifyOtpAndProceed({
    required String verificationId,
    required String otp,
    required BuildContext context,
    required String phoneNumber,
  }) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      SharedPreferences prefs = await SharedPreferences.getInstance();

      if (doc.exists) {
        // _user = UserModel.fromFirestore(doc);
        notifyListeners();

        // Save login state
        prefs.setBool('isLoggedIn', true);
        prefs.setString('userId', userCredential.user!.uid);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                Homepage(), // Replace with your admin dashboard page
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => RegisterPage()),
        );
      }
    } catch (e) {
      throw e;
    }
  }
}

// providers/reels_provider.dart
