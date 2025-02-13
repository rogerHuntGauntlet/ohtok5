require('dotenv').config();
const { generateMovieScenes } = require('./index');

// Mock request and response objects
const req = {
  method: 'POST',
  body: {
    movieIdea: "alligators chasing monkeys around while looking for the last human on earth"
  }
};

const res = {
  set: (key, value) => {
    console.log('Setting header:', key, value);
  },
  status: (code) => {
    console.log('Status code:', code);
    return res;
  },
  json: (data) => {
    console.log('Response data:', JSON.stringify(data, null, 2));
  },
  send: (data) => {
    console.log('Sending data:', data);
  }
};

// Test the function
console.log('Starting test...');
console.log('Using environment variables:', {
  hasOpenAI: !!process.env.OPENAI_API_KEY,
  hasPinecone: !!process.env.PINECONE_API_KEY
});

generateMovieScenes(req, res).catch(error => {
  console.error('Test failed:', error);
}); 