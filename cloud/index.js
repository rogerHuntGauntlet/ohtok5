/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {onRequest} = require("firebase-functions/v2/https");
const functions = require('firebase-functions/v2');
const logger = require("firebase-functions/logger");
const admin = require('firebase-admin');
const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const { Pinecone } = require('@pinecone-database/pinecone');
const { OpenAIEmbeddings } = require('@langchain/openai');
const { OpenAI } = require('@langchain/openai');
const { PromptTemplate } = require('@langchain/core/prompts');
const { LLMChain } = require('langchain/chains');
const { Replicate } = require('replicate');
const axios = require('axios');
const { getStorage } = require('firebase-admin/storage');
const { FieldValue } = require('firebase-admin/firestore');
const { defineSecret } = require('firebase-functions/params');

admin.initializeApp();

// Import the RAG function
//const ragFunctions = require('./rag_functions');

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

// Export the generateMovieScenes function as an HTTP function
exports.generateMovieScenes = functions.https.onRequest({
  cors: true,
  maxInstances: 10,
  memory: '1GiB',
  cpu: 1,
  timeoutSeconds: 120
}, async (req, res) => {
  try {
    console.log('Received movie idea:', req.body.movieIdea);
    
    // Get API keys from environment variables
    const PINECONE_API_KEY = process.env.PINECONE_API_KEY;
    const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

    console.log('Environment variables loaded:', { 
      hasPinecone: !!PINECONE_API_KEY, 
      hasOpenAI: !!OPENAI_API_KEY,
      pineconeKeyLength: PINECONE_API_KEY ? PINECONE_API_KEY.length : 0,
      openaiKeyLength: OPENAI_API_KEY ? OPENAI_API_KEY.length : 0
    });

    if (!PINECONE_API_KEY || !OPENAI_API_KEY) {
      console.error('Missing required API keys');
      return res.status(500).json({ error: 'Server configuration error - Missing API keys' });
    }
    
    // Initialize Pinecone
    const pc = new Pinecone({
      apiKey: PINECONE_API_KEY
    });

    // List all indexes to verify connection
    console.log('Listing Pinecone indexes...');
    try {
      const indexes = await pc.listIndexes();
      console.log('Available indexes:', indexes);
    } catch (error) {
      console.error('Error listing Pinecone indexes:', error);
      // Continue anyway as we know the index exists
    }

    const { movieIdea } = req.body;
    if (!movieIdea) {
      return res.status(400).json({ error: 'Movie idea is required' });
    }

    console.log('Generating embeddings...');
    // Get embeddings for the movie idea
    const embeddings = new OpenAIEmbeddings({
      openAIApiKey: OPENAI_API_KEY,
    });
    
    const queryEmbedding = await embeddings.embedQuery(movieIdea);

    console.log('Querying Pinecone...');
    // Query Pinecone for relevant context
    const index = pc.index('phd-knowledge');

    // Get index stats to verify content
    try {
      const stats = await index.describeIndexStats();
      console.log('Index stats:', stats);
    } catch (error) {
      console.error('Error getting index stats:', error);
      // Continue anyway
    }
    
    console.log('Attempting query with:', {
      vector: queryEmbedding.slice(0, 5), // Log just first 5 dimensions for brevity
      topK: 5,
      includeMetadata: true
    });

    const queryResponse = await index.namespace('witt_works').query({
      vector: queryEmbedding,
      topK: 5,
      includeMetadata: true
    });

    // Build context from similar entries with better error handling
    const contextParts = [];
    if (queryResponse.matches && queryResponse.matches.length > 0) {
      for (const match of queryResponse.matches) {
        console.log('Processing match score:', match.score);
        
        if (!match.metadata) {
          console.log('Match missing metadata:', match);
          continue;
        }

        if (match.metadata.text) {
          contextParts.push(`- ${match.metadata.text}`);
          if (match.metadata.source) {
            contextParts.push(`  Source: ${match.metadata.source}`);
          }
          contextParts.push('');
        } else {
          console.log('Match metadata missing text:', match.metadata);
        }
      }
    } else {
      console.log('No matches found in Pinecone response');
    }

    const context = contextParts.join('\n');
    console.log('Context built:', context || 'No context available');

    console.log('Generating scenes with OpenAI...');
    // Generate scenes using OpenAI
    const prompt = PromptTemplate.fromTemplate(`
      You are a creative movie scene generator. Using the provided movie idea and the knowledge from our database,
      generate a list of compelling scenes that would make an engaging short-form video.
      Each scene should be concise but descriptive, and incorporate relevant elements from the provided knowledge.

      Movie Idea: {movieIdea}
      
      Knowledge Context (use this to enhance the scenes with relevant details):
      {context}
      
      Generate 5-7 scenes that would make this movie idea work well as a short-form video.
      Each scene should:
      1. Be visually descriptive and engaging
      2. Incorporate elements from the knowledge context if relevant
      3. Follow a clear narrative arc
      4. Be suitable for short-form video format
      
      Format each scene as a numbered list.
    `);

    const model = new OpenAI({
      openAIApiKey: OPENAI_API_KEY,
      temperature: 0.7,
      modelName: 'gpt-4',
    });

    const chain = new LLMChain({
      prompt: prompt,
      llm: model,
    });

    const response = await chain.call({
      movieIdea: movieIdea,
      context: context,
    });

    console.log('Raw response:', response);

    // Parse the response into a structured list of scenes
    const scenes = response.text
      .split(/\d+\.\s+/)  // Split by numbers followed by a period and whitespace
      .filter(text => text.trim())  // Remove empty entries
      .map((sceneText, index) => {
        // Extract scene title and description if present
        const match = sceneText.match(/^(Scene \w+):\s*(.*)/s);
        const title = match ? match[1] : `Scene ${index + 1}`;
        const description = match ? match[2].trim() : sceneText.trim();
        
        return {
          id: index + 1,
          title: title,
          text: description,
          duration: 15, // Default duration in seconds
          type: 'scene',
          status: 'pending'
        };
      });

    console.log('Final scenes:', scenes);
    res.status(200).json({ 
      scenes,
      metadata: {
        totalScenes: scenes.length,
        movieIdea: movieIdea,
        generatedAt: new Date().toISOString()
      }
    });
  } catch (error) {
    console.error('Error details:', {
      message: error.message,
      stack: error.stack,
      name: error.name
    });
    res.status(500).json({ 
      error: 'Failed to generate movie scenes. Please try again.',
      details: error.message
    });
  }
}); 

