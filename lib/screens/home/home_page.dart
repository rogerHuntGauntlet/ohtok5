import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/social/auth_service.dart';
import '../../widgets/tutorial/tutorial_overlay.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../services/movie/movie_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../movie/scene_generation_loading_screen.dart';
import '../movie/movie_scenes_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../movie/movie_video_player_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey _createVideoButtonKey = GlobalKey();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _movieIdea = '';
  bool _isProcessing = false;
  bool _isSpeechInitialized = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) {
      _initializeSpeech();
    } else {
      final result = await Permission.microphone.request();
      if (result.isGranted) {
        _initializeSpeech();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required for speech recognition'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _initializeSpeech() async {
    try {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done') {
            setState(() => _isListening = false);
            if (_movieIdea.isNotEmpty) {
              _processMovieIdea();
            }
          }
        },
        onError: (error) {
          print('Speech Error: $error');
          setState(() => _isListening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $error')),
          );
        },
      );
      setState(() => _isSpeechInitialized = available);
      if (!available) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available on this device')),
        );
      }
    } catch (e) {
      print('Speech initialization error: $e');
      setState(() => _isSpeechInitialized = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to initialize speech recognition')),
      );
    }
  }

  Future<void> _startListening() async {
    if (!_isSpeechInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition is not initialized. Please try again.')),
      );
      return;
    }

    setState(() {
      _movieIdea = 'Listening...';
      _isListening = true;
    });

    late StateSetter dialogSetState;
    // Show the recording dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          dialogSetState = setDialogState;
          return AlertDialog(
            title: const Text('Recording Movie Idea'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_movieIdea),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        _speech.stop();
                        Navigator.pop(context);
                        setState(() {
                          _isListening = false;
                          _movieIdea = '';
                        });
                      },
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        _stopListening();
                        Navigator.pop(context);
                      },
                      child: const Text('Stop Recording'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    try {
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _movieIdea = result.recognizedWords.isEmpty ? 'Listening...' : result.recognizedWords;
          });
          dialogSetState(() {}); // Update the dialog with new text
        },
      );
    } catch (e) {
      print('Listen error: $e');
      setState(() {
        _isListening = false;
        _movieIdea = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start listening. Please try again.')),
      );
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
    if (_movieIdea.isNotEmpty && _movieIdea != 'Listening...') {
      _processMovieIdea();
    }
  }

  Future<void> _processMovieIdea() async {
    if (_movieIdea.isEmpty) return;

    // Show loading screen
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SceneGenerationLoadingScreen(
            movieIdea: _movieIdea,
          ),
        ),
      );
    }

    try {
      final movieService = Provider.of<MovieService>(context, listen: false);
      final scenes = await movieService.generateMovieScenes(_movieIdea);
      
      if (mounted) {
        // Replace loading screen with scenes screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => MovieScenesScreen(
              movieIdea: _movieIdea,
              scenes: scenes,
              movieId: scenes[0]['movieId'],
              movieTitle: null,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Pop loading screen on error
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing movie idea: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _showInstructions() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to Create a Movie'),
        content: const Text('Double tap the movie icon to start recording your movie idea. Tap it again to stop recording.\n\nYour idea will be processed and turned into movie scenes!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('OHFtok'),
          leading: TutorialOverlay(
            featureKey: 'create_movie',
            title: 'Create Your Movie',
            description: 'Double tap to start recording your movie idea!',
            targetPosition: _getCreateButtonPosition(),
            targetSize: const Size(48, 48),
            child: GestureDetector(
              onDoubleTap: (_isProcessing || !_isSpeechInitialized) 
                ? null 
                : () {
                    if (_isListening) {
                      _stopListening();
                    } else {
                      _startListening();
                    }
                  },
              child: IconButton(
                key: _createVideoButtonKey,
                onPressed: _isProcessing ? null : _showInstructions,
                icon: Icon(_isListening ? Icons.mic : Icons.movie_creation),
                color: _isListening ? Colors.red : null,
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: () async {
                try {
                  final service = Provider.of<MovieService>(context, listen: false);
                  final movies = await service.getAllMovies();
                  if (mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Database Contents'),
                        content: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Found ${movies.length} movies:'),
                              const SizedBox(height: 8),
                              ...movies.map((movie) => Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Movie ID: ${movie['documentId']}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text('Idea: ${movie['movieIdea']}'),
                                      Text('User: ${movie['userId']}'),
                                      Text('Status: ${movie['status']}'),
                                      Text('Created: ${_formatTimestamp(movie['createdAt'])}'),
                                    ],
                                  ),
                                ),
                              )),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error checking database: $e')),
                    );
                  }
                }
              },
            ),
            IconButton(
              onPressed: () async {
                await Provider.of<AuthService>(context, listen: false).signOut();
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
              icon: const Icon(Icons.logout),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.movie),
                text: 'My Movies',
              ),
              Tab(
                icon: Icon(Icons.fork_right),
                text: 'mNp(s)',
              ),
              Tab(
                icon: Icon(Icons.search),
                text: 'Find Movies',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMyMoviesTab(),
            _buildMyForksTab(),
            _buildFindMoviesTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildMyMoviesTab() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Movies',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: Provider.of<MovieService>(context).getUserMovies(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading movies: ${snapshot.error}',
                        style: TextStyle(color: Colors.red[400]),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final movies = snapshot.data!;
                  if (movies.isEmpty) {
                    return Center(
                      child: Text(
                        'Your created movies will appear here',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: movies.length,
                    itemBuilder: (context, index) {
                      final movie = movies[index];
                      final isComplete = _isMovieComplete(movie);
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => _navigateToMovie(movie),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const CircleAvatar(
                                      child: Icon(Icons.movie),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            movie['title'] ?? movie['movieIdea'],
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (movie['title'] != null)
                                            Text(
                                              movie['movieIdea'],
                                              style: TextStyle(color: Colors.grey[600]),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Created: ${_formatTimestamp(movie['createdAt'])}',
                                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                        ),
                                        Text(
                                          'Last Updated: ${_formatTimestamp(movie['updatedAt'] ?? movie['createdAt'])}',
                                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    if (_getIncompleteScenesCount(movie) > 0)
                                      Chip(
                                        label: Text('${_getIncompleteScenesCount(movie)} scenes need videos'),
                                        backgroundColor: Colors.orange[100],
                                        labelStyle: TextStyle(color: Colors.orange[900]),
                                      )
                                    else
                                      TextButton.icon(
                                        onPressed: () => _toggleMoviePublicStatus(movie),
                                        icon: Icon(
                                          movie['isPublic'] ? Icons.unpublished : Icons.publish,
                                          size: 18,
                                        ),
                                        label: Text(movie['isPublic'] ? 'Unpublish' : 'Publish'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: movie['isPublic'] ? Colors.red : Colors.green,
                                        ),
                                      ),
                                  ],
                                ),
                                if (movie['isPublic'])
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.visibility,
                                          size: 16,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${movie['views'] ?? 0} views',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    
    final date = timestamp is Timestamp 
        ? timestamp.toDate() 
        : DateTime.now();
    
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildMyForksTab() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Forked Movies',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              // TODO: Add forked movies list here
              Center(
                child: Text(
                  'Movies you\'ve forked will appear here',
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFindMoviesTab() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Discover Movies',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: Provider.of<MovieService>(context).getPublicMovies(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading movies: ${snapshot.error}',
                        style: TextStyle(color: Colors.red[400]),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final movies = snapshot.data!;
                  if (movies.isEmpty) {
                    return Center(
                      child: Text(
                        'No public movies available yet',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: movies.length,
                    itemBuilder: (context, index) {
                      final movie = movies[index];
                      final scenes = List<Map<String, dynamic>>.from(movie['scenes'] ?? [])
                          .where((scene) => 
                            scene['videoUrl'] != null && 
                            scene['videoUrl'].toString().isNotEmpty
                          )
                          .toList();
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () async {
                            try {
                              // Get full movie data with all scenes
                              final fullMovie = await Provider.of<MovieService>(context, listen: false)
                                  .getMovie(movie['documentId']);
                              
                              if (mounted) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => MovieScenesScreen(
                                      movieIdea: fullMovie['movieIdea'],
                                      scenes: fullMovie['scenes'],
                                      movieId: fullMovie['documentId'],
                                      movieTitle: fullMovie['title'],
                                      isReadOnly: true,  // Set to read-only mode
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error loading movie: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const CircleAvatar(
                                      child: Icon(Icons.movie),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            movie['title'] ?? movie['movieIdea'],
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (movie['title'] != null)
                                            Text(
                                              movie['movieIdea'],
                                              style: TextStyle(color: Colors.grey[600]),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.play_circle_outline),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Created: ${_formatTimestamp(movie['createdAt'])}',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                    ),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.visibility,
                                          size: 16,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${movie['views'] ?? 0}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          '${scenes.length} scenes',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateMovieDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Movie'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.mic),
              title: const Text('Voice Recording'),
              onTap: () {
                Navigator.pop(context);
                if (_isListening) {
                  _stopListening();
                } else {
                  _startListening();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.keyboard),
              title: const Text('Type Idea'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Show text input dialog
              },
            ),
          ],
        ),
      ),
    );
  }

  Offset _getCreateButtonPosition() {
    final RenderBox? renderBox = _createVideoButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return Offset.zero;
    return renderBox.localToGlobal(Offset.zero);
  }

  /// Navigate to movie details screen
  Future<void> _navigateToMovie(Map<String, dynamic> movie) async {
    try {
      final fullMovie = await Provider.of<MovieService>(context, listen: false)
          .getMovie(movie['documentId']);
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MovieScenesScreen(
              movieIdea: fullMovie['movieIdea'],
              scenes: fullMovie['scenes'],
              movieId: fullMovie['documentId'],
              movieTitle: fullMovie['title'],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading movie: $e')),
        );
      }
    }
  }

  bool _isMovieComplete(Map<String, dynamic> movie) {
    final scenes = movie['scenes'] as List<dynamic>?;
    if (scenes == null || scenes.isEmpty) return false;
    return scenes.every((scene) => 
      scene['status'] == 'completed' && 
      scene['videoUrl'] != null && 
      scene['videoUrl'].toString().isNotEmpty
    );
  }

  int _getIncompleteScenesCount(Map<String, dynamic> movie) {
    final scenes = movie['scenes'] as List<dynamic>?;
    if (scenes == null) return 0;
    
    return scenes.where((scene) => 
      scene['videoUrl'] == null || 
      scene['videoUrl'].toString().isEmpty
    ).length;
  }

  Future<void> _toggleMoviePublicStatus(Map<String, dynamic> movie) async {
    try {
      final movieService = Provider.of<MovieService>(context, listen: false);
      await movieService.updateMoviePublicStatus(
        movie['documentId'],
        !movie['isPublic'],
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              movie['isPublic'] 
                ? 'Movie unpublished successfully' 
                : 'Movie published successfully'
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating movie status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 