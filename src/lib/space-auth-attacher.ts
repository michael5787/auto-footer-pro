import { createMiddleware } from "@tanstack/react-start";
import { supabase } from "@/integrations/supabase/client";
import { getSpaceClient, SPACES, type SpaceKey } from "@/lib/spaces";

/**
 * Each space (talameed / taleem / admin) keeps its session in its own Supabase
 * client with a distinct storage key, so the default generated attacher — which
 * only reads the shared `supabase` client — never finds a token and server
 * functions receive no bearer (they then fail as unauthorized / "Forbidden").
 *
 * This middleware attaches the first available token: the shared client first,
 * then each space client.
 */
export const attachSpaceAuth = createMiddleware({ type: "function" }).client(async ({ next }) => {
  let token: string | undefined;

  const { data } = await supabase.auth.getSession();
  token = data.session?.access_token;

  if (!token && typeof window !== "undefined") {
    const order: SpaceKey[] = ["admin", ...(Object.keys(SPACES) as SpaceKey[])];
    for (const space of order) {
      const { data: spaceData } = await getSpaceClient(space).auth.getSession();
      if (spaceData.session?.access_token) {
        token = spaceData.session.access_token;
        break;
      }
    }
  }

  return next({ headers: token ? { Authorization: `Bearer ${token}` } : {} });
});
