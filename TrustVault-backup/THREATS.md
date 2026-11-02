
# TrustVault Threat Model

| Threat | Mitigation |
|---|---|
| Unauthorized document read | Database and Storage RLS |
| Unauthorized document deletion | Owner/admin authorization on server |
| Self-assigned admin role | Prevent client role updates |
| Leaked file links | Private bucket; avoid long-lived signed URLs |
| Permission revocation bypass | Recheck access on every download |
| Forged audit events | Trusted database triggers/functions only |
| Forged file MIME type | Server-side validation and file scanning |
| Password attacks | Email verification, rate limiting and MFA |
| SQL privilege escalation | Fixed search_path and strict RPC permissions |

Do not claim production security until authorization tests pass.