// Export the onUserCreated function with proper configuration


/**
 exports.generateMovieScenes = functions.https.onRequest({
  cors: true,
  maxInstances: 10,
  memory: '1GiB',
  cpu: 1,
  timeoutSeconds: 120
}, async (req, res) => {
 */

exports.onUserCreated = functions.firestore.onDocumentCreated({
  document: 'users/{userId}',
  memory: '256MiB',
  cpu: 0.5,
  maxInstances: 10,
  timeoutSeconds: 30
}, async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
        return;
    }

    const userData = snapshot.data();
    const userId = event.params.userId;
    
    logger.info("Processing new user profile:", userData.email);

    try {
        // Update the document with additional fields
        await snapshot.ref.update({
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            lastLogin: admin.firestore.FieldValue.serverTimestamp(),
            hasCompletedOnboarding: false,
            profileCompletion: 0,
            tokens: 0,
            emailVerified: false,
            role: 'user'
        });
        
        logger.info("Successfully processed profile for user:", userData.email);
    } catch (error) {
        logger.error("Error processing user profile:", error);
        throw error;
    }
});

// Define secrets
const REPLICATE_API_TOKEN = defineSecret('REPLICATE_API_TOKEN');

// Constants for progress tracking
const PROGRESS_STAGES = {
  ANALYZING: { progress: 0.1, message: 'Analyzing scene' },
  GENERATING: { progress: 0.3, message: 'Generating video frames' },
  PROCESSING: { progress: 0.6, message: 'Processing video' },
  DOWNLOADING: { progress: 0.8, message: 'Downloading video' },
  UPLOADING: { progress: 0.9, message: 'Uploading to storage' },
  COMPLETED: { progress: 1.0, message: 'Video ready!' }
};

