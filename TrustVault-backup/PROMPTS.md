# PROMPTS.md

## AI Assistance Record

This file records the AI assistance used during the development of TrustVault. Prompt descriptions below are summaries of the assistance requested, not necessarily verbatim chat transcripts.

### 2026-11-02 — Frontend Development
**Prompt summary:** Help design and build a secure document management interface using HTML, CSS and JavaScript.

**AI output:** Frontend structure, UI styling guidance and JavaScript implementation support.

**Human review:** Checked HTML element IDs, JavaScript selectors, navigation behaviour and UI functionality.

**Commit:** Add the relevant GitHub commit URL.

### 2026-11-02 — Authentication
**Prompt summary:** Explain and implement Supabase authentication, including registration, login and session handling.

**AI output:** Authentication implementation guidance and troubleshooting support.

**Human review:** Tested login and registration with multiple user accounts and checked role-related behaviour.

**Commit:** Add the relevant GitHub commit URL.

### 2026-11-02 — Authorization and RLS
**Prompt summary:** Review Admin, Owner and Viewer permissions and help design database-level access controls.

**AI output:** Row Level Security (RLS) policy guidance and authorization review.

**Human review:** Verified that UI visibility alone is not security and tested unauthorized document modification and deletion.

**Commit:** Add the relevant GitHub commit URL.

### 2026-11-02 — Audit Logging
**Prompt summary:** Help design audit logging for document operations and permission changes.

**AI output:** Audit event and database-trigger implementation guidance.

**Human review:** Checked upload, download and permission grant/revoke audit events. Reviewed the trustworthiness of client-generated logs.

**Commit:** Add the relevant GitHub commit URL.

### 2026-11-02 — Threat Modelling
**Prompt summary:** Identify security threats in a document management and sharing application.

**AI output:** Threat identification, mitigation suggestions and THREATS.md documentation guidance.

**Human review:** Compared proposed mitigations with implemented security controls and manual test results. Documented remaining limitations.

**Commit:** Add the relevant GitHub commit URL.
PROMPTS.md section	Relevant commit
Frontend	Fix TrustVault features and update UI
Authentication	Initial TrustVault project
Authorization	Fix owner document sharing permissions
Audit	Add automated TrustVault security tests
Threat model	Improve TrustVault threat model documentation

Important: Audit commit title automated tests ani undhi; audit logging implementation