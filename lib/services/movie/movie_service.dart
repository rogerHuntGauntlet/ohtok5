import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'movie_firestore_service.dart';

class MovieService {
  late final FirebaseFunctions _functions;
  final bool _useLocalServer = false; // Toggle this for local/production
  final String _localServerUrl = 'http://localhost:5002'; // Updated to match our local server port
  final MovieFirestoreService _firestoreService = MovieFirestoreService();
  
  MovieService() {
    // Initialize Firebase Functions with the correct region
    _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  }

  Future<List<Map<String, dynamic>>> generateMovieScenes(String movieIdea) async {
    try {
      if (_useLocalServer) {
        // Use local server
        final response = await http.post(
          Uri.parse('$_localServerUrl/generateMovieScenes'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'movieIdea': movieIdea}),
        );

        if (response.statusCode != 200) {
          print('Error from local server: ${response.body}');
          throw 'Failed to generate movie scenes. Server returned ${response.statusCode}';
        }

        final data = json.decode(response.body);
        final List<dynamic> rawScenes = data['scenes'];
        final scenes = rawScenes.map((scene) => {
          ...scene as Map<String, dynamic>,
          'notes': [], // Initialize empty notes array
        }).toList();

        // Save to Firestore
        await _firestoreService.saveMovie(
          movieIdea: movieIdea,
          scenes: scenes,
        );

        return scenes;
      } else {
        // Use Firebase Functions
        final functionUrl = 'https://us-central1-${dotenv.env['FIREBASE_PROJECT_ID']}.cloudfunctions.net/generateMovieScenes';
        final response = await http.post(
          Uri.parse(functionUrl),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'movieIdea': movieIdea}),
        );

        if (response.statusCode != 200) {
          print('Error from cloud function: ${response.body}');
          throw 'Failed to generate movie scenes. Server returned ${response.statusCode}';
        }

        final data = json.decode(response.body);
        final List<dynamic> rawScenes = data['scenes'];
        final scenes = rawScenes.map((scene) => {
          ...scene as Map<String, dynamic>,
          'notes': [], // Initialize empty notes array
        }).toList();

        // Save to Firestore
        await _firestoreService.saveMovie(
          movieIdea: movieIdea,
          scenes: scenes,
        );

        return scenes;
      }
    } catch (e) {
      print('Error generating movie scenes: $e');
      throw 'Failed to generate movie scenes. Please try again.';
    }
  }

  Future<Map<String, dynamic>?> updateSceneWithNote(
    Map<String, dynamic> scene,
    String note,
    String movieIdea,
  ) async {
    try {
      if (_useLocalServer) {
        final response = await http.post(
          Uri.parse('$_localServerUrl/updateScene'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'scene': scene,
            'note': note,
            'movieIdea': movieIdea,
          }),
        );

        if (response.statusCode != 200) {
          print('Error from local server: ${response.body}');
          throw 'Failed to update scene. Server returned ${response.statusCode}';
        }

        final data = json.decode(response.body);
        final updatedScene = data['updatedScene'] as Map<String, dynamic>;

        // Update in Firestore if scene has a documentId
        if (scene['documentId'] != null) {
          await _firestoreService.updateScene(
            movieId: scene['movieId'],
            sceneId: scene['documentId'],
            sceneData: {
              ...updatedScene,
              'notes': [
                ...(scene['notes'] ?? []),
                {
                  'text': note,
                  'timestamp': DateTime.now().toIso8601String(),
                }
              ],
            },
          );
        }

        return updatedScene;
      } else {
        final functionUrl = 'https://us-central1-${dotenv.env['FIREBASE_PROJECT_ID']}.cloudfunctions.net/updateScene';
        final response = await http.post(
          Uri.parse(functionUrl),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'scene': scene,
            'note': note,
            'movieIdea': movieIdea,
          }),
        );

        if (response.statusCode != 200) {
          print('Error from cloud function: ${response.body}');
          throw 'Failed to update scene. Server returned ${response.statusCode}';
        }

        final data = json.decode(response.body);
        final updatedScene = data['updatedScene'] as Map<String, dynamic>;

        // Update in Firestore if scene has a documentId
        if (scene['documentId'] != null) {
          await _firestoreService.updateScene(
            movieId: scene['movieId'],
            sceneId: scene['documentId'],
            sceneData: {
              ...updatedScene,
              'notes': [
                ...(scene['notes'] ?? []),
                {
                  'text': note,
                  'timestamp': DateTime.now().toIso8601String(),
                }
              ],
            },
          );
        }

        return updatedScene;
      }
    } catch (e) {
      print('Error updating scene: $e');
      throw 'Failed to update scene. Please try again.';
    }
  }

  Stream<List<Map<String, dynamic>>> getUserMovies() {
    return _firestoreService.getUserMovies();
  }

  Future<Map<String, dynamic>> getMovie(String movieId) {
    return _firestoreService.getMovie(movieId);
  }

  Future<List<Map<String, dynamic>>> getAllMovies() {
    return _firestoreService.getAllMovies();
  }
} 