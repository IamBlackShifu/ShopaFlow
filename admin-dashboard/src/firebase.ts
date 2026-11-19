import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';

export const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY || 'AIzaSyDzQz-9y1ay96_VN5uEQmjbi4z7WxB9rLo',
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN || 'shopaflow.firebaseapp.com',
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID || 'shopaflow',
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET || 'shopaflow.firebasestorage.app',
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID || '532922145349',
  appId: import.meta.env.VITE_FIREBASE_APP_ID || '1:532922145349:web:f5389f70f7371edbb8a12c',
};

export const firebaseApp = initializeApp(firebaseConfig);
export const auth = getAuth(firebaseApp);
export const db = getFirestore(firebaseApp);
