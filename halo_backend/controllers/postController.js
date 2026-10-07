import { db } from "../config/firebaseConfig.js";

const POSTS_COLLECTION = "posts";

// Create a new post
export const createPost = async (req, res) => {
  try {
    const { text, imageUrl } = req.body;
    const userId = req.user?.uid;

    if (!userId) return res.status(401).json({ message: "Unauthorized" });
    if (!text && !imageUrl) return res.status(400).json({ message: "Post must include text or imageUrl" });

    const now = new Date();
    const docRef = await db.collection(POSTS_COLLECTION).add({
      userId,
      text: text || "",
      imageUrl: imageUrl || "",
      likes: [],
      likeCount: 0,
      createdAt: now,
      updatedAt: now,
    });

    const created = await docRef.get();
    return res.status(201).json({ id: docRef.id, ...created.data() });
  } catch (error) {
    console.error("Error creating post:", error);
    return res.status(500).json({ message: "Server error" });
  }
};

// List posts with pagination (?limit=20&cursor=<docId>)
export const listPosts = async (req, res) => {
  try {
    const limit = Math.max(1, Math.min(parseInt(req.query.limit || "20", 10) || 20, 50));
    const cursor = req.query.cursor;

    let query = db.collection(POSTS_COLLECTION).orderBy("createdAt", "desc").limit(limit);

    if (cursor) {
      const cursorDoc = await db.collection(POSTS_COLLECTION).doc(cursor).get();
      if (cursorDoc.exists) {
        query = query.startAfter(cursorDoc);
      }
    }

    const snapshot = await query.get();
    const posts = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
    const nextCursor = snapshot.docs.length ? snapshot.docs[snapshot.docs.length - 1].id : null;

    return res.status(200).json({ items: posts, nextCursor });
  } catch (error) {
    console.error("Error listing posts:", error);
    return res.status(500).json({ message: "Server error" });
  }
};

// Get a single post
export const getPost = async (req, res) => {
  try {
    const { id } = req.params;
    const doc = await db.collection(POSTS_COLLECTION).doc(id).get();
    if (!doc.exists) return res.status(404).json({ message: "Post not found" });
    return res.status(200).json({ id: doc.id, ...doc.data() });
  } catch (error) {
    console.error("Error getting post:", error);
    return res.status(500).json({ message: "Server error" });
  }
};

// Update a post (owner only)
export const updatePost = async (req, res) => {
  try {
    const { id } = req.params;
    const { text, imageUrl } = req.body;
    const userId = req.user?.uid;

    const ref = db.collection(POSTS_COLLECTION).doc(id);
    const snapshot = await ref.get();
    if (!snapshot.exists) return res.status(404).json({ message: "Post not found" });
    const data = snapshot.data();
    if (data.userId !== userId) return res.status(403).json({ message: "Forbidden" });

    const update = {
      ...(text !== undefined ? { text } : {}),
      ...(imageUrl !== undefined ? { imageUrl } : {}),
      updatedAt: new Date(),
    };
    await ref.set(update, { merge: true });
    const updated = await ref.get();
    return res.status(200).json({ id: ref.id, ...updated.data() });
  } catch (error) {
    console.error("Error updating post:", error);
    return res.status(500).json({ message: "Server error" });
  }
};

// Delete a post (owner only)
export const deletePost = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user?.uid;

    const ref = db.collection(POSTS_COLLECTION).doc(id);
    const snapshot = await ref.get();
    if (!snapshot.exists) return res.status(404).json({ message: "Post not found" });
    const data = snapshot.data();
    if (data.userId !== userId) return res.status(403).json({ message: "Forbidden" });

    await ref.delete();
    return res.status(204).send();
  } catch (error) {
    console.error("Error deleting post:", error);
    return res.status(500).json({ message: "Server error" });
  }
};

// Toggle like on a post
export const toggleLike = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user?.uid;
    if (!userId) return res.status(401).json({ message: "Unauthorized" });

    const ref = db.collection(POSTS_COLLECTION).doc(id);
    const snapshot = await ref.get();
    if (!snapshot.exists) return res.status(404).json({ message: "Post not found" });
    const data = snapshot.data();
    const likes = Array.isArray(data.likes) ? data.likes : [];
    const hasLiked = likes.includes(userId);

    const updatedLikes = hasLiked ? likes.filter((u) => u !== userId) : [...likes, userId];
    const likeCount = updatedLikes.length;

    await ref.set({ likes: updatedLikes, likeCount, updatedAt: new Date() }, { merge: true });
    const updated = await ref.get();
    return res.status(200).json({ id: ref.id, ...updated.data() });
  } catch (error) {
    console.error("Error toggling like:", error);
    return res.status(500).json({ message: "Server error" });
  }
};


