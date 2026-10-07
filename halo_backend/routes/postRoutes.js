import express from "express";
import { authMiddleware } from "../middleware/auth.js";
import { createPost, listPosts, getPost, updatePost, deletePost, toggleLike } from "../controllers/postController.js";

const router = express.Router();

// Public: list posts
router.get("/", listPosts);

// Public: get single post
router.get("/:id", getPost);

// Authenticated: create, update, delete, like
router.post("/", authMiddleware, createPost);
router.put("/:id", authMiddleware, updatePost);
router.delete("/:id", authMiddleware, deletePost);
router.post("/:id/like", authMiddleware, toggleLike);

export default router;


