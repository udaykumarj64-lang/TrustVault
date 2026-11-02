
const SUPABASE_URL = "https://lkgwzavjyfqgylpparhe.supabase.co";
const SUPABASE_KEY = "sb_publishable_SRROVwa_Wemf5wLDncg61w_dzCJV_xb";

const db = window.supabase.createClient(
  SUPABASE_URL,
  SUPABASE_KEY
);

const authSection = document.getElementById("authSection");
const dashboard = document.getElementById("dashboard");
const authForm = document.getElementById("authForm");
const authMessage = document.getElementById("authMessage");

let isRegister = false;

const loginTab = document.getElementById("loginTab");
const registerTab = document.getElementById("registerTab");
const fullName = document.getElementById("fullName");
const nameLabel = document.getElementById("nameLabel");
const submitBtn = document.getElementById("submitBtn");

function showMessage(message) {
  authMessage.textContent = message;
}

function setMode(register) {
  isRegister = register;

  fullName.hidden = !register;
  nameLabel.hidden = !register;
  fullName.required = register;

  loginTab.classList.toggle("active", !register);
  registerTab.classList.toggle("active", register);

  submitBtn.textContent = register
    ? "Create Account"
    : "Login";

  showMessage("");
}

loginTab.addEventListener("click", () => setMode(false));
registerTab.addEventListener("click", () => setMode(true));

authForm.addEventListener("submit", async (event) => {
  event.preventDefault();

  const email = document.getElementById("email").value.trim();
  const password = document.getElementById("password").value;
  const name = fullName.value.trim();

  submitBtn.disabled = true;
  showMessage("Please wait...");

  try {
    if (isRegister) {
      const { data, error } = await db.auth.signUp({
        email,
        password,
        options: {
          data: {
            full_name: name
          }
        }
      });

      if (error) throw error;

      if (data.session) {
        await loadDashboard(data.user);
      } else {
        showMessage(
          "Registration successful. Please verify your email, then login."
        );
      }
    } else {
      const { data, error } = await db.auth.signInWithPassword({
        email,
        password
      });

      if (error) throw error;

      await loadDashboard(data.user);
    }
  } catch (error) {
    showMessage(error.message);
  } finally {
    submitBtn.disabled = false;
  }
});

async function loadDashboard(user) {
  const { data: profile, error } = await db
    .from("profiles")
    .select("full_name, role")
    .eq("id", user.id)
    .single();

  if (error) {
    showMessage("Profile loading failed: " + error.message);
    return;
  }

  authSection.hidden = true;
  dashboard.hidden = false;

  document.getElementById("welcomeText").textContent =
    "Welcome, " + (profile.full_name || user.email);

  document.getElementById("userRole").textContent = profile.role;
  document.getElementById("userEmail").textContent = user.email;
}

document.getElementById("logoutBtn").addEventListener("click", async () => {
  const { error } = await db.auth.signOut();

  if (error) {
    alert(error.message);
    return;
  }

  dashboard.hidden = true;
  authSection.hidden = false;
  authForm.reset();
  setMode(false);
});

async function checkExistingSession() {
  const { data, error } = await db.auth.getSession();

  if (error) {
    showMessage(error.message);
    return;
  }

  if (data.session) {
    await loadDashboard(data.session.user);
  }
}

db.auth.onAuthStateChange((event, session) => {
  if (event === "SIGNED_OUT") {
    dashboard.hidden = true;
    authSection.hidden = false;
  }
});

checkExistingSession();
