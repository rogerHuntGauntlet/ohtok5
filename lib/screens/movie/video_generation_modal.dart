import 'package:flutter/material.dart';

class VideoGenerationModal extends StatelessWidget {
  final String sceneText;
  final Stream<VideoGenerationProgress> progressStream;

  const VideoGenerationModal({
    super.key,
    required this.sceneText,
    required this.progressStream,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Generating Video',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            // Progress steps
            StreamBuilder<VideoGenerationProgress>(
              stream: progressStream,
              builder: (context, snapshot) {
                final progress = snapshot.data ?? VideoGenerationProgress(
                  stage: 'analyzing',
                  stageIndex: 0,
                  percentage: 0.0,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProgressStep(
                      'Analyzing Scene',
                      isActive: progress.stage == 'analyzing',
                      isCompleted: progress.stageIndex > 0,
                      percentage: progress.stage == 'analyzing' ? progress.percentage : null,
                    ),
                    const SizedBox(height: 16),
                    _buildProgressStep(
                      'Generating Storyboard',
                      isActive: progress.stage == 'storyboard',
                      isCompleted: progress.stageIndex > 1,
                      percentage: progress.stage == 'storyboard' ? progress.percentage : null,
                    ),
                    const SizedBox(height: 16),
                    _buildProgressStep(
                      'Creating Video Frames',
                      isActive: progress.stage == 'frames',
                      isCompleted: progress.stageIndex > 2,
                      percentage: progress.stage == 'frames' ? progress.percentage : null,
                    ),
                    const SizedBox(height: 16),
                    _buildProgressStep(
                      'Compositing Video',
                      isActive: progress.stage == 'compositing',
                      isCompleted: progress.stageIndex > 3,
                      percentage: progress.stage == 'compositing' ? progress.percentage : null,
                    ),
                    const SizedBox(height: 16),
                    _buildProgressStep(
                      'Adding Audio',
                      isActive: progress.stage == 'audio',
                      isCompleted: progress.stageIndex > 4,
                      percentage: progress.stage == 'audio' ? progress.percentage : null,
                    ),
                    const SizedBox(height: 16),
                    _buildProgressStep(
                      'Finalizing',
                      isActive: progress.stage == 'finalizing',
                      isCompleted: progress.stageIndex > 5,
                      percentage: progress.stage == 'finalizing' ? progress.percentage : null,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            // Scene preview
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Scene:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sceneText,
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressStep(
    String title, {
    required bool isActive,
    required bool isCompleted,
    double? percentage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? Colors.green
                    : isActive
                        ? Colors.blue
                        : Colors.grey[300],
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : isActive
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : null,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: isActive || isCompleted ? Colors.black : Colors.grey,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isActive && percentage != null) ...[
              const Spacer(),
              Text(
                '${(percentage * 100).round()}%',
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        if (isActive && percentage != null) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ],
      ],
    );
  }
}

class VideoGenerationProgress {
  final String stage;
  final int stageIndex;
  final double percentage;

  VideoGenerationProgress({
    required this.stage,
    required this.stageIndex,
    required this.percentage,
  });
} 