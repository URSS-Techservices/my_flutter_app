import admin from "firebase-admin";
import { createRequire } from "module";
import "dotenv/config";

const require = createRequire(import.meta.url);
const serviceAccount = require("../serviceAccountKey.json");

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: process.env.FIREBASE_STORAGE_BUCKET || "halo-app.appspot.com",
});

// Export Firestore database and Storage bucket to use in other files
export const db = admin.firestore();
export const bucket = admin.storage().bucket();

// Also export the initialized admin instance for auth verification usage
export default admin;