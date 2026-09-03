-- Correctif : la table public.resources n'avait pas de colonne class_id
-- (erreur "Could not find the 'class_id' column of 'resources' in the schema cache").
-- À exécuter une seule fois dans le SQL Editor du projet Supabase.

ALTER TABLE public.resources
  ADD COLUMN IF NOT EXISTS class_id uuid REFERENCES public.classes(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS resources_class_idx ON public.resources (class_id);

-- Rafraîchir le cache du schéma de l'API
NOTIFY pgrst, 'reload schema';
