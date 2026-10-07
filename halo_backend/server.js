import express from "express";
import cors from "cors";
import "dotenv/config";
import userRoutes from "./routes/userRoutes.js";
import postRoutes from "./routes/postRoutes.js";
import { db } from "./config/firebaseConfig.js";
import { v2 as cloudinary } from "cloudinary";
import multer from "multer";
import fs from "fs"; // ✅ fixed "form" → "from"

const app = express();
const PORT = process.env.PORT || 5000;

// ✅ Middleware
app.use(cors());
app.use(express.json());

// ✅ Cloudinary config (using environment variables)
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,

  api_secret: process.env.CLOUDINARY_API_SECRET,
});

// ✅ Routes
app.use("/users", userRoutes);
app.use("/posts", postRoutes);

// ✅ Health check
app.get("/", (req, res) => {
  res.send("Halo Backend is running!");
});

// ✅ Test Cloudinary connection
app.get("/test-cloudinary", async (req, res) => {
  try {
    const result = await cloudinary.api.ping();
    res.json({ message: "Cloudinary connected successfully!", result });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Cloudinary connection failed" });
  }
});

// ✅ Image upload route
const upload = multer({ dest: "uploads/" }); // temporary storage

app.post("/upload", upload.single("image"), async (req, res) => {
  try {
    // Upload image to Cloudinary
    const result = await cloudinary.uploader.upload(req.file.path, {
      folder: "halo_uploads",
    });

    // Delete the temporary file
    fs.unlinkSync(req.file.path);

    // Optional: Save image info to Firestore
    await db.collection("uploads").add({
      imageUrl: result.secure_url,
      createdAt: new Date(),
    });

    res.json({
      message: "Image uploaded successfully!",
      url: result.secure_url,
    });
  } catch (error) {
    console.error("Upload error:", error);
    res.status(500).json({ error: "Upload failed", details: error.message });
  }
});

// ✅ Start server
app.listen(PORT, () => {
  console.log(`✅ Server is running on port ${PORT}`);
});

export default cloudinary;
