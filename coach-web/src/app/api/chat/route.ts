import { NextResponse } from "next/server";
import OpenAI from "openai";
import { buildSystemPrompt } from "../../../lib/systemPrompt";

const openaiClient = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

export async function POST(request: Request) {
  if (!process.env.OPENAI_API_KEY) {
    return NextResponse.json(
      { error: "Missing OPENAI_API_KEY. Add it to coach-web/.env.local." },
      { status: 500 },
    );
  }

  try {
    const body = await request.json();
    const history = (body?.messages ?? []) as { role: "user" | "assistant"; content: string }[];

    console.log("Making OpenAI request with model: gpt-4o-mini");
    const response = await openaiClient.chat.completions.create({
      model: "gpt-4o-mini",
      messages: [{ role: "system", content: buildSystemPrompt() }, ...history],
      max_completion_tokens: 220,
    });

    console.log("OpenAI response:", JSON.stringify(response, null, 2));
    const reply = response.choices[0]?.message?.content ?? "I'm not sure how to respond.";
    console.log("Extracted reply:", reply);
    
    if (!reply || reply.trim() === "") {
      console.warn("Empty reply received from OpenAI");
      return NextResponse.json({ reply: "I received an empty response. Please try again." });
    }
    
    return NextResponse.json({ reply });
  } catch (error) {
    console.error("Chat API error:", error);
    const errorMessage = error instanceof Error ? error.message : String(error);
    return NextResponse.json(
      { error: `OpenAI API error: ${errorMessage}` },
      { status: 500 }
    );
  }
}

