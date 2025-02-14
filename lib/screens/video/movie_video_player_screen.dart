import 'package:flutter/material.dart';
import '../video/components/video_player.dart';

class MovieVideoPlayerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> scenes;
  final int initialIndex;

  const MovieVideoPlayerScreen({
    super.key,
    required this.scenes,
    this.initialIndex = 0,
  });

  @override
  State<MovieVideoPlayerScreen> createState() => _MovieVideoPlayerScreenState();
}

class _MovieVideoPlayerScreenState extends State<MovieVideoPlayerScreen> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Filter scenes that have videos
    final scenesWithVideos = widget.scenes.where((scene) => 
      scene['videoUrl'] != null && scene['videoUrl'].toString().isNotEmpty
    ).toList();

    if (scenesWithVideos.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text('No videos available'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity! < 0 && _currentIndex < scenesWithVideos.length - 1) {
            // Swipe up to next video
            _pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          } else if (details.primaryVelocity! > 0 && _currentIndex > 0) {
            // Swipe down to previous video
            _pageController.previousPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        },
        child: Stack(
          children: [
            // Video PageView
            PageView.builder(
              physics: const NeverScrollableScrollPhysics(), // Disable PageView scrolling
              controller: _pageController,
              scrollDirection: Axis.vertical,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemCount: scenesWithVideos.length,
              itemBuilder: (context, index) {
                final scene = scenesWithVideos[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Video Player
                    VideoPlayer(
                      videoUrl: scene['videoUrl']!,
                      autoPlay: index == _currentIndex,
                      showControls: true,
                      fit: BoxFit.cover,
                    ),
                    
                    // Scene Info Overlay
                    Positioned(
                      left: 16,
                      right: MediaQuery.of(context).size.width * 0.25, // Make it 75% width
                      bottom: 85,
                      child: GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.black.withOpacity(0.8),
                            isScrollControlled: true,
                            builder: (context) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                              decoration: const BoxDecoration(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Scene ${scene['id']}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(Icons.close, color: Colors.white),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    scene['text'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 40),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Scene ${scene['id']}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 8,
                                          color: Colors.black54,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.touch_app,
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                scene['text'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 8,
                                      color: Colors.black54,
                                    ),
                                  ],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Navigation Indicator
                    Positioned(
                      right: 16,
                      bottom: 85,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Up arrow (show if not last scene)
                            if (index < scenesWithVideos.length - 1) ...[
                              const Icon(
                                Icons.keyboard_arrow_up,
                                color: Colors.white,
                                size: 32,
                              ),
                              Text(
                                'Scene ${scene['id'] + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                            
                            if (index < scenesWithVideos.length - 1 && index > 0)
                              const SizedBox(height: 12),
                              
                            // Down arrow (show if not first scene)
                            if (index > 0) ...[
                              Text(
                                'Scene ${scene['id'] - 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.white,
                                size: 32,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            
            // Back Button with Gradient Background
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                        ),
                        const Spacer(),
                        // Scene counter
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Scene ${_currentIndex + 1}/${scenesWithVideos.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 