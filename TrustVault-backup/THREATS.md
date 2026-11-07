# TrustVault – Threat Model

## 1. Project Overview

TrustVault is a secure document-management and sharing platform. It allows users to upload, organize, manage, share, and download documents using role-based access control.

## 2. Security Threats and Mitigations

| Threat | Mitigation |
|---|---|
| Unauthorized document reading | PostgreSQL Row Level Security (RLS) and a private Supabase Storage bucket |
| Unauthorized document modification or deletion | Database authorization policies based on user roles and document ownership |
| Self-assigned admin role | Restrict profile role updates through database policies and trusted functions |
| Leaked file links | Private Storage bucket and controlled download access |
| Permission revocation bypass | Recheck document permissions when accessing files |
| Forged audit events | Database audit triggers and restricted write access |
| Invalid or oversized file uploads | File-type restrictions and a 10 MB upload limit |
| Password attacks | Apply authentication-provider protections; evaluate rate limiting and MFA |
| SQL privilege escalation | Restrict database function execution and use a fixed search path where configured |
| Unauthorized permission changes | RLS policies and owner/admin authorization for permission management |

## 3. User Roles

- **Admin:** Can manage and monitor documents and permissions according to admin policies.
- **Document Owner:** Can manage owned documents and grant or revoke access.
- **Viewer:** Can access documents only when the required permission is granted.

## 4. Security Controls Implemented and Manually Tested

- Private Supabase Storage bucket.
- Row Level Security policies on application tables.
- Document access controlled by user identity, ownership, and permissions.
- Permission grant and revoke audit events.
- Document download access checks.
- Viewer access restrictions for document updates and deletions.
- Upload validation for blocked file types and the 10 MB size limit.
- Admin access to documents and Activity Logs.

## 5. Automated Security Tests

The existing pgTAP test suite contains five database security scenarios:

1. Viewer cannot see a revoked document.
2. Viewer cannot see revoked document permissions.
3. Viewer cannot modify a revoked document.
4. Viewer cannot delete a revoked document.
5. Admin can view the document.

**Test result:** The project has previously reported 5/5 passing tests. Rerun the pgTAP suite and verify its output before treating this as the final submission result.

## 6. Manual Security Testing

Manual tests were performed in the local development environment and deployed Vercel application.

- Owner-to-Viewer document sharing and permission revocation.
- Revoked document disappears from the Viewer's shared documents.
- Unauthorized Viewer update and delete attempts do not change or remove the original document.
- Admin document access and Activity Logs.
- Permission and document activity audit events.
- Invalid `.exe` upload blocked.
- Valid PDF upload succeeds and remains after refresh.
- File exceeding 10 MB blocked.

**Note:** A Storage response such as "Object not found" is not, by itself, definitive proof of an authorization denial. Permission removal was also checked separately in the database.

## 7. Known Limitations and Future Improvements

- Expand automated tests for document owners, permission grants, revocations, and Storage access.
- Add server-side file-content validation and malware scanning.
- Evaluate password rate limiting and multi-factor authentication.
- Verify audit logging for failed Storage requests.
- Test immediate permission revocation against every download method.
- Perform an independent security review before production use.

## 8. Security Disclaimer

The current tests provide evidence that the tested security controls work in the tested scenarios. They do not establish production-level security or constitute an independent penetration test. Further automated testing, security review, and deployment hardening are recommended.