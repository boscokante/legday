export const runtime = "nodejs";

import { buildSystemPrompt } from "../../../lib/systemPrompt";

// Create an ephemeral token for client-side WebSocket connection
export async function POST() {
  const apiKey = process.env.OPENAI_API_KEY;
  
  if (!apiKey) {
    return new Response(
      JSON.stringify({ error: "Missing OPENAI_API_KEY" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }

  try {
    // Use client_secrets endpoint for GA API
    const response = await fetch("https://api.openai.com/v1/realtime/client_secrets", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({}),
    });

    if (!response.ok) {
      const error = await response.text();
      console.error("OpenAI session error:", response.status, error);
      return new Response(
        JSON.stringify({ error: `Failed to create realtime session: ${error}` }),
        { status: response.status, headers: { "Content-Type": "application/json" } }
      );
    }

    const data = await response.json();
    // Add our config to pass to client
    data.config = {
      instructions: buildSystemPrompt(),
      voice: "shimmer"
    };
    console.log("OpenAI session response with config");
    return new Response(JSON.stringify(data), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Realtime session error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
}

