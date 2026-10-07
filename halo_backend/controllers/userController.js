import { db } from "../config/firebaseConfig.js";

// List users with optional limit (default 20)
export const listUsers = async (req, res) => {
  try {
    const limit = Math.max(1, Math.min(parseInt(req.query.limit || "20", 10) || 20, 100));
    const cursor = req.query.cursor;

    let query = db.collection("users").orderBy("createdAt", "desc").limit(limit);
    if (cursor) {
      const cursorDoc = await db.collection("users").doc(cursor).get();
      if (cursorDoc.exists) {
        query = query.startAfter(cursorDoc);
      }
    }

    const snapshot = await query.get();
    const users = snapshot.docs.map((doc) => ({ uid: doc.id, ...doc.data() }));
    const nextCursor = snapshot.docs.length ? snapshot.docs[snapshot.docs.length - 1].id : null;
    return res.status(200).json({ items: users, nextCursor });
  } catch (error) {
    console.error("Error listing users:", error);
    return res.status(500).json({ message: "Server error" });
  }
};

// Fetch user profile
export const getUserProfile = async (req, res) => {
  try {
    const uid = req.params.uid;
    const userDoc = await db.collection("users").doc(uid).get();

    if (!userDoc.exists) {
      return res.status(404).json({ message: "User not found" });
    }

    res.status(200).json(userDoc.data());
  } catch (error) {
    console.error("Error fetching user:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// Update user profile
export const updateUserProfile = async (req, res) => {
  try {
    const uid = req.params.uid;
    const { username, bio, photoUrl } = req.body;

    const userRef = db.collection("users").doc(uid);
    // Merge to create the doc if it doesn't exist and avoid overwriting other fields
    await userRef.set(
      {
        ...(username !== undefined ? { username } : {}),
        ...(bio !== undefined ? { bio } : {}),
        ...(photoUrl !== undefined ? { photoUrl } : {}),
        updatedAt: new Date(),
      },
      { merge: true }
    );

    const updatedUser = await userRef.get();
    res.status(200).json(updatedUser.data());
  } catch (error) {
    console.error("Error updating user:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// Search users by username
export const searchUsers = async (req, res) => {
  try {
    // Support both legacy param style and query params
    const legacyUsername = req.params.username;
    const q = (req.query.q || legacyUsername || "").toString();
    const field = (req.query.field || (legacyUsername ? "username" : "email")).toString();

    if (!q || q.length < 2) {
      return res.status(400).json({ message: "Missing or too-short search query (min 2 chars)" });
    }

    const usersRef = db.collection("users");

    // Helper to run prefix search on a specific field
    const runPrefixSearch = async (fieldName) => {
      return await usersRef
        .where(fieldName, ">=", q)
        .where(fieldName, "<=", q + "\uf8ff")
        .get();
    };

    let snapshot = await runPrefixSearch(field);

    // Fallback: if no results searching by username, try email
    if (snapshot.empty && field !== "email") {
      snapshot = await runPrefixSearch("email");
    }

    if (snapshot.empty) {
      return res.status(404).json({ message: "No users found" });
    }

    const results = snapshot.docs.map(doc => ({ uid: doc.id, ...doc.data() }));
    return res.status(200).json(results);
  } catch (error) {
    console.error("Error searching users:", error);
    res.status(500).json({ message: "Server error" });
  }
};
