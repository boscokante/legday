import OpenAI from "openai";
import { buildSystemPrompt } from "../../../lib/systemPrompt";

const openaiClient = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

export async function POST(request: Request) {
  if (!process.env.OPENAI_API_KEY) {
    return new Response(
      JSON.stringify({ error: "Missing OPENAI_API_KEY. Add it to coach-web/.env.local." }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }

  try {
    const body = await request.json();
    const history = (body?.messages ?? []) as { role: "user" | "assistant"; content: string }[];

    const stream = await openaiClient.chat.completions.create({
      model: "gpt-5-mini",
      messages: [{ role: "system", content: buildSystemPrompt() }, ...history],
      max_completion_tokens: 1200,  // GPT-5 needs ~700 for reasoning + output
      stream: true,
    });

    // Create a streaming response
    const encoder = new TextEncoder();
    let totalContent = "";
    
    const readable = new ReadableStream({
      async start(controller) {
        try {
          for await (const chunk of stream) {
            const content = chunk.choices[0]?.delta?.content;
            if (content) {
              totalContent += content;
              controller.enqueue(encoder.encode(`data: ${JSON.stringify({ content })}\n\n`));
            }
          }
          console.log("Stream complete, total content length:", totalContent.length);
          if (!totalContent) {
            console.warn("No content received from stream");
            controller.enqueue(encoder.encode(`data: ${JSON.stringify({ content: "Thinking... (no response yet)" })}\n\n`));
          }
          controller.enqueue(encoder.encode("data: [DONE]\n\n"));
          controller.close();
        } catch (streamError) {
          console.error("Stream error:", streamError);
          controller.enqueue(encoder.encode(`data: ${JSON.stringify({ content: "Stream error occurred" })}\n\n`));
          controller.enqueue(encoder.encode("data: [DONE]\n\n"));
          controller.close();
        }
      },
    });

    return new Response(readable, {
      headers: {
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
        "Connection": "keep-alive",
      },
    });
  } catch (error) {
    console.error("Chat API error:", error);
    const errorMessage = error instanceof Error ? error.message : String(error);
    return new Response(
      JSON.stringify({ error: `OpenAI API error: ${errorMessage}` }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
}
