-- =====================================================
-- TRUSTVAULT
-- DATABASE POLICIES AND FUNCTIONS
-- =====================================================
--
-- Project: TrustVault - Secure Document Management
-- Database: Supabase PostgreSQL
--
-- IMPORTANT:
-- This file documents the verified database configuration.
-- Review the complete script before using it in a new project.
-- Do not execute it on the existing production database.
--
-- =====================================================
-- SECTION 1: ACCESS CONTROL FUNCTIONS
-- =====================================================

-- 1. Check whether the logged-in user is an Admin.

CREATE OR REPLACE FUNCTION public.is_trustvault_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
    SELECT EXISTS (
        SELECT 1
        FROM public.profiles
        WHERE id = (SELECT auth.uid())
          AND role = 'admin'
    );
$function$;


-- 2. Check whether a user has the requested document permission.
-- Edit permission also provides read access.

CREATE OR REPLACE FUNCTION public.trustvault_has_document_permission(
    p_document_id uuid,
    p_permission text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
    SELECT EXISTS (
        SELECT 1
        FROM public.document_permissions
        WHERE document_id = p_document_id
          AND grantee_id = (SELECT auth.uid())
          AND (
              permission = p_permission
              OR (p_permission = 'read' AND permission = 'edit')
          )
    );
$function$;


-- 3. Check whether the logged-in user owns a document.

CREATE OR REPLACE FUNCTION public.trustvault_is_document_owner(
    p_document_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
    SELECT EXISTS (
        SELECT 1
        FROM public.documents
        WHERE id = p_document_id
          AND owner_id = (SELECT auth.uid())
    );
$function$;


-- 4. Prevent document ownership from being changed.

CREATE OR REPLACE FUNCTION public.trustvault_protect_document_owner()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
    IF NEW.owner_id IS DISTINCT FROM OLD.owner_id THEN
        RAISE EXCEPTION 'Document ownership cannot be changed';
    END IF;

    RETURN NEW;
END;
$function$;
-- =====================================================
-- SECTION 2: DOCUMENT SHARING FUNCTIONS
-- =====================================================

-- 5. Grant document access using the registered user's email.
-- Supports read and edit permissions.

CREATE OR REPLACE FUNCTION public.grant_document_access(
    p_document_id uuid,
    p_email text,
    p_permission text
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_user_id uuid;
    v_owner_id uuid;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Please login first';
    END IF;

    IF p_permission NOT IN ('read', 'edit') THEN
        RAISE EXCEPTION 'Invalid permission';
    END IF;

    SELECT owner_id INTO v_owner_id
    FROM public.documents
    WHERE id = p_document_id;

    IF v_owner_id IS NULL THEN
        RAISE EXCEPTION 'Document not found';
    END IF;

    IF v_owner_id <> auth.uid() AND NOT EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'admin'
    ) THEN
        RAISE EXCEPTION 'Only the owner or admin can share this document';
    END IF;

    SELECT id INTO v_user_id
    FROM auth.users
    WHERE lower(email) = lower(trim(p_email))
    LIMIT 1;

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'No registered user found with this email';
    END IF;

    IF v_user_id = v_owner_id THEN
        RAISE EXCEPTION 'Owner already has full access';
    END IF;

    INSERT INTO public.document_permissions
        (document_id, grantee_id, permission, granted_by)
    VALUES
        (p_document_id, v_user_id, p_permission, auth.uid())
    ON CONFLICT (document_id, grantee_id)
    DO UPDATE SET
        permission = excluded.permission,
        granted_by = excluded.granted_by;

    RETURN 'Access granted successfully';
END;
$function$;


-- 6. Revoke document access using the user's ID.

CREATE OR REPLACE FUNCTION public.revoke_document_access(
    p_document_id uuid,
    p_user_id uuid
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_owner_id uuid;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Please login first';
    END IF;

    SELECT owner_id INTO v_owner_id
    FROM public.documents
    WHERE id = p_document_id;

    IF v_owner_id IS NULL THEN
        RAISE EXCEPTION 'Document not found';
    END IF;

    IF v_owner_id <> auth.uid() AND NOT EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'admin'
    ) THEN
        RAISE EXCEPTION 'Only the owner or admin can revoke access';
    END IF;

    DELETE FROM public.document_permissions
    WHERE document_id = p_document_id
      AND grantee_id = p_user_id;

    RETURN 'Access revoked successfully';
END;
$function$;


-- 7. Alternative permission grant function.

CREATE OR REPLACE FUNCTION public.trustvault_grant_permission(
    p_document_id uuid,
    p_email text,
    p_permission text
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_actor uuid;
    v_owner uuid;
    v_grantee uuid;
BEGIN
    v_actor := auth.uid();

    IF v_actor IS NULL THEN
        RAISE EXCEPTION 'Login required';
    END IF;

    IF p_permission NOT IN ('read', 'edit') THEN
        RAISE EXCEPTION 'Permission must be read or edit';
    END IF;

    IF p_email IS NULL OR trim(p_email) = '' THEN
        RAISE EXCEPTION 'Email is required';
    END IF;

    SELECT owner_id INTO v_owner
    FROM public.documents
    WHERE id = p_document_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Document not found';
    END IF;

    IF v_owner <> v_actor
       AND NOT public.is_trustvault_admin() THEN
        RAISE EXCEPTION 'Not authorized to share this document';
    END IF;

    SELECT id INTO v_grantee
    FROM auth.users
    WHERE lower(email) = lower(trim(p_email))
    LIMIT 1;

    IF v_grantee IS NULL THEN
        RAISE EXCEPTION 'No registered user found with this email';
    END IF;

    IF v_grantee = v_owner THEN
        RAISE EXCEPTION 'Document owner already has access';
    END IF;

    INSERT INTO public.document_permissions
        (document_id, grantee_id, permission, granted_by)
    VALUES
        (p_document_id, v_grantee, p_permission, v_actor);

    RETURN 'Permission granted successfully';
END;
$function$;


-- 8. Alternative permission revoke function.

CREATE OR REPLACE FUNCTION public.trustvault_revoke_permission(
    p_document_id uuid,
    p_email text
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_actor uuid;
    v_owner uuid;
    v_grantee uuid;
BEGIN
    v_actor := auth.uid();

    IF v_actor IS NULL THEN
        RAISE EXCEPTION 'Login required';
    END IF;

    SELECT owner_id INTO v_owner
    FROM public.documents
    WHERE id = p_document_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Document not found';
    END IF;

    IF v_owner <> v_actor
       AND NOT public.is_trustvault_admin() THEN
        RAISE EXCEPTION 'Not authorized to revoke permission';
    END IF;

    SELECT id INTO v_grantee
    FROM auth.users
    WHERE lower(email) = lower(trim(p_email))
    LIMIT 1;

    IF v_grantee IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    DELETE FROM public.document_permissions
    WHERE document_id = p_document_id
      AND grantee_id = v_grantee;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Permission not found';
    END IF;

    RETURN 'Permission revoked successfully';
END;
$function$;
-- =====================================================
-- SECTION 3: STORAGE AND ADMIN FUNCTIONS
-- =====================================================

-- 9. Check whether the logged-in user can access a file
-- stored in the private TrustVault bucket.

CREATE OR REPLACE FUNCTION public.trustvault_can_access_storage(
    p_storage_path text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
    SELECT EXISTS (
        SELECT 1
        FROM public.documents d
        WHERE d.storage_path = p_storage_path
        AND (
            public.is_trustvault_admin()
            OR d.owner_id = (SELECT auth.uid())
            OR EXISTS (
                SELECT 1
                FROM public.document_permissions p
                WHERE p.document_id = d.id
                  AND p.grantee_id = (SELECT auth.uid())
                  AND p.permission IN ('read', 'edit')
            )
        )
    );
$function$;


-- 10. List document owners for users who can access documents.

CREATE OR REPLACE FUNCTION public.trustvault_document_owners()
RETURNS TABLE(document_id uuid, owner_name text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
    SELECT
        d.id,
        COALESCE(p.full_name, 'Unknown')
    FROM public.documents d
    LEFT JOIN public.profiles p
        ON p.id = d.owner_id
    WHERE auth.uid() IS NOT NULL
      AND (
          d.owner_id = auth.uid()
          OR public.is_trustvault_admin()
          OR EXISTS (
              SELECT 1
              FROM public.document_permissions dp
              WHERE dp.document_id = d.id
                AND dp.grantee_id = auth.uid()
                AND dp.permission IN ('read', 'edit')
          )
      );
$function$;


-- 11. List registered users.
-- Only Admin users can execute this function successfully.

CREATE OR REPLACE FUNCTION public.trustvault_list_users()
RETURNS TABLE(
    user_id uuid,
    full_name text,
    email text,
    role text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    IF auth.uid() IS NULL
       OR NOT public.is_trustvault_admin() THEN
        RAISE EXCEPTION 'Admin access required';
    END IF;

    RETURN QUERY
    SELECT
        p.id,
        p.full_name,
        u.email::text,
        p.role
    FROM public.profiles p
    JOIN auth.users u ON u.id = p.id
    ORDER BY p.created_at DESC;
END;
$function$;


-- 12. Allow Admin to change another user's role.

CREATE OR REPLACE FUNCTION public.trustvault_set_user_role(
    p_user_id uuid,
    p_role text
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    IF auth.uid() IS NULL
       OR NOT public.is_trustvault_admin() THEN
        RAISE EXCEPTION 'Admin access required';
    END IF;

    IF p_role NOT IN ('admin', 'owner', 'viewer') THEN
        RAISE EXCEPTION 'Invalid role';
    END IF;

    IF p_user_id = auth.uid() THEN
        RAISE EXCEPTION 'You cannot change your own role';
    END IF;

    UPDATE public.profiles
    SET role = p_role
    WHERE id = p_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User profile not found';
    END IF;

    RETURN 'User role updated successfully';
END;
$function$;
-- =====================================================
-- SECTION 4: AUDIT LOGGING FUNCTIONS
-- =====================================================

-- 13. Automatically record document upload, update and delete events.

CREATE OR REPLACE FUNCTION public.record_document_audit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.audit_logs
            (actor_id, document_id, action, details)
        VALUES (
            (SELECT auth.uid()),
            NEW.id,
            'upload',
            pg_catalog.jsonb_build_object('title', NEW.title)
        );
        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO public.audit_logs
            (actor_id, document_id, action, details)
        VALUES (
            (SELECT auth.uid()),
            NEW.id,
            'update',
            pg_catalog.jsonb_build_object('title', NEW.title)
        );
        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO public.audit_logs
            (actor_id, document_id, action, details)
        VALUES (
            (SELECT auth.uid()),
            NULL,
            'delete',
            pg_catalog.jsonb_build_object(
                'title', OLD.title,
                'original_document_id', OLD.id
            )
        );
        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$function$;


-- 14. Automatically record permission grant and revoke events.

CREATE OR REPLACE FUNCTION public.record_permission_audit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.audit_logs
            (actor_id, document_id, action, details)
        VALUES (
            (SELECT auth.uid()),
            NEW.document_id,
            'permission_granted',
            pg_catalog.jsonb_build_object(
                'user_id', NEW.grantee_id,
                'permission', NEW.permission
            )
        );
        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO public.audit_logs
            (actor_id, document_id, action, details)
        VALUES (
            (SELECT auth.uid()),
            OLD.document_id,
            'permission_revoked',
            pg_catalog.jsonb_build_object(
                'user_id', OLD.grantee_id,
                'permission', OLD.permission
            )
        );
        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$function$;


-- 15. Record document download or denied-access attempts.

CREATE OR REPLACE FUNCTION public.trustvault_log_download(
    p_document_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_allowed boolean;
    v_title text;
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN false;
    END IF;

    SELECT d.title INTO v_title
    FROM public.documents d
    WHERE d.id = p_document_id;

    IF NOT FOUND THEN
        RETURN false;
    END IF;

    SELECT (
        public.is_trustvault_admin()
        OR EXISTS (
            SELECT 1
            FROM public.documents d
            WHERE d.id = p_document_id
              AND d.owner_id = auth.uid()
        )
        OR EXISTS (
            SELECT 1
            FROM public.document_permissions p
            WHERE p.document_id = p_document_id
              AND p.grantee_id = auth.uid()
              AND p.permission IN ('read', 'edit')
        )
    ) INTO v_allowed;

    INSERT INTO public.audit_logs (
        actor_id, document_id, action, details
    )
    VALUES (
        auth.uid(),
        p_document_id,
        CASE WHEN v_allowed THEN 'download' ELSE 'access_denied' END,
        jsonb_build_object('title', v_title)
    );

    RETURN v_allowed;
END;
$function$;
-- =====================================================
-- SECTION 5: USER REGISTRATION FUNCTION
-- =====================================================

-- 16. Automatically create a profile whenever a new
-- user registers through Supabase Authentication.
-- Every new user receives the default 'viewer' role.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    INSERT INTO public.profiles (id, full_name, role)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data ->> 'full_name', ''),
        'viewer'
    );

    RETURN NEW;
END;
$function$;
-- =====================================================
-- SECTION 6: TRIGGER CONFIGURATION
-- =====================================================

-- 1. Automatically create a profile after user registration.

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_user();


-- 2. Record document upload, update and delete events.

CREATE TRIGGER document_audit_trigger
AFTER INSERT OR UPDATE OR DELETE
ON public.documents
FOR EACH ROW
EXECUTE FUNCTION public.record_document_audit();


-- 3. Record permission grant and revoke events.

CREATE TRIGGER permission_audit_trigger
AFTER INSERT OR DELETE
ON public.document_permissions
FOR EACH ROW
EXECUTE FUNCTION public.record_permission_audit();


-- 4. Prevent document ownership changes.

CREATE TRIGGER trustvault_owner_protection
BEFORE UPDATE
ON public.documents
FOR EACH ROW
EXECUTE FUNCTION public.trustvault_protect_document_owner();
-- =====================================================
-- SECTION 7: ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================

-- Enable Row Level Security on all application tables.

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;


-- -----------------------------------------------------
-- PROFILES POLICIES
-- -----------------------------------------------------

CREATE POLICY "Read own profile or admin"
ON public.profiles
FOR SELECT
TO authenticated
USING (
    id = (SELECT auth.uid())
    OR public.is_trustvault_admin()
);


-- -----------------------------------------------------
-- DOCUMENTS POLICIES
-- -----------------------------------------------------

CREATE POLICY "Read permitted documents"
ON public.documents
FOR SELECT
TO authenticated
USING (
    public.is_trustvault_admin()
    OR owner_id = (SELECT auth.uid())
    OR public.trustvault_has_document_permission(id, 'read')
);


CREATE POLICY "Only admins and owners insert documents"
ON public.documents
FOR INSERT
TO authenticated
WITH CHECK (
    public.is_trustvault_admin()
    OR (
        owner_id = (SELECT auth.uid())
        AND EXISTS (
            SELECT 1
            FROM public.profiles p
            WHERE p.id = (SELECT auth.uid())
              AND p.role = 'owner'
        )
    )
);


CREATE POLICY "Owners admins and editors update documents"
ON public.documents
FOR UPDATE
TO authenticated
USING (
    public.is_trustvault_admin()
    OR owner_id = (SELECT auth.uid())
    OR public.trustvault_has_document_permission(id, 'edit')
)
WITH CHECK (
    public.is_trustvault_admin()
    OR owner_id = (SELECT auth.uid())
    OR public.trustvault_has_document_permission(id, 'edit')
);


CREATE POLICY "Only admins and owners delete documents"
ON public.documents
FOR DELETE
TO authenticated
USING (
    public.is_trustvault_admin()
    OR (
        owner_id = (SELECT auth.uid())
        AND EXISTS (
            SELECT 1
            FROM public.profiles p
            WHERE p.id = (SELECT auth.uid())
              AND p.role = 'owner'
        )
    )
);


-- -----------------------------------------------------
-- DOCUMENT PERMISSIONS POLICIES
-- -----------------------------------------------------

CREATE POLICY "Read relevant permissions"
ON public.document_permissions
FOR SELECT
TO authenticated
USING (
    public.is_trustvault_admin()
    OR grantee_id = (SELECT auth.uid())
    OR public.trustvault_is_document_owner(document_id)
);


CREATE POLICY "Owners and admins grant permissions"
ON public.document_permissions
FOR INSERT
TO authenticated
WITH CHECK (
    granted_by = (SELECT auth.uid())
    AND (
        public.is_trustvault_admin()
        OR EXISTS (
            SELECT 1
            FROM public.documents d
            WHERE d.id = document_permissions.document_id
              AND d.owner_id = (SELECT auth.uid())
        )
    )
);


CREATE POLICY "Owners and admins revoke permissions"
ON public.document_permissions
FOR DELETE
TO authenticated
USING (
    public.is_trustvault_admin()
    OR EXISTS (
        SELECT 1
        FROM public.documents d
        WHERE d.id = document_permissions.document_id
          AND d.owner_id = (SELECT auth.uid())
    )
);


-- -----------------------------------------------------
-- DOCUMENT VERSIONS POLICIES
-- -----------------------------------------------------

CREATE POLICY "Owners can add document versions"
ON public.document_versions
FOR INSERT
TO authenticated
WITH CHECK (
    created_by = (SELECT auth.uid())
    AND EXISTS (
        SELECT 1
        FROM public.documents d
        WHERE d.id = document_versions.document_id
          AND d.owner_id = (SELECT auth.uid())
    )
);


CREATE POLICY "Users can view accessible document versions"
ON public.document_versions
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.documents d
        WHERE d.id = document_versions.document_id
          AND (
              d.owner_id = (SELECT auth.uid())
              OR EXISTS (
                  SELECT 1
                  FROM public.document_permissions p
                  WHERE p.document_id = d.id
                    AND p.grantee_id = (SELECT auth.uid())
              )
          )
    )
);


-- -----------------------------------------------------
-- AUDIT LOGS POLICIES
-- -----------------------------------------------------

CREATE POLICY "Owners and admins can view audit logs"
ON public.audit_logs
FOR SELECT
TO authenticated
USING (
    actor_id = (SELECT auth.uid())
    OR EXISTS (
        SELECT 1
        FROM public.documents d
        WHERE d.id = audit_logs.document_id
          AND d.owner_id = (SELECT auth.uid())
    )
    OR EXISTS (
        SELECT 1
        FROM public.profiles p
        WHERE p.id = (SELECT auth.uid())
          AND p.role = 'admin'
    )
);
-- =====================================================
-- SECTION 8: STORAGE SECURITY POLICIES
-- =====================================================

-- Storage bucket: trustvault-documents
-- Access is restricted to authenticated users.


-- 1. Secure file uploads.
-- Only Admins and document owners can upload files.

CREATE POLICY "TrustVault secure uploads"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'trustvault-documents'
    AND EXISTS (
        SELECT 1
        FROM public.documents d
        WHERE d.storage_path = objects.name
          AND (
              public.is_trustvault_admin()
              OR d.owner_id = (SELECT auth.uid())
          )
    )
);


-- 2. Secure file downloads.
-- Admins, owners and users with read/edit permission
-- can access the stored files.

CREATE POLICY "TrustVault secure downloads"
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'trustvault-documents'
    AND public.trustvault_can_access_storage(name)
);


-- 3. Secure file updates.
-- Admins, owners and users with edit permission
-- can update stored files.

CREATE POLICY "TrustVault secure updates"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'trustvault-documents'
    AND EXISTS (
        SELECT 1
        FROM public.documents d
        WHERE d.storage_path = objects.name
          AND (
              public.is_trustvault_admin()
              OR d.owner_id = (SELECT auth.uid())
              OR EXISTS (
                  SELECT 1
                  FROM public.document_permissions p
                  WHERE p.document_id = d.id
                    AND p.grantee_id = (SELECT auth.uid())
                    AND p.permission = 'edit'
              )
          )
    )
)
WITH CHECK (
    bucket_id = 'trustvault-documents'
    AND EXISTS (
        SELECT 1
        FROM public.documents d
        WHERE d.storage_path = objects.name
          AND (
              public.is_trustvault_admin()
              OR d.owner_id = (SELECT auth.uid())
              OR EXISTS (
                  SELECT 1
                  FROM public.document_permissions p
                  WHERE p.document_id = d.id
                    AND p.grantee_id = (SELECT auth.uid())
                    AND p.permission = 'edit'
              )
          )
    )
);


-- 4. Secure file deletion.
-- Only Admins and document owners can delete files.

CREATE POLICY "TrustVault secure deletes"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'trustvault-documents'
    AND EXISTS (
        SELECT 1
        FROM public.documents d
        WHERE d.storage_path = objects.name
          AND (
              public.is_trustvault_admin()
              OR d.owner_id = (SELECT auth.uid())
          )
    )
);