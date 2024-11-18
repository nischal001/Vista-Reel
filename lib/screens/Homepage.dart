import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:reelsapp/screens/ImageMerger.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  List<Map<String, dynamic>> templates =
      []; // Updated to hold full template data

  @override
  void initState() {
    super.initState();
    fetchTemplates();
  }

  Future<void> createTemplate() async {
    // Reference to the Firestore collection
    CollectionReference templatesRef =
        FirebaseFirestore.instance.collection('templates');

    // Template data with an array of objects in durations
    Map<String, dynamic> templateData = {
      "templateName": "Second",
      "templateAudio":
          "https://firebasestorage.googleapis.com/v0/b/reelsapp-5239d.appspot.com/o/J.%20Cole%20-%20She%20Knows%20(Lyrics).mp3?alt=media",
      "templateCategory": "Trendy",
      "durations": [
        {"duration": 2.5, "hasTransition": "No", "transitionType": "none"},
        {"duration": 3.0, "hasTransition": "Yes", "transitionType": "fade"},
        {"duration": 2.0, "hasTransition": "Yes", "transitionType": "pixelize"},
        {"duration": 2.0, "hasTransition": "Yes", "transitionType": "wipeleft"},
        {
          "duration": 2.0,
          "hasTransition": "Yes",
          "transitionType": "wiperight"
        },
      ]
    };

    // Add the template to Firestore
    await templatesRef.add(templateData);
  }

  Future<void> fetchTemplates() async {
    // Fetch templates from Firestore
    try {
      QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('templates').get();
      setState(() {
        templates = snapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
      });
    } catch (e) {
      print('Error fetching templates: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Vista Reels',
          style: GoogleFonts.poppins(
            color: Colors.white,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              createTemplate();
            },
            child: Text(
              'Pro',
              style: GoogleFonts.poppins(
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
      body: templates.isEmpty
          ? Center(
              child: CircularProgressIndicator(),
            ) // Loading indicator
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: templates.map((template) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MediaMerger(
                              template:
                                  templates, // Pass the entire template object here
                            ),
                          ),
                        );
                      },
                      child: Container(
                        height: 250,
                        width: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            template['templateName'], // Display template name
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }
}
