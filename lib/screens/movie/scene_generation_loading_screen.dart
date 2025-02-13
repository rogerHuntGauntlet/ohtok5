import 'package:flutter/material.dart';

class SceneGenerationLoadingScreen extends StatelessWidget {
  final String movieIdea;

  const SceneGenerationLoadingScreen({
    super.key,
    required this.movieIdea,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '🎬 Creating Your Movie',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Movie Idea:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        movieIdea,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Center(
                child: CircularProgressIndicator(),
              ),
              const SizedBox(height: 32),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What\'s Happening:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      _StepIndicator(
                        icon: Icons.psychology,
                        text: 'Analyzing your idea',
                        isCompleted: true,
                      ),
                      _StepDivider(),
                      _StepIndicator(
                        icon: Icons.auto_awesome,
                        text: 'Gathering creative inspiration',
                        isCompleted: true,
                      ),
                      _StepDivider(),
                      _StepIndicator(
                        icon: Icons.movie_creation,
                        text: 'Crafting your scenes',
                        isActive: true,
                      ),
                      _StepDivider(),
                      _StepIndicator(
                        icon: Icons.check_circle,
                        text: 'Finalizing your movie',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'This usually takes about 30 seconds...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isCompleted;
  final bool isActive;

  const _StepIndicator({
    required this.icon,
    required this.text,
    this.isCompleted = false,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCompleted
        ? Colors.green
        : isActive
            ? Theme.of(context).primaryColor
            : Colors.grey;

    return Row(
      children: [
        Icon(
          isCompleted ? Icons.check_circle : icon,
          color: color,
          size: 24,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16,
              color: color,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        if (isActive)
          Container(
            width: 24,
            height: 24,
            padding: const EdgeInsets.all(4),
            child: const CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
      ],
    );
  }
}

class _StepDivider extends StatelessWidget {
  const _StepDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      child: Container(
        width: 1,
        height: 24,
        color: Colors.grey.withOpacity(0.3),
      ),
    );
  }
} 