import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/movie/movie_service.dart';
import '../../services/movie/movie_video_service.dart';
import '../video/movie_video_player_screen.dart';
import 'scene_generation_modal.dart';
import 'video_generation_modal.dart';
import 'dart:async';

class MovieScenesScreen extends StatefulWidget {
  final String movieIdea;
  final List<Map<String, dynamic>> scenes;
  final String? movieTitle;
  final String movieId;
  final bool isReadOnly;

  const MovieScenesScreen({
    super.key,
    required this.movieIdea,
    required this.scenes,
    required this.movieId,
    this.movieTitle,
    this.isReadOnly = false,
  });

  @override
  State<MovieScenesScreen> createState() => _MovieScenesScreenState();
}

class _MovieScenesScreenState extends State<MovieScenesScreen> {
  String? _currentTitle;
  final MovieVideoService _videoService = MovieVideoService();

  @override
  void initState() {
    super.initState();
    _currentTitle = widget.movieTitle;
  }

  Future<void> _showTitleDialog(BuildContext context, {String? currentTitle}) async {
    final textController = TextEditingController(text: currentTitle);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(currentTitle == null ? 'Create Movie Title' : 'Edit Movie Title'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                hintText: 'Enter a title for your movie...',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final title = textController.text.trim();
              if (title.isEmpty) return;

              try {
                final movieService = Provider.of<MovieService>(context, listen: false);
                await movieService.updateMovieTitle(widget.movieId, title);
                setState(() => _currentTitle = title);
                Navigator.of(context).pop();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: Text(currentTitle == null ? 'Create' : 'Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context, Map<String, dynamic> scene) async {
    final textController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Scene'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your notes or changes for this scene:'),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter your notes here...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(textController.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final progressController = StreamController<String>();
      
      // Show the generation modal
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => SceneGenerationModal(
          originalScene: scene['text'],
          notes: result,
          progressStream: progressController.stream,
        ),
      );

      try {
        final movieService = Provider.of<MovieService>(context, listen: false);
        final updatedScene = await movieService.updateSceneWithNote(
          scene,
          result,
          widget.movieIdea,
          progressController,
        );

        // Close the generation modal
        if (context.mounted) {
          Navigator.of(context).pop();
        }

        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Scene updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        // Close the generation modal
        if (context.mounted) {
          Navigator.of(context).pop();
        }

        // Show error message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        await progressController.close();
      }
    }
  }

  Future<void> _generateVideo(BuildContext context, Map<String, dynamic> scene) async {
    final progressController = StreamController<VideoGenerationProgress>();
    
    // Show the generation modal
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => VideoGenerationModal(
        sceneText: scene['text'],
        progressStream: progressController.stream,
      ),
    );

    try {
      final movieService = Provider.of<MovieService>(context, listen: false);
      final videoUrl = await movieService.generateVideo(
        scene,
        progressController,
      );

      // Close the generation modal
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Update the scene with the new video
      await movieService.updateSceneVideo(
        widget.movieId,
        scene['documentId'],
        videoUrl,
        DateTime.now().millisecondsSinceEpoch.toString(),
      );

      // Show success message with preview option
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Video Generated!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text('Your video has been generated successfully.'),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // TODO: Navigate to video preview screen
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Watch Video'),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      // Close the generation modal
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      await progressController.close();
    }
  }

