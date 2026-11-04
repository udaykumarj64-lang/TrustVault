-- TrustVault Automated Security Tests
-- Run this script in Supabase SQL Editor.
-- Expected result: 5 tests passed.

BEGIN;

SELECT extensions.plan(5);

-- TEST 1 to 4: Viewer restrictions
SET LOCAL ROLE authenticated;

SELECT set_config(
    'request.jwt.claim.sub',
    'd1dd9525-c4d9-44f8-a74d-1c3d4905c258',
    true
);

-- Test 1: Viewer cannot see revoked document
SELECT extensions.is(
    (
        SELECT COUNT(*)::integer
        FROM public.documents
        WHERE id = '7711e392-0d0c-4903-a286-ee93c93b8a3a'
    ),
    0,
    'Viewer cannot see revoked document'
);

-- Test 2: Viewer cannot see revoked permissions
SELECT extensions.is(
    (
        SELECT COUNT(*)::integer
        FROM public.document_permissions
        WHERE document_id = '7711e392-0d0c-4903-a286-ee93c93b8a3a'
    ),
    0,
    'Viewer cannot see revoked permissions'
);

-- Test 3: Viewer cannot modify revoked document
WITH changed AS (
    UPDATE public.documents
    SET title = title
    WHERE id = '7711e392-0d0c-4903-a286-ee93c93b8a3a'
    RETURNING id
)
SELECT extensions.is(
    (SELECT COUNT(*)::integer FROM changed),
    0,
    'Viewer cannot modify revoked document'
);

-- Test 4: Viewer cannot delete revoked document
WITH deleted AS (
    DELETE FROM public.documents
    WHERE id = '7711e392-0d0c-4903-a286-ee93c93b8a3a'
    RETURNING id
)
SELECT extensions.is(
    (SELECT COUNT(*)::integer FROM deleted),
    0,
    'Viewer cannot delete revoked document'
);

-- TEST 5: Admin access
RESET ROLE;
SET LOCAL ROLE authenticated;

SELECT set_config(
    'request.jwt.claim.sub',
    '38dbfa04-1a32-4e95-b623-c7ddf17b1d16',
    true
);

SELECT extensions.is(
    (
        SELECT COUNT(*)::integer
        FROM public.documents
        WHERE id = '7711e392-0d0c-4903-a286-ee93c93b8a3a'
    ),
    1,
    'Admin can view document'
);

SELECT * FROM extensions.finish();

ROLLBACK;