// Firebase Web Configuration
const firebaseConfig = {
  apiKey: "AIzaSyB...", // Replace with your actual API key
  authDomain: "djinnan.firebaseapp.com",
  projectId: "djinnan",
  storageBucket: "djinnan.appspot.com",
  messagingSenderId: "123456789",
  appId: "1:123456789:web:abcdef123456",
  measurementId: "G-XXXXXXXXX"
};

// Initialize Firebase
if (!firebase.apps.length) {
  firebase.initializeApp(firebaseConfig);
}

// Export Firebase services
export const auth = firebase.auth();
export const db = firebase.firestore();
export const storage = firebase.storage();
export const messaging = firebase.messaging();
