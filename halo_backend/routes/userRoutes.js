import express from "express";
import { listUsers, getUserProfile, updateUserProfile, searchUsers } from "../controllers/userController.js";

const router = express.Router();

// Route to list users
router.get("/", listUsers);

// Route to update a user's profile
router.put("/:uid", updateUserProfile);

// Route to search users by username
router.get("/search/:username", searchUsers);

// Route to search users with query params (?q=&field=email)
router.get("/search", searchUsers);

// Route to fetch a user's profile (placed after more specific routes)
router.get("/:uid", getUserProfile);

export default router;
