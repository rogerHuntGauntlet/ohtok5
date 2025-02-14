import 'package:flutter/material.dart';

class SceneGenerationModal extends StatelessWidget {
  final String originalScene;
  final String notes;
  final Stream<String> progressStream;

  const SceneGenerationModal({
    super.key,
    required this.originalScene,
    required this.notes,
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
              'Generating New Scene',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            // Progress steps
            StreamBuilder<String>(
              stream: progressStream,
              builder: (context, snapshot) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProgressStep(
                      'Analyzing Original Scene',
                      isActive: snapshot.data == 'analyzing',
                      isCompleted: snapshot.data == 'processing' || snapshot.data == 'finalizing',
                    ),
                    const SizedBox(height: 16),
                    _buildProgressStep(
                      'Processing Your Notes',
                      isActive: snapshot.data == 'processing',
                      isCompleted: snapshot.data == 'finalizing',
                    ),
                    const SizedBox(height: 16),
                    _buildProgressStep(
                      'Finalizing Scene',
                      isActive: snapshot.data == 'finalizing',
                      isCompleted: false,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            // Original scene and notes preview
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
                    'Your Notes:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notes,
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
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

  Widget _buildProgressStep(String title, {required bool isActive, required bool isCompleted}) {
    return Row(
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
      ],
    );
  }
} 