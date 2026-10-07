# Firebase Schema for Profile Features

## Collection: `users`
Each user document contains profile information and nested data.

### Base User Document Structure
```javascript
users/{userId} {
  // Basic Info
  name: string
  username: string
  email: string
  bio: string
  profilePhoto: string (URL)
  coverPhoto: string (URL)
  city: string
  age: number
  gender: string
  
  // Profile Type
  userType: "aspirant" | "guru" | "wellness"
  
  // Counts
  followersCount: number
  followingCount: number
  postsCount: number
  isPrivate: boolean
  
  // Online Status
  isOnline: boolean
  lastSeen: timestamp
  
  // Common Fields
  interests: [string]
  socialLinks: {
    instagram: string (URL)
    spotify: string (URL)
    telegram: string (URL)
    youtube: string (URL)
  }
  
  // ========== ASPIRANT SPECIFIC ==========
  fitnessTag: string
  fitnessGoals: [string]
  fitnessLevel: string
  healthNotes: [string]
  
  // Last Workouts (Array of objects)
  lastWorkouts: [
    {
      id: string (auto-generated)
      title: string
      intensity: string ("Low" | "Moderate" | "High" | "Fun")
      calories: string (e.g., "650 kcal")
      duration: string (e.g., "45 min")
      date: timestamp
      createdAt: timestamp
    }
  ]
  
  // Events & Challenges (Array of objects)
  eventsChallenges: [
    {
      id: string (auto-generated)
      type: string ("Challenge" | "Goal" | "Event")
      name: string
      status: string ("Active" | "Upcoming" | "Completed" | "Joined")
      date: timestamp (optional)
      createdAt: timestamp
    }
  ]
  
  // Fitness Articles (Array of objects)
  fitnessArticles: [
    {
      id: string (auto-generated)
      title: string
      source: string (e.g., "Blog · 4 min read")
      url: string (optional)
      createdAt: timestamp
    }
  ]
  
  // Fitness Stats (Object)
  fitnessStats: {
    steps: number
    caloriesBurned: number
    workouts: number
    lastUpdated: timestamp
  }
  
  // ========== GURU SPECIFIC ==========
  professionTag: string
  experienceYears: number
  rating: number (0-5)
  reviewCount: number
  
  // Popular Products (Array of objects)
  popularProducts: [
    {
      id: string (auto-generated)
      name: string
      price: string (e.g., "₹549")
      note: string (optional)
      imageUrl: string (optional)
      description: string (optional)
      createdAt: timestamp
    }
  ]
  
  // Last Workouts (Array of objects)
  lastWorkouts: [
    {
      id: string (auto-generated)
      title: string
      clients: string (e.g., "5 clients")
      calories: string (e.g., "2.1K kcal")
      duration: string (e.g., "60 min")
      date: timestamp
      createdAt: timestamp
    }
  ]
  
  // Specialties (Array of strings)
  specialties: [string]
  
  // Certifications (Array of strings)
  certifications: [string]
  
  // Reviews (Array of objects)
  reviews: [
    {
      id: string (auto-generated)
      name: string (reviewer name)
      rating: number (1-5)
      text: string
      createdAt: timestamp
    }
  ]
  
  // Gallery Images (Array of URLs)
  galleryImages: [string]
  
  // ========== WELLNESS SPECIFIC ==========
  business_name: string
  professionTag: string
  experienceYears: number
  rating: number (0-5)
  reviewCount: number
  
  // Popular Products (Array of objects)
  popularProducts: [
    {
      id: string (auto-generated)
      name: string
      price: string (e.g., "₹349")
      tag: string (e.g., "Best Seller" | "Popular")
      imageUrl: string (optional)
      description: string (optional)
      createdAt: timestamp
    }
  ]
  
  // Popular Services (Array of strings)
  popularServices: [string]
  
  // Fitness Events (Array of objects)
  fitnessEvents: [
    {
      id: string (auto-generated)
      title: string
      date: string (e.g., "Sun, 7:00 AM")
      place: string
      imageUrl: string (optional)
      createdAt: timestamp
    }
  ]
  
  // Studio Location
  studioLocation: string (address)
  studioLatitude: number (optional)
  studioLongitude: number (optional)
  
  // Service Slots (Array of objects)
  serviceSlots: [
    {
      id: string (auto-generated)
      title: string
      time: string (e.g., "Mon–Sat • 6–10 AM")
      status: string ("Available" | "Limited Slots" | "Full")
      createdAt: timestamp
    }
  ]
  
  // Reviews (Array of objects)
  reviews: [
    {
      id: string (auto-generated)
      name: string (reviewer name)
      rating: number (1-5)
      text: string
      createdAt: timestamp
    }
  ]
  
  // Gallery Images (Array of URLs)
  galleryImages: [string]
}
```

## Data Structure Notes

### Arrays with IDs
For arrays like `lastWorkouts`, `eventsChallenges`, etc., each item should have:
- `id`: Unique identifier (use `FieldValue.serverTimestamp()` + random string or UUID)
- `createdAt`: Timestamp for sorting
- Other specific fields

### Updating Arrays
When adding/editing/deleting items in arrays:
1. **Add**: Read array, append new item, update document
2. **Edit**: Read array, find item by id, update it, save array
3. **Delete**: Read array, filter out item by id, save array

### Example Update Operations

#### Add a Workout (Aspirant)
```javascript
const workout = {
  id: Date.now().toString(),
  title: "Morning Run",
  intensity: "High",
  calories: "500 kcal",
  duration: "30 min",
  date: FieldValue.serverTimestamp(),
  createdAt: FieldValue.serverTimestamp()
};

await firestore.collection('users').doc(userId).update({
  lastWorkouts: FieldValue.arrayUnion(workout)
});
```

#### Update Fitness Stats
```javascript
await firestore.collection('users').doc(userId).update({
  'fitnessStats.steps': 5000,
  'fitnessStats.caloriesBurned': 450,
  'fitnessStats.workouts': 5,
  'fitnessStats.lastUpdated': FieldValue.serverTimestamp()
});
```

#### Add Social Link
```javascript
await firestore.collection('users').doc(userId).update({
  'socialLinks.instagram': 'https://instagram.com/username'
});
```

## Security Rules Example
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      // Users can read any profile
      allow read: if true;
      
      // Users can only update their own profile
      allow update: if request.auth != null && request.auth.uid == userId;
      
      // Users can create their own profile
      allow create: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

