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
admin.initializeApp();

// Import the RAG function
const ragFunctions = require('./rag_functions');

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
  // Enable CORS
  res.set('Access-Control-Allow-Origin', '*');
  
  if (req.method === 'OPTIONS') {
    // Send response to OPTIONS requests
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.status(204).send('');
    return;
  }

  try {
    console.log('Received movie idea:', req.body.movieIdea);
    
    // Get API keys from environment or config
    let PINECONE_API_KEY, OPENAI_API_KEY;
    
    if (process.env.NODE_ENV === 'production') {
      // In production, use Firebase config
      const config = functions.params;
      console.log('Available config params:', Object.keys(config));
      PINECONE_API_KEY = config.pinecone?.apikey;
      OPENAI_API_KEY = config.openai?.apikey;
    } else {
      // In development, use environment variables
      PINECONE_API_KEY = process.env.PINECONE_API_KEY;
      OPENAI_API_KEY = process.env.OPENAI_API_KEY;
    }

    console.log('API Keys loaded:', { 
      hasPinecone: !!PINECONE_API_KEY, 
      hasOpenAI: !!OPENAI_API_KEY,
      pineconeKeyLength: PINECONE_API_KEY ? PINECONE_API_KEY.length : 0,
      openaiKeyLength: OPENAI_API_KEY ? OPENAI_API_KEY.length : 0,
      environment: process.env.NODE_ENV || 'development'
    });

    if (!PINECONE_API_KEY || !OPENAI_API_KEY) {
      console.error('Missing required API keys:', {
        hasPinecone: !!PINECONE_API_KEY,
        hasOpenAI: !!OPENAI_API_KEY,
        availableConfig: process.env.NODE_ENV === 'production' ? functions.params : { PINECONE_API_KEY, OPENAI_API_KEY }
      });
      return res.status(500).json({ error: 'Server configuration error - Missing API keys' });
    }
    
    // Initialize Pinecone
    const pc = new Pinecone({
      apiKey: PINECONE_API_KEY,
      environment: 'aped-4627-b74a'
    });

    // List all indexes to verify connection
    console.log('Listing Pinecone indexes...');
    const indexes = await pc.listIndexes();
    console.log('Available indexes:', indexes);

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
    const stats = await index.describeIndexStats();
    console.log('Index stats:', stats);
    
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
      .split('\n')
      .filter(line => line.trim())
      .map((line, index) => {
        const sceneText = line.replace(/^\d+\.\s*/, '').trim();
        return {
          id: index + 1,
          text: sceneText,
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

// Export all functions
module.exports = {
  ...require('./functions')
};
