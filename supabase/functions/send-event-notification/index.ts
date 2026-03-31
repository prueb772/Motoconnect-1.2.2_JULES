import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FIREBASE_SERVICE_ACCOUNT = Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!;

interface EventPayload {
  event_id: string;
  title: string;
  grupo_id: string | null;
  organizer_id: string;
  is_public: boolean;
}

// Obtiene un access token de Firebase usando el Service Account (JWT firmado)
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

  // Importar clave privada RSA del Service Account
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

  // Intercambiar JWT por access token de Google OAuth
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const tokenData = await tokenResponse.json();
  return tokenData.access_token;
}

Deno.serve(async (req: Request) => {
  try {
    const payload: EventPayload = await req.json();
    const { event_id, title, grupo_id, organizer_id, is_public } = payload;

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Obtener nombre del grupo o del creador del evento
    let responsable = "";
    if (grupo_id) {
      const { data: grupo } = await supabase
        .from("grupos_ruta")
        .select("nombre")
        .eq("id", grupo_id)
        .single();
      responsable = grupo?.nombre ?? "";
    }

    if (!responsable) {
      const { data: usuario } = await supabase
        .from("usuarios")
        .select("nombre")
        .eq("id", organizer_id)
        .single();
      responsable = usuario?.nombre ?? "MotoConnect";
    }

    // Obtener tokens FCM según privacidad del evento
    let tokens: string[];

    if (is_public !== false) {
      // Evento público: notificar a todos los usuarios registrados
      const { data: tokenRows, error: tokenError } = await supabase
        .from("fcm_tokens")
        .select("token");

      if (tokenError || !tokenRows || tokenRows.length === 0) {
        return new Response(JSON.stringify({ message: "No hay tokens registrados" }), { status: 200 });
      }
      tokens = tokenRows.map((r: { token: string }) => r.token);
    } else {
      // Evento privado: notificar solo a miembros de los grupos asociados
      const { data: grupos } = await supabase
        .from("evento_grupos")
        .select("grupo_id")
        .eq("evento_id", event_id);

      const grupoIds = grupos?.map((g: any) => g.grupo_id) ?? [];

      if (grupoIds.length === 0) {
        return new Response(JSON.stringify({ message: "Evento privado sin grupos, sin notificaciones" }), { status: 200 });
      }

      const { data: miembros } = await supabase
        .from("miembros_grupo")
        .select("usuario_id")
        .in("grupo_id", grupoIds);

      const userIds = miembros?.map((m: any) => m.usuario_id) ?? [];

      if (userIds.length === 0) {
        return new Response(JSON.stringify({ message: "Sin miembros en los grupos, sin notificaciones" }), { status: 200 });
      }

      const { data: tokenRows, error: tokenError } = await supabase
        .from("fcm_tokens")
        .select("token")
        .in("usuario_id", userIds);

      if (tokenError || !tokenRows || tokenRows.length === 0) {
        return new Response(JSON.stringify({ message: "No hay tokens para los miembros del grupo" }), { status: 200 });
      }
      tokens = tokenRows.map((r: { token: string }) => r.token);
    }

    // Obtener access token de Firebase
    const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT);
    const accessToken = await getFirebaseAccessToken(serviceAccount);
    const projectId = serviceAccount.project_id;

    // Enviar notificación a cada token (FCM HTTP v1 no soporta multicast directo)
    const notificationBody = `"${title}", a cargo de ${responsable}`;
    const sendPromises = tokens.map((token) =>
      fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            token,
            notification: {
              title: "Nuevo Evento",
              body: notificationBody,
            },
            android: {
              notification: {
                channel_id: "eventos_channel",
                icon: "ic_launcher",
                click_action: "FLUTTER_NOTIFICATION_CLICK",
              },
            },
            data: {
              type: "event_created",
              event_id,
            },
          },
        }),
      })
    );

    await Promise.allSettled(sendPromises);

    return new Response(
      JSON.stringify({ message: `Notificaciones enviadas a ${tokens.length} dispositivos` }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), { status: 500 });
  }
});
