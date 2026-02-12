-- Public ID card verification RPC.
--
-- This enables the `/verify-card?tok=...` page to validate a card without
-- requiring a login, while still keeping the `students` table protected by RLS.
--
-- SECURITY: This function is SECURITY DEFINER. It must return only the fields
-- you are comfortable exposing via a public verification link.

CREATE OR REPLACE FUNCTION public.verify_student_id_card(token text)
RETURNS TABLE (
  id text,
  first_name text,
  last_name text,
  seat_number text,
  id_card_issued_at timestamp with time zone,
  has_active_subscription boolean,
  active_plan_name text,
  active_end_date timestamp with time zone
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    s.id,
    s.first_name,
    s.last_name,
    s.seat_number,
    s.id_card_issued_at,
    (sub.plan_name IS NOT NULL) as has_active_subscription,
    sub.plan_name as active_plan_name,
    sub.end_date as active_end_date
  FROM public.students s
  LEFT JOIN LATERAL (
    SELECT
      plan_name,
      end_date
    FROM public.subscriptions
    WHERE student_id = s.id
      AND COALESCE(is_deleted, false) = false
      AND status = 'active'
      AND start_date <= now()
      AND end_date >= now()
    ORDER BY end_date DESC
    LIMIT 1
  ) sub ON true
  WHERE s.id_card_token = token
    AND COALESCE(s.is_deleted, false) = false
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.verify_student_id_card(text) TO anon;
GRANT EXECUTE ON FUNCTION public.verify_student_id_card(text) TO authenticated;
