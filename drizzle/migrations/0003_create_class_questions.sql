CREATE TABLE public.questions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id uuid NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
  student_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  teacher_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  title text NOT NULL,
  body text,
  file_path text,
  file_name text,
  mime_type text,
  file_size bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX questions_class_idx ON public.questions (class_id, created_at DESC);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.questions TO authenticated;
GRANT ALL ON public.questions TO service_role;

ALTER TABLE public.questions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Read questions of own class"
ON public.questions FOR SELECT TO authenticated
USING (
  auth.uid() = student_id
  OR public.has_role(auth.uid(), 'super_admin')
  OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.class_id = questions.class_id)
  OR EXISTS (SELECT 1 FROM public.teacher_classes tc WHERE tc.teacher_id = auth.uid() AND tc.class_id = questions.class_id)
);

CREATE POLICY "Students ask questions in own class"
ON public.questions FOR INSERT TO authenticated
WITH CHECK (
  auth.uid() = student_id
  AND EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.class_id = questions.class_id)
);

CREATE POLICY "Authors update own questions"
ON public.questions FOR UPDATE TO authenticated
USING (auth.uid() = student_id) WITH CHECK (auth.uid() = student_id);

CREATE POLICY "Authors delete own questions"
ON public.questions FOR DELETE TO authenticated
USING (auth.uid() = student_id OR public.has_role(auth.uid(), 'super_admin'));

CREATE TRIGGER update_questions_updated_at
BEFORE UPDATE ON public.questions
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TABLE public.question_answers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  question_id uuid NOT NULL REFERENCES public.questions(id) ON DELETE CASCADE,
  teacher_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  body text,
  file_path text,
  file_name text,
  mime_type text,
  file_size bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX question_answers_question_idx ON public.question_answers (question_id, created_at);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.question_answers TO authenticated;
GRANT ALL ON public.question_answers TO service_role;

ALTER TABLE public.question_answers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Read answers of visible questions"
ON public.question_answers FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.questions q
    WHERE q.id = question_answers.question_id
      AND (
        q.student_id = auth.uid()
        OR public.has_role(auth.uid(), 'super_admin')
        OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.class_id = q.class_id)
        OR EXISTS (SELECT 1 FROM public.teacher_classes tc WHERE tc.teacher_id = auth.uid() AND tc.class_id = q.class_id)
      )
  )
);

CREATE POLICY "Teachers answer questions of their classes"
ON public.question_answers FOR INSERT TO authenticated
WITH CHECK (
  auth.uid() = teacher_id
  AND EXISTS (
    SELECT 1 FROM public.questions q
    JOIN public.teacher_classes tc ON tc.class_id = q.class_id
    WHERE q.id = question_answers.question_id AND tc.teacher_id = auth.uid()
  )
);

CREATE POLICY "Teachers update own answers"
ON public.question_answers FOR UPDATE TO authenticated
USING (auth.uid() = teacher_id) WITH CHECK (auth.uid() = teacher_id);

CREATE POLICY "Teachers delete own answers"
ON public.question_answers FOR DELETE TO authenticated
USING (auth.uid() = teacher_id OR public.has_role(auth.uid(), 'super_admin'));

CREATE TRIGGER update_question_answers_updated_at
BEFORE UPDATE ON public.question_answers
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE POLICY "Read question files of own class"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'questions'
  AND (
    owner = auth.uid()
    OR public.has_role(auth.uid(), 'super_admin')
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.class_id::text = (storage.foldername(name))[1]
    )
    OR EXISTS (
      SELECT 1 FROM public.teacher_classes tc
      WHERE tc.teacher_id = auth.uid() AND tc.class_id::text = (storage.foldername(name))[1]
    )
  )
);

CREATE POLICY "Upload question files in own class"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'questions'
  AND (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.class_id::text = (storage.foldername(name))[1]
    )
    OR EXISTS (
      SELECT 1 FROM public.teacher_classes tc
      WHERE tc.teacher_id = auth.uid() AND tc.class_id::text = (storage.foldername(name))[1]
    )
  )
);

CREATE POLICY "Delete own question files"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'questions'
  AND (owner = auth.uid() OR public.has_role(auth.uid(), 'super_admin'))
);

CREATE OR REPLACE FUNCTION public.shares_class(_viewer uuid, _target uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles v
    JOIN public.profiles t ON t.class_id = v.class_id
    WHERE v.id = _viewer AND t.id = _target AND v.class_id IS NOT NULL
  )
  OR EXISTS (
    SELECT 1
    FROM public.profiles v
    JOIN public.teacher_classes tc ON tc.class_id = v.class_id
    WHERE v.id = _viewer AND tc.teacher_id = _target AND v.class_id IS NOT NULL
  )
$$;

REVOKE EXECUTE ON FUNCTION public.shares_class(uuid, uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.shares_class(uuid, uuid) TO authenticated;

CREATE POLICY "Classmates and class teachers read profiles"
ON public.profiles
FOR SELECT
TO authenticated
USING (public.shares_class(auth.uid(), id));