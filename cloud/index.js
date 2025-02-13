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
admin.initializeApp();

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

exports.onUserCreated = onDocumentCreated('users/{userId}', async (event) => {
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
