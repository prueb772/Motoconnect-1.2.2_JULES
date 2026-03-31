import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FIREBASE_SERVICE_ACCOUNT = Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!;

// ─── Firebase Auth ────────────────────────────────────────────────────────────

async function getFirebaseAccessToken(serviceAccount: Record<string, string>): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const encode = (obj: object) =>
    btoa(JSON.stringify(obj)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");

  const signingInput = `${encode(header)}.${encode(payload)}`;

  const pemKey = serviceAccount.private_key.replace(/\\n/g, "\n");
  const binaryKey = Uint8Array.from(
    atob(pemKey.replace("-----BEGIN PRIVATE KEY-----", "").replace("-----END PRIVATE KEY-----", "").replace(/\s/g, "")),
    (c) => c.charCodeAt(0)
  );
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(signingInput)
  );

  const jwt = `${signingInput}.${btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_")}`;

  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const tokenData = await tokenResponse.json();
  return tokenData.access_token;
}

// ─── FCM Send ─────────────────────────────────────────────────────────────────

async function sendFcmNotification(
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
  accessToken: string,
  projectId: string
): Promise<void> {
  await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${accessToken}`,
    },
    body: JSON.stringify({
      message: {
        token,
        notification: { title, body },
        android: {
          notification: {
            channel_id: "sesiones_channel",
            icon: "ic_launcher",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
        data,
      },
    }),
  });
}

async function sendToTokens(
  tokens: string[],
  title: string,
  body: string,
  data: Record<string, string>,
  accessToken: string,
  projectId: string
): Promise<void> {
  if (tokens.length === 0) return;
  await Promise.allSettled(
    tokens.map((token) => sendFcmNotification(token, title, body, data, accessToken, projectId))
  );
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

async function getFcmTokensForUsers(
  supabase: ReturnType<typeof createClient>,
  userIds: string[]
): Promise<string[]> {
  if (userIds.length === 0) return [];
  const { data } = await supabase
    .from("fcm_tokens")
    .select("token")
    .in("usuario_id", userIds);
  return data?.map((r: { token: string }) => r.token) ?? [];
}

async function getUserName(
  supabase: ReturnType<typeof createClient>,
  userId: string
): Promise<string> {
  const { data } = await supabase
    .from("usuarios")
    .select("nombre")
    .eq("id", userId)
    .single();
  return data?.nombre ?? "Un miembro";
}

async function getGroupName(
  supabase: ReturnType<typeof createClient>,
  grupoId: string
): Promise<string> {
  const { data } = await supabase
    .from("grupos_ruta")
    .select("nombre")
    .eq("id", grupoId)
    .single();
  return data?.nombre ?? "el grupo";
}

async function getGroupMemberIds(
  supabase: ReturnType<typeof createClient>,
  grupoId: string,
  excludeUserId?: string
): Promise<string[]> {
  const { data } = await supabase
    .from("miembros_grupo")
    .select("usuario_id")
    .eq("grupo_id", grupoId);
  const ids = data?.map((m: { usuario_id: string }) => m.usuario_id) ?? [];
  return excludeUserId ? ids.filter((id: string) => id !== excludeUserId) : ids;
}

async function getApprovedParticipantIds(
  supabase: ReturnType<typeof createClient>,
  sesionId: string,
  excludeUserId?: string
): Promise<string[]> {
  const { data } = await supabase
    .from("participantes_sesion")
    .select("usuario_id")
    .eq("sesion_id", sesionId)
    .eq("estado_aprobacion", "aprobado");
  const ids = data?.map((p: { usuario_id: string }) => p.usuario_id) ?? [];
  return excludeUserId ? ids.filter((id: string) => id !== excludeUserId) : ids;
}

async function getGrupoIdFromSesion(
  supabase: ReturnType<typeof createClient>,
  sesionId: string
): Promise<string> {
  const { data } = await supabase
    .from("sesiones_ruta_activa")
    .select("grupo_id")
    .eq("id", sesionId)
    .single();
  return data?.grupo_id ?? "";
}

// ─── Main Handler ─────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  try {
    const payload = await req.json();
    const { event_type } = payload;

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT);
    const accessToken = await getFirebaseAccessToken(serviceAccount);
    const projectId = serviceAccount.project_id;

    // ── Sesión iniciada ──────────────────────────────────────────────────────
    if (event_type === "session_started") {
      const { sesion_id, grupo_id, iniciada_por, nombre_sesion } = payload;

      const [iniciadorNombre, grupoNombre, memberIds] = await Promise.all([
        getUserName(supabase, iniciada_por),
        getGroupName(supabase, grupo_id),
        getGroupMemberIds(supabase, grupo_id, iniciada_por),
      ]);

      const tokens = await getFcmTokensForUsers(supabase, memberIds);

      await sendToTokens(
        tokens,
        `Sesión iniciada en ${grupoNombre}`,
        `${iniciadorNombre} inició la sesión "${nombre_sesion}"`,
        { type: "session_started", sesion_id, grupo_id },
        accessToken,
        projectId
      );

      return new Response(
        JSON.stringify({ message: "Notificaciones enviadas", total: tokens.length }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // ── Miembro aprobado ─────────────────────────────────────────────────────
    if (event_type === "member_joined") {
      const { sesion_id, usuario_id } = payload;

      // Obtener grupo_id de la sesión para incluirlo en el payload de navegación
      const [miembroNombre, participantIds, grupo_id] = await Promise.all([
        getUserName(supabase, usuario_id),
        getApprovedParticipantIds(supabase, sesion_id, usuario_id),
        getGrupoIdFromSesion(supabase, sesion_id),
      ]);

      const tokens = await getFcmTokensForUsers(supabase, participantIds);

      await sendToTokens(
        tokens,
        "Nuevo miembro en la sesión",
        `${miembroNombre} se unió a la sesión`,
        { type: "member_joined", sesion_id, grupo_id },
        accessToken,
        projectId
      );

      return new Response(
        JSON.stringify({ message: "Notificaciones enviadas", total: tokens.length }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // ── Sesión finalizada ────────────────────────────────────────────────────
    if (event_type === "session_ended") {
      const { sesion_id, grupo_id, nombre_sesion } = payload;

      const participantIds = await getApprovedParticipantIds(supabase, sesion_id);
      const tokens = await getFcmTokensForUsers(supabase, participantIds);

      await sendToTokens(
        tokens,
        "Sesión finalizada",
        `La sesión "${nombre_sesion}" ha finalizado`,
        { type: "session_ended", sesion_id, grupo_id },
        accessToken,
        projectId
      );

      return new Response(
        JSON.stringify({ message: "Notificaciones enviadas", total: tokens.length }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // ── SOS ──────────────────────────────────────────────────────────────────
    if (event_type === "sos") {
      const { sesion_id, grupo_id, usuario_id } = payload;

      const [remitente, participantIds] = await Promise.all([
        getUserName(supabase, usuario_id),
        getApprovedParticipantIds(supabase, sesion_id, usuario_id),
      ]);

      const tokens = await getFcmTokensForUsers(supabase, participantIds);

      await sendToTokens(
        tokens,
        "SOS",
        `${remitente} está solicitando apoyo`,
        { type: "sos", sesion_id, grupo_id },
        accessToken,
        projectId
      );

      return new Response(
        JSON.stringify({ message: "SOS enviado", total: tokens.length }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ error: `event_type desconocido: ${event_type}` }),
      { status: 400 }
    );
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), { status: 500 });
  }
});
