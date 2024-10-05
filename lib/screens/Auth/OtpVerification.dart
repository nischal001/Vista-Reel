import 'package:flutter/material.dart';
import 'package:flutter_otp_text_field/flutter_otp_text_field.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import 'package:reelsapp/providers/UserProvider.dart';

class OTPVerificationPage extends StatefulWidget {
  String phonenumber;
  String verificationId;
  OTPVerificationPage({
    super.key,
    required this.phonenumber,
    required this.verificationId,
  });

  @override
  State<OTPVerificationPage> createState() => _OTPVerificationPageState();
}

class _OTPVerificationPageState extends State<OTPVerificationPage> {
  TextEditingController otpController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Verification Code',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xff3A77CE),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18.0),
            child: Text(
              'enter the verification code we just sent on your email address nischaltuxxxxx@gmail.com',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
          Center(
            child: Pinput(
              length: 6,
              controller: otpController,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: InkWell(
              onTap: () async {
                if (otpController.text.isEmpty) {
                  // AppUtil().showErrorDialog(context, 'OTP is required');
                  return;
                }

                final userProvider =
                    Provider.of<UserProvider>(context, listen: false);
                try {
                  await userProvider.verifyOtpAndProceed(
                    context: context,
                    otp: otpController.text,
                    verificationId: widget.verificationId,
                    phoneNumber: widget.phonenumber,
                  );
                  print('Done');
                  // AppUtil()
                  //     .showSuccessDialog(context, 'User verified successfully');
                } catch (e) {
                  // AppUtil()
                  //     .showErrorDialog(context, 'Failed to verify OTP: $e');
                }
              },
              child: Container(
                height: 50,
                width: MediaQuery.of(context).size.width / 1.5,
                decoration: BoxDecoration(
                  color: Color(0xff222F74),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'Verify',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: MediaQuery.of(context).size.width,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Didn't receive an OTP ? ",
                  style: GoogleFonts.outfit(),
                ),
                InkWell(
                  onTap: () {},
                  child: Text(
                    'Resend Now',
                    style: GoogleFonts.outfit(
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
