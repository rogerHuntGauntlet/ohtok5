import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MovieFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<List<Map<String, dynamic>>> getAllMovies() async {
    try {
      final snapshot = await _firestore.collection('movies').get();
      return snapshot.docs.map((doc) => {
        ...doc.data(),
        'documentId': doc.id,
      }).toList();
    } catch (e) {
      print('Error getting all movies: $e');
      throw 'Failed to get movies';
    }
  }

  Future<String> saveMovie({
    required String movieIdea,
    required List<Map<String, dynamic>> scenes,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'User not authenticated';

      final movieDoc = await _firestore.collection('movies').add({
        'userId': user.uid,
        'movieIdea': movieIdea,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'draft',
        'isPublic': false,
        'likes': 0,
        'views': 0,
        'forks': 0,
      });

      // Add scenes as a subcollection
      final batch = _firestore.batch();
      for (final scene in scenes) {
        final sceneRef = movieDoc.collection('scenes').doc();
        batch.set(sceneRef, {
          ...scene,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      // Update user's movies count
      await _firestore.collection('users').doc(user.uid).update({
        'moviesCount': FieldValue.increment(1),
      });

      return movieDoc.id;
    } catch (e) {
      print('Error saving movie: $e');
      throw 'Failed to save movie. Please try again.';
    }
  }

  Future<Map<String, dynamic>> getMovie(String movieId) async {
    try {
      final movieDoc = await _firestore.collection('movies').doc(movieId).get();
      if (!movieDoc.exists) throw 'Movie not found';

      final scenesSnapshot = await movieDoc.reference.collection('scenes').orderBy('id').get();
      final scenes = scenesSnapshot.docs.map((doc) => {
        ...doc.data(),
        'documentId': doc.id,
      }).toList();

      return {
        ...movieDoc.data()!,
        'documentId': movieDoc.id,
        'scenes': scenes,
      };
    } catch (e) {
      print('Error getting movie: $e');
      throw 'Failed to load movie. Please try again.';
    }
  }

  Future<void> updateScene({
    required String movieId,
    required String sceneId,
    required Map<String, dynamic> sceneData,
  }) async {
    try {
      await _firestore
          .collection('movies')
          .doc(movieId)
          .collection('scenes')
          .doc(sceneId)
          .update({
        ...sceneData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating scene: $e');
      throw 'Failed to update scene. Please try again.';
    }
  }

  Stream<List<Map<String, dynamic>>> getUserMovies() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw 'User not authenticated';

    return _firestore
        .collection('movies')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .asyncMap((snapshot) async {
          final movies = <Map<String, dynamic>>[];
          
          for (final doc in snapshot.docs) {
            final movieData = doc.data();
            final scenesSnapshot = await doc.reference
                .collection('scenes')
                .orderBy('id')
                .get();
            
            final scenes = scenesSnapshot.docs
                .map((sceneDoc) => {
                      ...sceneDoc.data(),
                      'documentId': sceneDoc.id,
                    })
                .toList();

            movies.add({
              ...movieData,
              'documentId': doc.id,
              'scenes': scenes,
            });
          }
          
          return movies;
        });
  }

  /// Updates a movie's title
  Future<void> updateMovieTitle(String movieId, String title) async {
    try {
      await _firestore.collection('movies').doc(movieId).update({
        'title': title,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating movie title: $e');
      throw 'Failed to update movie title';
    }
  }

  /// Updates a movie's public status
  Future<void> updateMoviePublicStatus(String movieId, bool isPublic) async {
    try {
      await _firestore.collection('movies').doc(movieId).update({
        'isPublic': isPublic,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating movie public status: $e');
      throw 'Failed to update movie public status';
    }
  }

  /// Gets all public movies with their scenes
  Stream<List<Map<String, dynamic>>> getPublicMovies() {
    return _firestore
        .collection('movies')
        .where('isPublic', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final movies = <Map<String, dynamic>>[];
          
          for (final doc in snapshot.docs) {
            final movieData = doc.data();
            final scenesSnapshot = await doc.reference
                .collection('scenes')
                .orderBy('id')
                .get();
            
            final scenes = scenesSnapshot.docs
                .map((sceneDoc) => {
                      ...sceneDoc.data(),
                      'documentId': sceneDoc.id,
                    })
                .where((scene) => 
                    scene['status'] == 'completed' && 
                    scene['videoUrl'] != null && 
                    scene['videoUrl'].toString().isNotEmpty
                )
                .toList();

            if (scenes.isNotEmpty) {
              movies.add({
                ...movieData,
                'documentId': doc.id,
                'scenes': scenes,
              });
            }
          }
          
          return movies;
        });
  }
} 