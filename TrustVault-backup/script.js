
const SUPABASE_URL = "https://lkgwzavjyfqgylpparhe.supabase.co";
const SUPABASE_KEY = "sb_publishable_SRROVwa_Wemf5wLDncg61w_dzCJV_xb";
const BUCKET = "trustvault-documents";
const MAX_SIZE = 10 * 1024 * 1024;

const db = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);

let currentUser = null;
let currentProfile = null;
let documents = [];
let authMode = "login";

const $ = id => document.getElementById(id);

function message(text, target = "authMessage") {
  const el = $(target);
  if (el) el.textContent = text;
}

function toast(text) {
  const el = $("toast");
  el.textContent = text;
  el.classList.add("show");
  setTimeout(() => el.classList.remove("show"), 3000);
}

function safe(value) {
  return String(value ?? "").replace(/[&<>"']/g, c => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;",
    '"': "&quot;", "'": "&#39;"
  })[c]);
}

function setAuthMode(mode) {
  authMode = mode;
  $("loginTab").classList.toggle("active", mode === "login");
  $("registerTab").classList.toggle("active", mode === "register");
  $("nameLabel").hidden = mode !== "register";
  $("fullName").hidden = mode !== "register";
  $("fullName").required = mode === "register";
  $("submitBtn").textContent = mode === "login" ? "Login" : "Register";
  $("authHeading").textContent = mode === "login" ? "Welcome to TrustVault" : "Create your account";
  message("");
}

async function handleAuth(event) {
  event.preventDefault();

  const email = $("email").value.trim();
  const password = $("password").value;

  $("submitBtn").disabled = true;

  try {
    if (authMode === "login") {
      const { error } = await db.auth.signInWithPassword({ email, password });
      if (error) throw error;
    } else {
      const fullName = $("fullName").value.trim();

      const { data, error } = await db.auth.signUp({
        email,
        password,
        options: { data: { full_name: fullName } }
      });

      if (error) throw error;

      if (!data.session) {
        message("Account created. Email verification avasaramaithe verify chesi login avvandi.");
      } else {
        message("Registration successful!");
      }
    }
  } catch (error) {
    message(error.message);
  } finally {
    $("submitBtn").disabled = false;
  }
}

async function loadProfile() {
  const { data, error } = await db
    .from("profiles")
    .select("id,full_name,role")
    .eq("id", currentUser.id)
    .maybeSingle();

  if (error) throw error;

  currentProfile = data || {
    full_name: currentUser.email,
    email: currentUser.email,
    role: "viewer"
  };

  $("welcomeText").textContent = "Welcome, " + (currentProfile.full_name || currentUser.email);
  $("userEmail").textContent = currentUser.email;
  $("userRole").textContent = currentProfile.role || "viewer";

  $("authSection").hidden = true;
  $("dashboard").hidden = false;

  await loadDocuments();
  await loadActivity();
}

async function loadDocuments() {
  const { data, error } = await db
    .from("documents")
    .select("id,ownerid,title,catageory,storagepath,mime_byte,size_byete,created_at")
    .order("created_at", { ascending: false });

  if (error) throw error;

  documents = data || [];
  $("documentCount").textContent = documents.length;
  renderDocuments();
}

