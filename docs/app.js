import { initializeApp } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-app.js";
import { getAuth, signInWithEmailAndPassword, sendPasswordResetEmail, signOut } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js";
import { getFunctions, httpsCallable } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-functions.js";

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
const auth = getAuth(app);
const functions = getFunctions(app);
const deleteMyAccount = httpsCallable(functions, "deleteMyAccount");

const stepSignin = document.getElementById("step-signin");
const stepConfirm = document.getElementById("step-confirm");
const stepDone = document.getElementById("step-done");

const signinBtn = document.getElementById("signin-btn");
const forgotBtn = document.getElementById("forgot-btn");
const signinMsg = document.getElementById("signin-msg");
const confirmEmail = document.getElementById("confirm-email");
const confirmCheck = document.getElementById("confirm-check");
const deleteBtn = document.getElementById("delete-btn");
const cancelBtn = document.getElementById("cancel-btn");
const deleteMsg = document.getElementById("delete-msg");

function showStep(step) {
  for (const el of [stepSignin, stepConfirm, stepDone]) el.classList.remove("active");
  step.classList.add("active");
}

function showMessage(container, text, kind) {
  container.innerHTML = `<div class="msg ${kind}">${text}</div>`;
}

function authErrorMessage(err) {
  switch (err.code) {
    case "auth/invalid-email":
      return "Adresse e-mail invalide.";
    case "auth/invalid-credential":
    case "auth/wrong-password":
    case "auth/user-not-found":
      return "E-mail ou mot de passe incorrect.";
    case "auth/too-many-requests":
      return "Trop de tentatives — réessayez dans quelques minutes.";
    default:
      return "Une erreur est survenue. Réessayez.";
  }
}

stepSignin.addEventListener("submit", async (e) => {
  e.preventDefault();
  signinMsg.innerHTML = "";
  const email = document.getElementById("email").value.trim();
  const password = document.getElementById("password").value;
  if (!email || !password) return;

  signinBtn.disabled = true;
  signinBtn.textContent = "Connexion…";
  try {
    const cred = await signInWithEmailAndPassword(auth, email, password);
    confirmEmail.textContent = cred.user.email ?? email;
    showStep(stepConfirm);
  } catch (err) {
    showMessage(signinMsg, authErrorMessage(err), "error");
  } finally {
    signinBtn.disabled = false;
    signinBtn.textContent = "Se connecter";
  }
});

forgotBtn.addEventListener("click", async () => {
  signinMsg.innerHTML = "";
  const email = document.getElementById("email").value.trim();
  if (!email) {
    showMessage(signinMsg, "Entrez votre adresse e-mail ci-dessus, puis cliquez à nouveau.", "error");
    return;
  }

  forgotBtn.disabled = true;
  forgotBtn.textContent = "Envoi…";
  try {
    await sendPasswordResetEmail(auth, email);
  } catch (err) {
    // Don't leak whether the address has an account — show the same
    // success message either way (only a malformed address is reported).
    if (err.code === "auth/invalid-email") {
      showMessage(signinMsg, authErrorMessage(err), "error");
      forgotBtn.disabled = false;
      forgotBtn.textContent = "Mot de passe oublié ?";
      return;
    }
  }
  showMessage(signinMsg, "Si un compte existe avec cette adresse, un e-mail de réinitialisation vient d'être envoyé.", "success");
  forgotBtn.disabled = false;
  forgotBtn.textContent = "Mot de passe oublié ?";
});

confirmCheck.addEventListener("change", () => {
  deleteBtn.disabled = !confirmCheck.checked;
});

cancelBtn.addEventListener("click", async () => {
  await signOut(auth).catch(() => {});
  confirmCheck.checked = false;
  deleteBtn.disabled = true;
  deleteMsg.innerHTML = "";
  showStep(stepSignin);
});

deleteBtn.addEventListener("click", async () => {
  deleteMsg.innerHTML = "";
  deleteBtn.disabled = true;
  deleteBtn.textContent = "Suppression en cours…";
  try {
    await deleteMyAccount();
    await signOut(auth).catch(() => {});
    showStep(stepDone);
  } catch (err) {
    showMessage(deleteMsg, "La suppression a échoué. Réessayez ou contactez-nous par e-mail.", "error");
    deleteBtn.disabled = false;
    deleteBtn.textContent = "Supprimer définitivement mes données";
  }
});