// Helper function to get server timestamp
const getServerTimestamp = () => FieldValue.serverTimestamp();

// Helper function to generate standard video metadata
const generateVideoMetadata = (videoId, jobData, sourceType = 'ai') => ({
  contentType: 'video/mp4',
  metadata: {
    videoId,
    movieId: jobData.movieId,
    sceneId: jobData.sceneId,
    userId: jobData.userId,
    uploadedAt: new Date().toISOString(),
    sourceType,
    ...(sourceType === 'ai' && {
      predictionId: jobData.predictionId,
      description: jobData.sceneText
    })
  }
});

// Helper function to update scene document
const updateSceneWithVideo = async (movieId, sceneId, videoUrl, videoId, sourceType = 'ai') => {
  const sceneRef = admin.firestore()
    .collection('movies')
    .doc(movieId)
    .collection('scenes')
    .doc(sceneId);

  await sceneRef.update({
    videoUrl,
    videoId,
    status: 'completed',
    videoType: sourceType,
    updatedAt: getServerTimestamp()
  });
};

// Generate video for a scene


exports.generateSingleScene = functions.https.onRequest({
  cors: true,
  maxInstances: 10,
  memory: '1GiB',
  cpu: 1,
  timeoutSeconds: 250
}, async (req, res) => {
  // Enable CORS
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  try {
    console.log('Received generate request:', JSON.stringify(req.body, null, 2));
    console.log('Environment variables:', {
      hasReplicateToken: !!process.env.REPLICATE_API_TOKEN,
      tokenLength: process.env.REPLICATE_API_TOKEN ? process.env.REPLICATE_API_TOKEN.length : 0
    });
    
    const { scene, userId } = req.body;
    if (!scene || !scene.text || !userId) {
      return res.status(400).json({ error: 'Scene text and userId are required' });
    }

    const replicateToken = process.env.REPLICATE_API_TOKEN;
    if (!replicateToken) {
      console.error('Missing Replicate API token');
      return res.status(500).json({ error: 'Server configuration error - Missing Replicate API token' });
    }

    // Test Replicate API connection
    try {
      const testResponse = await axios.get('https://api.replicate.com/v1/models', {
        headers: {
          'Authorization': `Bearer ${replicateToken}`,
          'Content-Type': 'application/json'
        }
      });
      console.log('Replicate API connection test successful');
    } catch (apiError) {
      console.error('Replicate API connection test failed:', apiError.response?.data || apiError.message);
      return res.status(500).json({ 
        error: 'Failed to connect to Replicate API',
        details: apiError.response?.data || apiError.message
      });
    }

    // Create prediction using Replicate API
    console.log('Creating prediction with text:', scene.text);
    const predictionResponse = await axios.post('https://api.replicate.com/v1/predictions', {
      version: "luma/ray",
      input: { prompt: scene.text }
    }, {
      headers: {
        'Authorization': `Bearer ${replicateToken}`,
        'Content-Type': 'application/json'
      }
    });

    const predictionId = predictionResponse.data.id;
    console.log('Prediction created:', predictionId);

    // Create job document in Firestore
    const jobRef = admin.firestore().collection('videoJobs').doc(predictionId);
    await jobRef.set({
      status: 'analyzing',
      progress: PROGRESS_STAGES.ANALYZING.progress,
      message: PROGRESS_STAGES.ANALYZING.message,
      sceneId: scene.documentId,
      movieId: scene.movieId,
      userId,
      sceneText: scene.text,
      predictionId,
      createdAt: getServerTimestamp(),
      updatedAt: getServerTimestamp()
    });

    console.log('Job document created in Firestore');
    res.status(200).json({
      success: true,
      jobId: predictionId,
      status: 'analyzing',
      progress: PROGRESS_STAGES.ANALYZING.progress
    });

  } catch (error) {
    console.error('Error initiating video generation:', error.response?.data || error);
    res.status(500).json({
      error: 'Failed to initiate video generation',
      details: error.response?.data || error.message
    });
  }
});