function renderDocuments() {
  const search = $("searchInput").value.toLowerCase().trim();
  const category = $("categoryFilter").value;

  const filtered = documents.filter(item =>
    (!search || `${item.title} ${item.category}`.toLowerCase().includes(search)) &&
    (!category || item.category === category)
  );item.category

  $("documentsList").innerHTML = filtered.length
    ? filtered.map(item => `
      <article class="document-card">
        <span class="badge">${safe(item.category || "General")}</span>
        <h3>${safe(item.title || "Untitled")}</h3>
        <p>${safe(item.mime_type || "File")}</p>
        <p>${item.size_bytes ? (item.size_bytes / 1024).toFixed(1) + " KB" : ""}</p>
        <button class="primary" data-download="${safe(item.id)}">Download</button>
        ${item.size_bytes === currentUser.id || currentProfile.role === "admin"
          ? `<button class="danger" data-delete="${safe(item.id)}">Delete</button>`
          : ""}
      </article>
    `).join("")
    : `<article class="panel"><p class="muted">Documents levu. Upload button use cheyyandi.</p></article>`;

  $("documentsList").querySelectorAll("[data-download]").forEach(button => {
    button.addEventListener("click", () => downloadFile(button.dataset.download));
  });

  $("documentsList").querySelectorAll("[data-delete]").forEach(button => {
    button.addEventListener("click", () => deleteFile(button.dataset.delete));
  });
}

async function uploadFile(event) {
 
async function uploadFile(event) {
  event.preventDefault();

  const file = $("docFile").files[0];

  if (!file) {
    message("Please select a file.", "uploadMessage");
    return;
  }

  if (file.size > MAX_SIZE) {
    message("File must be below 10 MB.", "uploadMessage");
    return;
  }

  const allowedTypes = [
    "application/pdf",
    "image/jpeg",
    "image/png",
    "text/plain",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
  ];

  if (!allowedTypes.includes(file.type)) {
    message("PDF, JPG, PNG, TXT and DOCX only.", "uploadMessage");
    return;
  }

  const path = currentUser.id + "/" + crypto.randomUUID() + "-" +
    file.name.replace(/[^a-zA-Z0-9._-]/g, "_");

  try {
    message("Uploading...", "uploadMessage");

    // First create document record
    const { data: doc, error: dbError } = await db
      .from("documents")
      .insert({
        ownerid: currentUser.id,
        title: $("docTitle").value.trim() || file.name,
        catageory: $("docCategory").value,
        storagepath: path,
        mime_byte: file.type,
        size_byete: file.size
      })
      .select()
      .single();

    if (dbError) throw dbError;

    // Then upload file to private storage
    const { error: storageError } = await db.storage
      .from(BUCKET)
      .upload(path, file, {
        contentType: file.type,
        upsert: false
      });

    if (storageError) {
      await db.from("documents").delete().eq("id", doc.id);
      throw storageError;
    }

    $("uploadForm").reset();
    $("uploadDialog").close();

    await loadDocuments();
    await loadActivity();

    toast("Document uploaded successfully!");

  } catch (error) {
    console.error("Upload error:", error);
    message(error.message, "uploadMessage");
  }
}

  const safeName = file.name.replace(/[^a-zA-Z0-9._-]/g, "_");
  const path = `${currentUser.id}/${crypto.randomUUID()}-${safeName}`;

  try {
    const { error: storageError } = await db.storage
      .from(BUCKET)
      .upload(path, file, { contentType: file.type, upsert: false });

    if (storageError) throw storageError;

const { error: rowError } = await db.from("documents").insert({
  ownerid: currentUser.id,
  title: $("docTitle").value.trim() || file.name,
  catageory: $("docCategory").value,
  storagepath: path,
  mime_byte: file.type,
  size_byete: file.size
});

    if (rowError) {
      await db.storage.from(BUCKET).remove([path]);
      throw rowError;
    }

    $("uploadForm").reset();
    $("uploadDialog").close();
    await loadDocuments();
    await loadActivity();
    toast("Document upload successful!");
  } catch (error) {
    message(error.message, "uploadMessage");
  }
}

async function downloadFile(id) {
  const record = documents.find(item => item.id === id);
  if (!record) return toast("Document not found.");

  const { data, error } = await db.storage
    .from(BUCKET)
    .download(record.storage_path);

  if (error) return toast("Download failed: " + error.message);

  const url = URL.createObjectURL(data);
  const link = document.createElement("a");
  link.href = url;
  link.download = record.title || "document";
  document.body.appendChild(link);
  link.click();
  link.remove();

  setTimeout(() => URL.revokeObjectURL(url), 1000);
  toast("Download started.");
}

