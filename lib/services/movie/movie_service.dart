import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../openai/openai_service.dart';
import 'movie_firestore_service.dart';
import 'package:flutter/material.dart';
import '../../screens/movie/video_generation_modal.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MovieService {
  final FirebaseFunctions _functions;
  final MovieFirestoreService _firestoreService = MovieFirestoreService();
  final OpenAIService _openAIService = OpenAIService();
  
  MovieService() : _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Generates movie scenes using AI
  Future<List<Map<String, dynamic>>> generateMovieScenes(String movieIdea) async {
    try {
      print('Starting generateMovieScenes with idea: $movieIdea');
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'User not authenticated';
      
      print('User authenticated: ${user.uid}');
      print('Initializing HTTP request...');

      final payload = {
        'movieIdea': movieIdea,
        'userId': user.uid,
      };
      print('Payload prepared: ${json.encode(payload)}');

      print('Making HTTP POST request...');
      final response = await http.post(
        Uri.parse('https://us-central1-${dotenv.env['FIREBASE_PROJECT_ID']}.cloudfunctions.net/generateMovieScenes'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      if (response.statusCode != 200) {
        print('Error from cloud function: ${response.body}');
        throw 'Failed to generate scenes. Server returned ${response.statusCode}';
      }

      final data = json.decode(response.body);
      if (data == null || !data.containsKey('scenes')) {
        print('No data received from function');
        throw 'No scenes generated';
      }

      print('Processing scenes from result...');
      final scenes = List<Map<String, dynamic>>.from(data['scenes']);
      print('Successfully processed ${scenes.length} scenes');
      
      return scenes;
    } catch (e, stackTrace) {
      print('Error generating movie scenes: $e');
      print('Stack trace: $stackTrace');
      throw 'Failed to generate movie scenes. Please try again.';
    }
  }

  /// Gets all movies (admin function)
  Future<List<Map<String, dynamic>>> getAllMovies() async {
    return _firestoreService.getAllMovies();
  }

  /// Gets movies for the current user
  Stream<List<Map<String, dynamic>>> getUserMovies() {
    return _firestoreService.getUserMovies();
  }

  /// Gets all public movies
  Stream<List<Map<String, dynamic>>> getPublicMovies() {
    return _firestoreService.getPublicMovies();
  }

  /// Gets a single movie by ID
  Future<Map<String, dynamic>> getMovie(String documentId) async {
    return _firestoreService.getMovie(documentId);
  }

  /// Updates a movie's title
  Future<void> updateMovieTitle(String movieId, String title) async {
    return _firestoreService.updateMovieTitle(movieId, title);
  }

  /// Updates a movie's public status
  Future<void> updateMoviePublicStatus(String movieId, bool isPublic) async {
    return _firestoreService.updateMoviePublicStatus(movieId, isPublic);
  }

  /// Generates video for a scene using AI
  Future<String> generateVideo(
    Map<String, dynamic> scene,
    StreamController<VideoGenerationProgress> progressController,
  ) async {
    try {
      print('Starting video generation for scene: ${scene['id']}');
      
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'User not authenticated';

      // Prepare scene data for the cloud function
      final sceneData = {
        'scene': {
          'text': scene['text'],
          'documentId': scene['documentId'],
          'movieId': scene['movieId'],
        },
        'userId': user.uid,
      };

      // Call generateSingleScene function
      print('Initiating video generation...');
      final response = await http.post(
        Uri.parse('https://us-central1-${dotenv.env['FIREBASE_PROJECT_ID']}.cloudfunctions.net/generateSingleScene'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(sceneData),
      );

      if (response.statusCode != 200) {
        print('Error from cloud function: ${response.body}');
        throw 'Failed to start video generation. Server returned ${response.statusCode}';
      }

      final data = json.decode(response.body);
      final String? jobId = data['jobId'];
      
      if (jobId == null) {
        print('Full response for debugging: ${response.body}');
        throw 'No jobId returned from server';
      }

      // Poll for status updates
      bool isComplete = false;
      String videoUrl = '';
      String videoId = '';
      
      while (!isComplete) {
        await Future.delayed(const Duration(seconds: 2));
        
        final statusResponse = await http.post(
          Uri.parse('https://us-central1-${dotenv.env['FIREBASE_PROJECT_ID']}.cloudfunctions.net/getGenerationStatus'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'jobId': jobId}),
        );
        
        if (statusResponse.statusCode != 200) {
          print('Error checking status: ${statusResponse.body}');
          throw 'Failed to check video status. Server returned ${statusResponse.statusCode}';
        }

        final statusData = json.decode(statusResponse.body);
        final String status = statusData['status'] ?? 'unknown';
        final double progress = statusData['progress'] ?? 0.0;
        final String message = statusData['message'] ?? 'Processing...';
        
        // Update progress
        progressController.add(VideoGenerationProgress(
          stage: status,
          stageIndex: _getStageIndex(status),
          percentage: progress,
        ));

        if (status == 'completed') {
          isComplete = true;
          videoUrl = statusData['videoUrl'];
          videoId = statusData['videoId'];
        } else if (status == 'failed') {
          throw statusData['error'] ?? 'Video generation failed';
        }
      }

      return videoUrl;
    } catch (e, stackTrace) {
      print('Error generating video: $e');
      print('Stack trace: $stackTrace');
      throw 'Failed to generate video. Please try again.';
    }
  }

  /// Updates a scene with a video URL and metadata
  Future<void> updateSceneVideo(
    String movieId,
    String sceneId,
    String videoUrl,
    String videoId,
    {bool isUserVideo = false}
  ) async {
    try {
      await _firestoreService.updateScene(
        movieId: movieId,
        sceneId: sceneId,
        sceneData: {
          'videoUrl': videoUrl,
          'videoId': videoId,
          'videoType': isUserVideo ? 'user' : 'ai',
          'status': 'completed',
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    } catch (e) {
      print('Error updating scene video: $e');
      throw 'Failed to update scene with video URL. Please try again.';
    }
  }

  /// Updates a scene with user notes and regenerates the scene text
  Future<Map<String, dynamic>?> updateSceneWithNote(
    Map<String, dynamic> scene,
    String note,
    String movieIdea,
    StreamController<String> progressController,
  ) async {
    try {
      // Get updated scene text from OpenAI
      final updatedText = await _openAIService.updateSceneText(
        originalScene: scene['text'],
        notes: note,
        movieIdea: movieIdea,
        progressController: progressController,
      );

      // Create updated scene data
      final updatedScene = {
        ...scene,
        'text': updatedText,
        'notes': [
          ...(scene['notes'] ?? []),
          {
            'text': note,
            'timestamp': DateTime.now().toIso8601String(),
          }
        ],
      };

      // Update in Firestore if scene has a documentId
      if (scene['documentId'] != null) {
        await _firestoreService.updateScene(
          movieId: scene['movieId'],
          sceneId: scene['documentId'],
          sceneData: updatedScene,
        );
      }

      return updatedScene;
    } catch (e) {
      print('Error updating scene: $e');
      throw 'Failed to update scene. Please try again.';
    }
  }

  // Helper method to get stage index for progress tracking
  int _getStageIndex(String status) {
    switch (status) {
      case 'analyzing':
        return 0;
      case 'generating':
        return 1;
      case 'processing':
        return 2;
      case 'downloading':
        return 3;
      case 'uploading':
        return 4;
      case 'completed':
        return 5;
      default:
        return 0;
    }
  }
}