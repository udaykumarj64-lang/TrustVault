# TrustVault – Threat Model

## 1. Project Overview

TrustVault is a secure document-sharing platform that allows users to upload, manage, share, and download documents with role-based access control.

## 2. Security Threats and Mitigations

| Threat | Mitigation |
|---|---|
| Unauthorized document reading | PostgreSQL Row Level Security (RLS) and private Supabase Storage bucket |
| Unauthorized document deletion | Server-side owner/admin authorization |
| Self-assigned admin role | Prevent unauthorized profile role updates |
| Leaked file links | Private Storage bucket; avoid long-lived signed URLs |
| Permission revocation bypass | Recheck authorization on every download |
| Forged audit events | Trusted database triggers and restricted functions |
| Forged file MIME type | Validate file type, size and content |
| Password attacks | Email verification, rate limiting and MFA |
| SQL privilege escalation | Fixed search_path and restricted RPC permissions |
| Unauthorized permission changes | RLS policies for permission grants and revocations |

## 3. User Roles

- **Admin:** Can manage and monitor documents and permissions according to admin policies.
- **Document Owner:** Can manage owned documents and grant or revoke access.
- **Viewer:** Can access only documents for which read permission is granted.

## 4. Security Controls Implemented and Tested

- Private document Storage bucket.
- Row Level Security enabled on public tables.
- Document access controlled by user identity and permissions.
- Permission grant and revoke audit events.
- Download authorization checks.
- Unauthorized access attempts recorded in audit logs.
- Database functions hardened with restricted execution privileges.

## 5. Automated Security Test Results

The following five pgTAP tests were executed successfully:

1. Viewer cannot see a revoked document.
2. Viewer cannot see revoked document permissions.
3. Viewer cannot modify a revoked document.
4. Viewer cannot delete a revoked document.
5. Admin can view the document.

**Test result: 5/5 passed for the tested database scenarios.**

## 6. Known Limitations and Future Improvements

- Implement and test a dedicated document-owner account and role.
- Add automated tests for permission grants, revocations and Storage access.
- Add server-side file content validation and malware scanning.
- Add password rate limiting and multi-factor authentication.
- Verify audit logging for failed Storage requests.
- Test immediate revocation against all download methods.

## 7. Security Disclaimer

Passing the current tests does not establish production-level security. Further testing, independent security review and deployment hardening are required.
