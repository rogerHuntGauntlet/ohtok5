import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'dart:async';

class OpenAIService {
  final String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  late final String _apiKey;

  OpenAIService() {
    _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
  }

  Future<String> updateSceneText({
    required String originalScene,
    required String notes,
    required String movieIdea,
    required StreamController<String> progressController,
  }) async {
    try {
      // Step 1: Analyzing
      progressController.add('analyzing');
      await Future.delayed(const Duration(seconds: 1));

      // Step 2: Processing
      progressController.add('processing');
      
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a creative movie script writer. Your task is to update a movie scene based on the provided notes while maintaining consistency with the overall movie idea.'
            },
            {
              'role': 'user',
              'content': '''Movie Idea: $movieIdea

Original Scene: $originalScene

Notes for changes: $notes

Please rewrite the scene incorporating these notes. Keep the response focused and only return the new scene text.'''
            }
          ],
          'temperature': 0.7,
          'max_tokens': 500,
        }),
      );

      if (response.statusCode != 200) {
        throw 'Failed to update scene: ${response.body}';
      }

      // Step 3: Finalizing
      progressController.add('finalizing');
      await Future.delayed(const Duration(milliseconds: 500));

      final data = json.decode(response.body);
      return data['choices'][0]['message']['content'].trim();
    } catch (e) {
      throw 'Failed to update scene: $e';
    }
  }
} 