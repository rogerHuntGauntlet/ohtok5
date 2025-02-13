import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/tutorial_overlay.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey _createVideoButtonKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OHFtok'),
        actions: [
          IconButton(
            onPressed: () {
              Provider.of<AuthService>(context, listen: false).signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TutorialOverlay(
              featureKey: 'create_video',
              title: 'Create Your First Video',
              description: 'Tap here to start recording your first video!',
              targetPosition: _getCreateButtonPosition(),
              targetSize: const Size(56, 56),
              child: FloatingActionButton(
                key: _createVideoButtonKey,
                onPressed: () {
                  // Handle video creation
                },
                child: const Icon(Icons.video_call),
              ),
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
} 