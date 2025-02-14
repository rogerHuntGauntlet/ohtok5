import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MovieVideoService {
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Uploads a video for a scene, either from camera or gallery
  Future<Map<String, String>?> uploadVideoForScene({
    required String movieId,
    required String sceneId,
    required BuildContext context,
    required bool fromCamera,
    void Function(double progress)? onProgress,
  }) async {
    try {
      print('Starting video upload process');

      // Check authentication
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('User not authenticated');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please sign in to upload videos'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return null;
      }

      print('User authenticated: ${currentUser.uid}');

      // Pick video from camera or gallery
      final XFile? videoFile = await _picker.pickVideo(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );

      if (videoFile == null) {
        print('No video file selected');
        return null;
      }

      print('Video file selected: ${videoFile.path}');

      // Get file size for progress calculation
      final fileSize = await videoFile.length();
      
      // Create the storage reference
      final storageRef = _storage.ref();
      final videoRef = storageRef.child('movies/$movieId/scenes/$sceneId/${DateTime.now().millisecondsSinceEpoch}.mp4');

      // Show upload progress
      final progressDialog = _showUploadProgress(context);

      // Start upload with progress tracking
      final uploadTask = videoRef.putFile(
        File(videoFile.path),
        SettableMetadata(
          contentType: 'video/mp4',
          customMetadata: {
            'videoId': videoRef.name,
            'movieId': movieId,
            'sceneId': sceneId,
            'userId': currentUser.uid,
            'uploadedAt': DateTime.now().toIso8601String(),
            'sourceType': 'user',
          },
        ),
      );

      print('Upload task started');

      // Track upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (onProgress != null) {
          final progress = snapshot.bytesTransferred / fileSize;
          onProgress(progress);
        }
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('Upload progress: ${progress.toStringAsFixed(1)}%');
        progressDialog.update(progress);
      });

      // Wait for upload to complete
      print('Waiting for upload to complete...');
      final snapshot = await uploadTask;
      print('Upload completed. Total bytes: ${snapshot.totalBytes}');

      // Get download URL
      final videoUrl = await videoRef.getDownloadURL();
      final videoId = videoRef.name;
      print('Download URL obtained: $videoUrl');

      // Close progress dialog
      progressDialog.close();

      return {
        'videoUrl': videoUrl,
        'videoId': videoId,
      };
    } catch (e, stackTrace) {
      print('Error in uploadVideoForScene: $e');
      print('Stack trace: $stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }

  _ProgressDialog _showUploadProgress(BuildContext context) {
    final dialog = _ProgressDialog(context: context);
    dialog.show();
    return dialog;
  }
}

class _ProgressDialog {
  final BuildContext context;
  bool _isShowing = false;
  double _progress = 0;

  _ProgressDialog({required this.context});

  void show() {
    if (!_isShowing) {
      _isShowing = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text('Uploading video... ${_progress.toStringAsFixed(1)}%'),
                  ],
                ),
              );
            },
          );
        },
      );
    }
  }

  void update(double progress) {
    _progress = progress;
    if (_isShowing && context.mounted) {
      Navigator.of(context).pop();
      show();
    }
  }

  void close() {
    if (_isShowing && context.mounted) {
      Navigator.of(context).pop();
      _isShowing = false;
    }
  }
}