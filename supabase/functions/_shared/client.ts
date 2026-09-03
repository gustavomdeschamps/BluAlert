import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

export function adminClient() {
  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  );
}

export async function authenticatedUser(request: Request) {
  const authorization = request.headers.get('Authorization');
  if (!authorization?.startsWith('Bearer ')) throw new Error('UNAUTHORIZED');
  const client = adminClient();
  const { data, error } = await client.auth.getUser(authorization.slice(7));
  if (error || !data.user) throw new Error('UNAUTHORIZED');
  return { client, user: data.user };
}

export function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
  });
}
