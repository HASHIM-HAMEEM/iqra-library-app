-- Add secure ID-card token fields to students.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'students'
      AND column_name = 'id_card_token'
  ) THEN
    ALTER TABLE public.students
      ADD COLUMN id_card_token text;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'students'
      AND column_name = 'id_card_issued_at'
  ) THEN
    ALTER TABLE public.students
      ADD COLUMN id_card_issued_at timestamp with time zone;
  END IF;
END $$;

UPDATE public.students
SET id_card_token = replace((gen_random_uuid())::text, '-', '')
WHERE id_card_token IS NULL OR length(trim(id_card_token)) = 0;

UPDATE public.students
SET id_card_issued_at = COALESCE(id_card_issued_at, created_at, now())
WHERE id_card_token IS NOT NULL;

ALTER TABLE public.students
  ALTER COLUMN id_card_token SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'students_id_card_token_length_check'
  ) THEN
    ALTER TABLE public.students
      ADD CONSTRAINT students_id_card_token_length_check
      CHECK (length(trim(id_card_token)) >= 16);
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS idx_students_id_card_token
  ON public.students (id_card_token);