async function deleteFile(id) {
  const record = documents.find(item => item.id === id);
  if (!record || !confirm(`Delete "${record.title}"?`)) return;

  try {
    const { error: storageError } = await db.storage
      .from(BUCKET)
      .remove([record.storage_path]);

    if (storageError) throw storageError;

    const { error: rowError } = await db
      .from("documents")
      .delete()
      .eq("id", id);

    if (rowError) throw rowError;

    await loadDocuments();
    await loadActivity();
    toast("Document deleted.");
  } catch (error) {
    toast("Delete failed: " + error.message);
  }
}

async function loadActivity() {
  const { data, error } = await db
    .from("audit_logs")
    .select("id,action,details,created_at")
    .order("created_at", { ascending: false })
    .limit(50);

  if (error) {
    $("activityList").textContent = "Activity logs unavailable: " + error.message;
    return;
  }

  $("activityList").innerHTML = data?.length
    ? data.map(log => `
      <div class="activity-item">
        <strong>${safe(log.action || "Activity")}</strong>
        <small>${safe(new Date(log.created_at).toLocaleString())}</small>
        <p>${safe(typeof log.details === "string" ? log.details : JSON.stringify(log.details || {}))}</p>
      </div>
    `).join("")
    : `<p class="muted">Activity logs inka levu.</p>`;
}

async function logout() {
  const { error } = await db.auth.signOut();
  if (error) return toast(error.message);

  currentUser = null;
  currentProfile = null;
  documents = [];

  $("dashboard").hidden = true;
  $("authSection").hidden = false;
  $("authForm").reset();

  setAuthMode("login");
  toast("Logged out.");
}

function showView(view) {
  ["overview", "documents", "activity"].forEach(name => {
    $(`${name}View`).hidden = name !== view;
  });

  document.querySelectorAll(".nav-btn").forEach(button => {
    button.classList.toggle("active", button.dataset.view === view);
  });

  if (view === "documents") renderDocuments();
  if (view === "activity") loadActivity();
}

async function initializeApp() {
  if (!window.supabase) {
    message("Supabase library load avvaledu. Internet check cheyyandi.");
    return;
  }

  if (SUPABASE_KEY.includes("PASTE_")) {
    message("script.js lo Publishable Key add cheyyandi.");
    return;
  }

  $("loginTab").addEventListener("click", () => setAuthMode("login"));
  $("registerTab").addEventListener("click", () => setAuthMode("register"));
  $("authForm").addEventListener("submit", handleAuth);
  $("logoutBtn").addEventListener("click", logout);
$("openUploadBtn").addEventListener("click", () => {
    alert("Upload button clicked successfully!");
    $("uploadDialog").showModal();
});
  $("closeUploadBtn").addEventListener("click", () => $("uploadDialog").close());
  $("uploadForm").addEventListener("submit", uploadFile);
  $("searchInput").addEventListener("input", renderDocuments);
  $("categoryFilter").addEventListener("change", renderDocuments);

  document.querySelectorAll(".nav-btn").forEach(button => {
    button.addEventListener("click", () => showView(button.dataset.view));
  });

  const { data, error } = await db.auth.getSession();
  if (error) return message(error.message);

  if (data.session) {
    currentUser = data.session.user;
    try {
      await loadProfile();
    } catch (error) {
      message("Dashboard error: " + error.message);
    }
  }

  db.auth.onAuthStateChange((_event, session) => {
    if (session) {
      currentUser = session.user;
      setTimeout(() => loadProfile().catch(error => message(error.message)), 0);
    } else if (currentUser) {
      currentUser = null;
      currentProfile = null;
      documents = [];
      $("dashboard").hidden = true;
      $("authSection").hidden = false;
    }
  });
}

document.addEventListener("DOMContentLoaded", initializeApp);
