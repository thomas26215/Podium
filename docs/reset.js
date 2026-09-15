import { sendPasswordResetEmail } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js";
import { auth } from "./firebase-init.js";

const form = document.getElementById("reset-form");
const emailInput = document.getElementById("reset-email");
const resetBtn = document.getElementById("reset-btn");
const resetMsg = document.getElementById("reset-msg");

function showMessage(text, kind) {
  resetMsg.innerHTML = `<div class="msg ${kind}">${text}</div>`;
}

form.addEventListener("submit", async (e) => {
  e.preventDefault();
  resetMsg.innerHTML = "";
  const email = emailInput.value.trim();
  if (!email) return;

  resetBtn.disabled = true;
  resetBtn.textContent = "Envoi…";
  try {
    await sendPasswordResetEmail(auth, email);
    showMessage("Si un compte existe avec cette adresse, un e-mail de réinitialisation vient d'être envoyé. Pensez à vérifier vos spams / courriers indésirables s'il n'arrive pas d'ici quelques minutes.", "success");
  } catch (err) {
    // Don't leak whether the address has an account — only a malformed
    // address gets its own message, everything else looks like success.
    if (err.code === "auth/invalid-email") {
      showMessage("Adresse e-mail invalide.", "error");
    } else if (err.code === "auth/too-many-requests") {
      showMessage("Trop de tentatives — réessayez dans quelques minutes.", "error");
    } else {
      // Still logged for debugging — auth/user-not-found is expected and
      // fine to hide, but anything else (network, config, quota) would be
      // silently swallowed here otherwise.
      console.error("sendPasswordResetEmail failed:", err.code, err.message);
      showMessage("Si un compte existe avec cette adresse, un e-mail de réinitialisation vient d'être envoyé. Pensez à vérifier vos spams / courriers indésirables s'il n'arrive pas d'ici quelques minutes.", "success");
    }
  } finally {
    resetBtn.disabled = false;
    resetBtn.textContent = "Envoyer le lien de réinitialisation";
  }
});
