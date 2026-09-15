import { initializeApp } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-app.js";
import { getAuth } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js";
import { getFunctions } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-functions.js";

// Same public web config as lib/firebase_options.dart — safe to expose,
// access is governed by Firestore/Auth rules and the deleteMyAccount
// function itself, not by keeping this secret.
const firebaseConfig = {
  apiKey: "AIzaSyB-XGWe72H5NZPmTX9ck_y33RRqODyZp94",
  authDomain: "podium-9b4bf.firebaseapp.com",
  projectId: "podium-9b4bf",
  storageBucket: "podium-9b4bf.firebasestorage.app",
  messagingSenderId: "392494713569",
  appId: "1:392494713569:web:188ae0ad2050cadbcf45a0",
  measurementId: "G-VBQPPJGQWC",
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const functions = getFunctions(app);
