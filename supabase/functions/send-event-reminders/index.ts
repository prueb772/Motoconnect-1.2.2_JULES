import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FIREBASE_SERVICE_ACCOUNT = Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!;

// ─── Firebase Auth ───────────────────────────────────────────────────────────

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

// ─── FCM Send ────────────────────────────────────────────────────────────────

async function sendFcmNotification(
  token: string,
  title: string,
  body: string,
  eventId: string,
  notifType: string,
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
            channel_id: "eventos_channel",
            icon: "ic_launcher",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
        data: {
          type: notifType,
          event_id: eventId,
        },
      },
    }),
  });
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

async function getFcmTokens(
  supabase: ReturnType<typeof createClient>,
  userIds: string[]
): Promise<string[]> {
  const { data } = await supabase
    .from("fcm_tokens")
    .select("token")
    .in("usuario_id", userIds);
  return data?.map((r: { token: string }) => r.token) ?? [];
}

async function getParticipantIds(
  supabase: ReturnType<typeof createClient>,
  eventoId: string,
  estados: string[]
): Promise<string[]> {
  const { data } = await supabase
    .from("participantes_eventos")
    .select("usuario_id")
    .eq("evento_id", eventoId)
    .in("estado", estados);
  return data?.map((p: { usuario_id: string }) => p.usuario_id) ?? [];
}

// ─── Main Handler ─────────────────────────────────────────────────────────────

Deno.serve(async (_req: Request) => {
  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const now = new Date();

    // Ventana ±20 minutos alrededor de la marca objetivo.
    // El cron corre cada 30 min, así que ±20 min da un overlap de 10 min entre
    // ejecuciones consecutivas, evitando huecos si el cron se retrasa ligeramente.
    // Los flags reminder_*_sent evitan doble envío en el overlap.
    const window24hStart = new Date(now.getTime() + (24 * 60 - 20) * 60 * 1000);
    const window24hEnd   = new Date(now.getTime() + (24 * 60 + 20) * 60 * 1000);
    const window2hStart  = new Date(now.getTime() + (2  * 60 - 20) * 60 * 1000);
    const window2hEnd    = new Date(now.getTime() + (2  * 60 + 20) * 60 * 1000);

    // Obtener Service Account de Firebase una sola vez
    const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT);
    const accessToken = await getFirebaseAccessToken(serviceAccount);
    const projectId = serviceAccount.project_id;

    let total24h = 0;
    let total2h  = 0;

    // ── Recordatorios 24 horas ──────────────────────────────────────────────

    const { data: eventos24h } = await supabase
      .from("eventos")
      .select("id, titulo")
      .gte("fecha_hora", window24hStart.toISOString())
      .lte("fecha_hora", window24hEnd.toISOString())
      .eq("reminder_24h_sent", false);

    if (eventos24h && eventos24h.length > 0) {
      for (const evento of eventos24h) {
        const userIds = await getParticipantIds(supabase, evento.id, ["confirmado", "posible"]);
        if (userIds.length === 0) {
          await supabase.from("eventos").update({ reminder_24h_sent: true }).eq("id", evento.id);
          continue;
        }

        const tokens = await getFcmTokens(supabase, userIds);
        if (tokens.length > 0) {
          await Promise.allSettled(
            tokens.map((token) =>
              sendFcmNotification(
                token,
                "Recordatorio de Evento",
                `Mañana es el evento "${evento.titulo}", ¡no te lo pierdas!`,
                evento.id,
                "event_reminder_24h",
                accessToken,
                projectId
              )
            )
          );
          total24h += tokens.length;
        }

        await supabase.from("eventos").update({ reminder_24h_sent: true }).eq("id", evento.id);
      }
    }

    // ── Recordatorios 2 horas ───────────────────────────────────────────────

    const { data: eventos2h } = await supabase
      .from("eventos")
      .select("id, titulo")
      .gte("fecha_hora", window2hStart.toISOString())
      .lte("fecha_hora", window2hEnd.toISOString())
      .eq("reminder_2h_sent", false);

    if (eventos2h && eventos2h.length > 0) {
      for (const evento of eventos2h) {
        const userIds = await getParticipantIds(supabase, evento.id, ["confirmado"]);
        if (userIds.length === 0) {
          await supabase.from("eventos").update({ reminder_2h_sent: true }).eq("id", evento.id);
          continue;
        }

        const tokens = await getFcmTokens(supabase, userIds);
        if (tokens.length > 0) {
          await Promise.allSettled(
            tokens.map((token) =>
              sendFcmNotification(
                token,
                "¡Tu evento empieza pronto!",
                `El evento "${evento.titulo}" comienza en 2 horas`,
                evento.id,
                "event_reminder_2h",
                accessToken,
                projectId
              )
            )
          );
          total2h += tokens.length;
        }

        await supabase.from("eventos").update({ reminder_2h_sent: true }).eq("id", evento.id);
      }
    }

    return new Response(
      JSON.stringify({
        message: "Recordatorios procesados",
        recordatorios_24h: total24h,
        recordatorios_2h: total2h,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), { status: 500 });
  }
});