// Check generation status
exports.getGenerationStatus = functions.https.onRequest({
  cors: true,
  maxInstances: 10,
  memory: '1GiB',
  cpu: 1,
  timeoutSeconds: 120
}, async (req, res) => {
  try {
    const { jobId } = req.body;
    if (!jobId) {
      return res.status(400).json({ error: 'jobId is required' });
    }

    // Get job data from Firestore
    const jobRef = admin.firestore().collection('videoJobs').doc(jobId);
    const jobDoc = await jobRef.get();
    
    if (!jobDoc.exists) {
      return res.status(404).json({ error: 'Job not found' });
    }

    const jobData = jobDoc.data();
    if (jobData.status === 'completed' && jobData.videoUrl) {
      return res.status(200).json({
        status: 'completed',
        progress: PROGRESS_STAGES.COMPLETED.progress,
        videoUrl: jobData.videoUrl,
        videoId: jobData.videoId
      });
    }

    // Check Replicate status
    const replicateToken = process.env.REPLICATE_API_TOKEN;
    const prediction = await axios.get(`https://api.replicate.com/v1/predictions/${jobId}`, {
      headers: { 'Authorization': `Bearer ${replicateToken}` }
    });

    console.log('Replicate status:', prediction.data.status);

    switch (prediction.data.status) {
      case 'starting':
        await jobRef.update({
          status: 'analyzing',
          progress: PROGRESS_STAGES.ANALYZING.progress,
          message: PROGRESS_STAGES.ANALYZING.message,
          updatedAt: getServerTimestamp()
        });
        break;

      case 'processing':
        await jobRef.update({
          status: 'generating',
          progress: PROGRESS_STAGES.GENERATING.progress,
          message: PROGRESS_STAGES.GENERATING.message,
          updatedAt: getServerTimestamp()
        });
        break;

      case 'succeeded':
        if (!jobData.videoUrl) {
          console.log('Processing completed video...');
          
          // Download video from Replicate
          const replicateVideoUrl = prediction.data.output;
          const videoResponse = await axios.get(replicateVideoUrl, {
            responseType: 'arraybuffer',
            headers: { 'Authorization': `Bearer ${replicateToken}` }
          });

          // Generate videoId and prepare for storage
          const videoId = admin.firestore().collection('videos').doc().id;
          const bucket = getStorage().bucket();
          const file = bucket.file(`${videoId}.mp4`);

          // Upload to Firebase Storage
          await file.save(videoResponse.data, {
            metadata: generateVideoMetadata(videoId, jobData)
          });

          // Get permanent download URL
          const videoUrl = await file.getDownloadURL();

          // Update job document
          await jobRef.update({
            status: 'completed',
            progress: PROGRESS_STAGES.COMPLETED.progress,
            message: PROGRESS_STAGES.COMPLETED.message,
            videoUrl,
            videoId,
            completedAt: getServerTimestamp(),
            updatedAt: getServerTimestamp()
          });

          // Update scene document
          await updateSceneWithVideo(
            jobData.movieId,
            jobData.sceneId,
            videoUrl,
            videoId
          );

          return res.status(200).json({
            status: 'completed',
            progress: PROGRESS_STAGES.COMPLETED.progress,
            videoUrl,
            videoId
          });
        }
        break;

      case 'failed':
        await jobRef.update({
          status: 'failed',
          error: prediction.data.error || 'Video generation failed',
          updatedAt: getServerTimestamp()
        });
        return res.status(500).json({
          status: 'failed',
          error: prediction.data.error || 'Video generation failed'
        });

      case 'canceled':
        await jobRef.update({
          status: 'failed',
          error: 'Video generation was canceled',
          updatedAt: getServerTimestamp()
        });
        return res.status(500).json({
          status: 'failed',
          error: 'Video generation was canceled'
        });
    }

    // Return current status
    res.status(200).json({
      status: jobData.status,
      progress: jobData.progress,
      message: jobData.message
    });

  } catch (error) {
    console.error('Error checking generation status:', error);
    res.status(500).json({
      error: 'Failed to check video generation status',
      details: error.message
    });
  }
});
