"use client";

import { FormEvent, useState } from "react";
import { rotationStatus, todayPlan, WorkoutExercise } from "../lib/sampleData";

type ChatMessage = {
  role: "user" | "assistant";
  content: string;
};

const initialMessages: ChatMessage[] = [
  {
    role: "assistant",
    content:
      "Coach ready. We're on Push + Core with Achilles light. Tell me when you're set for the first bench press set (5 reps @ 205).",
  },
];

// Initialize exercises with completed state
const initialExercises: WorkoutExercise[] = todayPlan.exercises.map((ex) => ({
  ...ex,
  sets: ex.sets.map((set) => ({ ...set, completed: false })),
}));

export default function Home() {
  const [messages, setMessages] = useState<ChatMessage[]>(initialMessages);
  const [input, setInput] = useState("");
  const [isSending, setIsSending] = useState(false);
  const [exercises, setExercises] = useState<WorkoutExercise[]>(initialExercises);
  const [currentExerciseIndex, setCurrentExerciseIndex] = useState(0);

  async function handleSend(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!input.trim()) return;

    const nextMessages = [...messages, { role: "user" as const, content: input.trim() }];
    setMessages(nextMessages);
    setInput("");
    setIsSending(true);

    try {
      const response = await fetch("/api/chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ messages: nextMessages }),
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        throw new Error(errorData.error || `HTTP ${response.status}`);
      }

      const data = await response.json();
      setMessages([
        ...nextMessages,
        { role: "assistant", content: data.reply ?? data.error ?? "I couldn't reach the coach." },
      ]);
    } catch (error) {
      console.error("Chat error:", error);
      setMessages([
        ...nextMessages,
        { role: "assistant", content: `Error: ${error instanceof Error ? error.message : "Connection issue. Try again in a moment."}` },
      ]);
    } finally {
      setIsSending(false);
    }
  }

  return (
    <div className="min-h-screen bg-slate-950 p-6 text-slate-50">
      <div className="mx-auto grid max-w-6xl gap-6 md:grid-cols-[3fr,2fr]">
        <section className="flex flex-col rounded-2xl border border-white/10 bg-slate-900 p-4 shadow-lg">
          <header className="border-b border-white/10 pb-4">
            <h1 className="text-xl font-semibold">Coach Chat</h1>
            <p className="text-sm text-slate-400">Streamlined text sandbox for trainer flow.</p>
          </header>
          <div className="flex flex-1 flex-col gap-3 overflow-y-auto py-4">
            {messages.map((message, index) => (
              <div
                key={index}
                className={`max-w-[90%] rounded-2xl px-4 py-3 text-sm leading-6 ${
                  message.role === "user"
                    ? "ml-auto bg-blue-600 text-white"
                    : "mr-auto bg-slate-800 text-slate-100"
                }`}
              >
                {message.content}
              </div>
            ))}
            {isSending && (
              <div className="mr-auto rounded-2xl bg-slate-800 px-4 py-3 text-sm text-slate-200">
                Coach is thinking…
              </div>
            )}
          </div>
          <form onSubmit={handleSend} className="flex gap-3 pt-2">
            <input
              className="flex-1 rounded-2xl border border-white/10 bg-slate-950 px-4 py-3 text-sm text-white focus:border-blue-500 focus:outline-none"
              placeholder="Tell the coach how the set went…"
              value={input}
              onChange={(event) => setInput(event.target.value)}
            />
            <button
              type="submit"
              disabled={isSending}
              className="rounded-2xl bg-blue-500 px-5 py-2 text-sm font-semibold text-white transition hover:bg-blue-400 disabled:opacity-40"
            >
              Send
            </button>
          </form>
        </section>
        <section className="space-y-4 rounded-2xl border border-white/10 bg-slate-900 p-4 shadow-lg">
          <header className="border-b border-white/10 pb-3">
            <h2 className="text-lg font-semibold">Rotation Dashboard</h2>
            <p className="text-xs uppercase tracking-wide text-blue-300">Today: {todayPlan.focus}</p>
          </header>
          <div className="grid grid-cols-2 gap-3">
            {rotationStatus.primary.map((tile) => (
              <Tile key={tile.label} label={tile.label} days={tile.daysSince} highlight />
            ))}
          </div>
          <div className="grid grid-cols-2 gap-3">
            {rotationStatus.secondary.map((tile) => (
              <Tile key={tile.label} label={tile.label} days={tile.daysSince} />
            ))}
          </div>
          <div className="rounded-2xl border border-white/10 bg-slate-950/60 p-4 text-sm text-slate-200">
            <p className="text-xs uppercase tracking-wide text-slate-400 mb-3">Current Exercises</p>
            <div className="space-y-4">
              {exercises
                .slice(currentExerciseIndex, currentExerciseIndex + 2)
                .map((exercise, idx) => {
                  const globalIdx = currentExerciseIndex + idx;
                  const completedCount = exercise.sets.filter((s) => s.completed).length;
                  const totalSets = exercise.sets.length;
                  
                  return (
                    <div key={exercise.name} className="rounded-lg bg-white/5 p-3">
                      <div className="flex items-center justify-between mb-2">
                        <p className="text-slate-200 font-medium">{exercise.name}</p>
                        <p className="text-xs text-blue-300">
                          {completedCount}/{totalSets} sets
                        </p>
                      </div>
                      <div className="flex flex-wrap gap-2">
                        {exercise.sets.map((set, setIdx) => (
                          <div
                            key={setIdx}
                            className={`flex items-center gap-1.5 rounded-md px-2 py-1 text-xs ${
                              set.completed
                                ? "bg-green-600/30 text-green-300"
                                : "bg-white/5 text-slate-400"
                            }`}
                          >
                            <input
                              type="checkbox"
                              checked={set.completed || false}
                              onChange={() => {
                                const updated = [...exercises];
                                updated[globalIdx].sets[setIdx].completed = !set.completed;
                                setExercises(updated);
                              }}
                              className="h-3 w-3 rounded border-white/20 accent-green-500"
                            />
                            <span>
                              {set.targetReps} @ {set.targetWeight}lb
                            </span>
                          </div>
                        ))}
                      </div>
                    </div>
                  );
                })}
            </div>
            {exercises.length > 2 && (
              <div className="mt-4 flex justify-center gap-2">
                <button
                  onClick={() => setCurrentExerciseIndex(Math.max(0, currentExerciseIndex - 2))}
                  disabled={currentExerciseIndex === 0}
                  className="rounded-lg bg-white/5 px-3 py-1.5 text-xs text-slate-300 disabled:opacity-30 disabled:cursor-not-allowed hover:bg-white/10"
                >
                  ← Previous
                </button>
                <button
                  onClick={() =>
                    setCurrentExerciseIndex(
                      Math.min(exercises.length - 2, currentExerciseIndex + 2)
                    )
                  }
                  disabled={currentExerciseIndex >= exercises.length - 2}
                  className="rounded-lg bg-white/5 px-3 py-1.5 text-xs text-slate-300 disabled:opacity-30 disabled:cursor-not-allowed hover:bg-white/10"
                >
                  Next →
                </button>
              </div>
            )}
          </div>
        </section>
      </div>
    </div>
  );
}

function Tile({ label, days, highlight }: { label: string; days: number; highlight?: boolean }) {
  const palette = ["bg-green-600/60", "bg-amber-500/60", "bg-orange-600/60", "bg-rose-600/60"];
  const color = highlight ? palette[Math.min(days, palette.length - 1)] : "bg-slate-800";

  return (
    <div className={`rounded-2xl p-4 text-center ${color}`}>
      <p className="text-xs uppercase tracking-wide text-white/70">{label}</p>
      <p className="text-2xl font-semibold text-white">{days}d</p>
    </div>
  );
}
