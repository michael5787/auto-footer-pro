CREATE TABLE public.absences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL,
  teacher_id uuid NOT NULL,
  class_id uuid REFERENCES public.classes(id) ON DELETE SET NULL,
  start_date date NOT NULL,
  end_date date NOT NULL,
  reason text,
  justified boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT absences_range CHECK (end_date >= start_date),
  CONSTRAINT absences_reason_len CHECK (reason IS NULL OR char_length(reason) <= 200)
);
CREATE INDEX absences_student_idx ON public.absences(student_id, start_date DESC);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.absences TO authenticated;
GRANT ALL ON public.absences TO service_role;
ALTER TABLE public.absences ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Students view own absences" ON public.absences FOR SELECT TO authenticated
  USING (student_id = auth.uid() OR teacher_id = auth.uid() OR public.teaches_student(auth.uid(), student_id) OR public.has_role(auth.uid(), 'super_admin'));
CREATE POLICY "Teachers add absences" ON public.absences FOR INSERT TO authenticated
  WITH CHECK (teacher_id = auth.uid() AND (public.teaches_student(auth.uid(), student_id) OR public.has_role(auth.uid(), 'super_admin')));
CREATE POLICY "Teachers update own absences" ON public.absences FOR UPDATE TO authenticated
  USING (teacher_id = auth.uid() OR public.has_role(auth.uid(), 'super_admin'));
CREATE POLICY "Teachers delete own absences" ON public.absences FOR DELETE TO authenticated
  USING (teacher_id = auth.uid() OR public.has_role(auth.uid(), 'super_admin'));

CREATE TABLE public.behavior_grades (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  student_id uuid NOT NULL,
  teacher_id uuid NOT NULL,
  class_id uuid REFERENCES public.classes(id) ON DELETE SET NULL,
  grade numeric(5,2) NOT NULL CHECK (grade >= 0 AND grade <= 20),
  comment text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (student_id, teacher_id)
);
CREATE INDEX behavior_grades_student_idx ON public.behavior_grades (student_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.behavior_grades TO authenticated;
GRANT ALL ON public.behavior_grades TO service_role;
ALTER TABLE public.behavior_grades ENABLE ROW LEVEL SECURITY;
CREATE TRIGGER update_behavior_grades_updated_at
BEFORE UPDATE ON public.behavior_grades
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE POLICY "Read behavior grades" ON public.behavior_grades FOR SELECT TO authenticated
USING (
  auth.uid() = student_id OR auth.uid() = teacher_id
  OR public.has_role(auth.uid(), 'super_admin'::public.app_role)
  OR EXISTS (SELECT 1 FROM public.teacher_classes tc
             WHERE tc.class_id = behavior_grades.class_id AND tc.teacher_id = auth.uid())
);
CREATE POLICY "Teachers write behavior grades" ON public.behavior_grades FOR INSERT TO authenticated
WITH CHECK (
  auth.uid() = teacher_id AND (
    public.has_role(auth.uid(), 'super_admin'::public.app_role)
    OR EXISTS (SELECT 1 FROM public.teacher_classes tc
               WHERE tc.class_id = behavior_grades.class_id AND tc.teacher_id = auth.uid())
  )
);
CREATE POLICY "Teachers update behavior grades" ON public.behavior_grades FOR UPDATE TO authenticated
USING (auth.uid() = teacher_id OR public.has_role(auth.uid(), 'super_admin'::public.app_role))
WITH CHECK (auth.uid() = teacher_id OR public.has_role(auth.uid(), 'super_admin'::public.app_role));
CREATE POLICY "Teachers delete behavior grades" ON public.behavior_grades FOR DELETE TO authenticated
USING (auth.uid() = teacher_id OR public.has_role(auth.uid(), 'super_admin'::public.app_role));

ALTER TABLE public.agenda_events ALTER COLUMN event_date DROP NOT NULL;
ALTER TABLE public.agenda_events ADD COLUMN trimester text;
ALTER TABLE public.agenda_events ADD CONSTRAINT agenda_events_trimester_check CHECK (trimester IS NULL OR trimester IN ('1','2','3'));
COMMENT ON COLUMN public.agenda_events.event_date IS 'NULL = évaluation par défaut non programmée (cachée des élèves jusqu''à attribution d''une date)';