  Future<void> _uploadVideo(BuildContext context, Map<String, dynamic> scene, bool fromCamera) async {
    try {
      // Show upload progress dialog
      final progressController = StreamController<double>();
      
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => StreamBuilder<double>(
          stream: progressController.stream,
          builder: (context, snapshot) {
            return AlertDialog(
              title: Text(snapshot.data == 1.0 ? 'Complete!' : 'Uploading Video'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  if (snapshot.data != 1.0) LinearProgressIndicator(
                    value: snapshot.data,
                  ),
                  if (snapshot.data == 1.0) const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    snapshot.data == 1.0
                      ? 'Video upload successful!'
                      : snapshot.data != null 
                        ? '${(snapshot.data! * 100).toStringAsFixed(0)}%'
                        : 'Starting upload...',
                  ),
                ],
              ),
              actions: snapshot.data == 1.0 ? [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ] : null,
            );
          },
        ),
      );

      final movieService = Provider.of<MovieService>(context, listen: false);
      final result = await _videoService.uploadVideoForScene(
        movieId: widget.movieId,
        sceneId: scene['documentId'],
        context: context,
        fromCamera: fromCamera,
        onProgress: (progress) {
          progressController.add(progress);
        },
      );

      if (result != null) {
        await movieService.updateSceneVideo(
          widget.movieId,
          scene['documentId'],
          result['videoUrl']!,
          result['videoId']!,
          isUserVideo: true,
        );

        // Send final progress to show completion state
        progressController.add(1.0);

        // Update the scene status in the UI
        setState(() {
          final index = widget.scenes.indexWhere((s) => s['documentId'] == scene['documentId']);
          if (index != -1) {
            widget.scenes[index]['status'] = 'completed';
          }
        });
      }
    } catch (e) {
      // Close progress dialog on error
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Movie Scenes'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Movie Title:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            if (_currentTitle != null)
                              TextButton.icon(
                                onPressed: () => _showTitleDialog(context, currentTitle: _currentTitle),
                                icon: const Icon(Icons.edit),
                                label: const Text('Edit'),
                              )
                            else
                              TextButton.icon(
                                onPressed: () => _showTitleDialog(context),
                                icon: const Icon(Icons.add),
                                label: const Text('Create Title'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_currentTitle != null)
                          Text(
                            _currentTitle!,
                            style: const TextStyle(fontSize: 20),
                          )
                        else
                          const Text(
                            'No title yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Movie Idea:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.movieIdea,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Suggested Scenes:',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.scenes.length,
                  itemBuilder: (context, index) {
                    final scene = widget.scenes[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          child: Text('${scene['id']}'),
                        ),
                        title: Text(
                          scene['title'] ?? 'Scene ${scene['id']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          scene['text'],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 12,
                              color: _getStatusColor(scene['status']),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              scene['status'],
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  scene['text'],
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (scene['videoUrl'] != null && scene['videoUrl'].toString().isNotEmpty)
                                      TextButton.icon(
                                        onPressed: () {
                                          final scenesWithVideos = widget.scenes.where((scene) => 
                                            scene['videoUrl'] != null && scene['videoUrl'].toString().isNotEmpty
                                          ).toList();
                                          
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) => MovieVideoPlayerScreen(
                                                scenes: scenesWithVideos,
                                                initialIndex: scenesWithVideos.indexWhere(
                                                  (s) => s['documentId'] == scene['documentId']
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.play_circle_outline),
                                        label: const Text('Watch Video'),
                                      ),
                                    if (!widget.isReadOnly)
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.video_library),
                                        tooltip: 'Add Video',
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'ai',
                                            child: Row(
                                              children: [
                                                Icon(Icons.auto_awesome),
                                                SizedBox(width: 8),
                                                Text('Generate AI Video'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'camera',
                                            child: Row(
                                              children: [
                                                Icon(Icons.camera_alt),
                                                SizedBox(width: 8),
                                                Text('Record Video'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'gallery',
                                            child: Row(
                                              children: [
                                                Icon(Icons.photo_library),
                                                SizedBox(width: 8),
                                                Text('Upload from Gallery'),
                                              ],
                                            ),
                                          ),
                                        ],
                                        onSelected: (value) async {
                                          switch (value) {
                                            case 'ai':
                                              await _generateVideo(context, scene);
                                              break;
                                            case 'camera':
                                              await _uploadVideo(context, scene, true);
                                              break;
                                            case 'gallery':
                                              await _uploadVideo(context, scene, false);
                                              break;
                                          }
                                        },
                                      ),
                                    if (!widget.isReadOnly)
                                      TextButton.icon(
                                        onPressed: () => _showEditDialog(context, scene),
                                        icon: const Icon(Icons.edit),
                                        label: const Text('Edit'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          onPressed: () {
            final scenesWithVideos = widget.scenes.where((scene) => 
              scene['videoUrl'] != null && scene['videoUrl'].toString().isNotEmpty
            ).toList();
            
            if (scenesWithVideos.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No videos available yet. Add some videos to your scenes first.'),
                ),
              );
              return;
            }
            
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => MovieVideoPlayerScreen(
                  scenes: scenesWithVideos,
                ),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          icon: const Icon(Icons.movie),
          label: const Text('Watch Full Movie'),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.grey;
      case 'recording':
        return Colors.red;
      case 'completed':
        return Colors.green;
      case 'failed':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
} 