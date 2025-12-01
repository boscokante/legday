"use client";

import { FormEvent, useState, useCallback, useEffect, useRef } from "react";
import { getRotationStatus, getTodayPlan, WorkoutExercise, RotationTile, WorkoutPlan } from "../lib/sampleData";
import { useRealtimeVoice } from "../lib/useRealtimeVoice";

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

// Superset state type
type SupersetState = {
  exerciseA: string | null;
  exerciseB: string | null;
};

// Default rotation status for initial render (avoids hydration mismatch)
const defaultRotationStatus = {
  primary: [
    { label: "Leg", daysSince: 0 },
    { label: "Push", daysSince: 0 },
    { label: "Pull", daysSince: 0 },
    { label: "Core", daysSince: 0 },
    { label: "Achilles", daysSince: 0 },
  ],
  secondary: [
    { label: "Bike", daysSince: 0 },
    { label: "Hoop", daysSince: 0 },
  ],
};

export default function Home() {
  const [messages, setMessages] = useState<ChatMessage[]>(initialMessages);
  const [input, setInput] = useState("");
  const [isSending, setIsSending] = useState(false);
  const [exercises, setExercises] = useState<WorkoutExercise[]>([]);
  const [currentExerciseIndex, setCurrentExerciseIndex] = useState(0);
  const [rotationStatus, setRotationStatus] = useState(defaultRotationStatus);
  const [todayPlan, setTodayPlan] = useState<WorkoutPlan | null>(null);
  
  // Superset dashboard state - one from primary day, one from secondary day
  const [superset, setSuperset] = useState<SupersetState>({
    exerciseA: null,
    exerciseB: null,
  });

  // Calculate date-dependent values on client only to avoid hydration mismatch
  useEffect(() => {
    const rotation = getRotationStatus();
    const plan = getTodayPlan();
    setRotationStatus(rotation);
    setTodayPlan(plan);
    setExercises(plan.exercises.map((ex) => ({
      ...ex,
      sets: ex.sets.map((set) => ({ ...set, completed: false })),
    })));
    setSuperset({
      exerciseA: plan.primaryExercises[0] ?? null,
      exerciseB: plan.secondaryExercises[0] ?? null,
    });
  }, []);

  // Voice agent state
  const [voiceTranscript, setVoiceTranscript] = useState("");
  
  const handleVoiceTranscript = useCallback((text: string, isFinal: boolean) => {
    setVoiceTranscript(text);
    if (isFinal && text.trim()) {
      // Reset response accumulator for next response
      voiceResponseRef.current = "";
      // Add user message from voice
      setMessages(prev => [...prev, { role: "user", content: text }]);
    }
  }, []);

  const voiceResponseRef = useRef("");
  
  const handleVoiceResponse = useCallback((deltaText: string) => {
    // Accumulate the response text
    voiceResponseRef.current += deltaText;
    const fullText = voiceResponseRef.current;
    
    setMessages(prev => {
      const last = prev[prev.length - 1];
      // If the last message is assistant and we're in the middle of a response, update it
      if (last?.role === "assistant" && fullText.startsWith(last.content.substring(0, 10))) {
        return [...prev.slice(0, -1), { role: "assistant", content: fullText }];
      }
      // New response - add new message
      return [...prev, { role: "assistant", content: fullText }];
    });
  }, []);

  const { state: voiceState, connect: connectVoice, disconnect: disconnectVoice } = useRealtimeVoice({
    onTranscript: handleVoiceTranscript,
    onResponse: handleVoiceResponse,
    onError: (error) => {
      console.error("Voice error:", error);
      setMessages(prev => [...prev, { role: "assistant", content: `Voice error: ${error}` }]);
    },
  });

  // Get exercise data by name
  const getExercise = (name: string | null) => 
    name ? exercises.find((ex) => ex.name === name) : null;

  // Mark the current (first incomplete) set as done
  const markSetDone = (exerciseName: string) => {
    setExercises((prev) =>
      prev.map((ex) => {
        if (ex.name !== exerciseName) return ex;
        const firstIncomplete = ex.sets.findIndex((s) => !s.completed);
        if (firstIncomplete === -1) return ex;
        return {
          ...ex,
          sets: ex.sets.map((s, i) =>
            i === firstIncomplete ? { ...s, completed: true } : s
          ),
        };
      })
    );
  };

  async function handleSend(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!input.trim()) return;

    const nextMessages = [...messages, { role: "user" as const, content: input.trim() }];
    setMessages(nextMessages);
    setInput("");
    setIsSending(true);

    // Add placeholder for streaming response
    const placeholderMessages = [...nextMessages, { role: "assistant" as const, content: "" }];
    setMessages(placeholderMessages);

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

      // Handle streaming response
      const reader = response.body?.getReader();
      const decoder = new TextDecoder();
      let accumulatedContent = "";

      if (reader) {
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;

          const chunk = decoder.decode(value, { stream: true });
          const lines = chunk.split("\n");

          for (const line of lines) {
            if (line.startsWith("data: ")) {
              const data = line.slice(6);
              if (data === "[DONE]") continue;
              try {
                const parsed = JSON.parse(data);
                if (parsed.content) {
                  accumulatedContent += parsed.content;
                  setMessages([
                    ...nextMessages,
                    { role: "assistant", content: accumulatedContent },
                  ]);
                }
              } catch {
                // Skip invalid JSON
              }
            }
          }
        }
      }

      // If no content was received, show error
      if (!accumulatedContent) {
        setMessages([
          ...nextMessages,
          { role: "assistant", content: "I received an empty response. Please try again." },
        ]);
      }
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
          
          {/* Superset Dashboard */}
          {superset.exerciseA && (
            <div className="border-b border-white/10 py-3">
              <div className="flex gap-3">
                <SupersetCard
                  exercise={getExercise(superset.exerciseA)}
                  onDone={() => superset.exerciseA && markSetDone(superset.exerciseA)}
                />
                {superset.exerciseB && (
                  <SupersetCard
                    exercise={getExercise(superset.exerciseB)}
                    onDone={() => superset.exerciseB && markSetDone(superset.exerciseB)}
                  />
                )}
              </div>
              <button
                onClick={() => setSuperset({ exerciseA: null, exerciseB: null })}
                className="mt-2 flex items-center gap-1 text-xs text-slate-500 hover:text-slate-300 mx-auto"
              >
                <span>×</span> Clear
              </button>
            </div>
          )}
          
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
            <button
              type="button"
              onClick={() => voiceState === "idle" ? connectVoice() : disconnectVoice()}
              className={`rounded-2xl px-4 py-2 text-sm font-semibold transition ${
                voiceState === "idle" 
                  ? "bg-slate-700 text-white hover:bg-slate-600" 
                  : voiceState === "listening"
                  ? "bg-green-600 text-white animate-pulse"
                  : voiceState === "thinking"
                  ? "bg-yellow-600 text-white"
                  : voiceState === "speaking"
                  ? "bg-purple-600 text-white"
                  : "bg-blue-600 text-white"
              }`}
            >
              {voiceState === "idle" ? "🎤" : 
               voiceState === "listening" ? "🔴" :
               voiceState === "thinking" ? "🤔" :
               voiceState === "speaking" ? "🔊" : "⏳"}
            </button>
          </form>
        </section>
        <section className="space-y-4 rounded-2xl border border-white/10 bg-slate-900 p-4 shadow-lg">
          <header className="border-b border-white/10 pb-3">
            <h2 className="text-lg font-semibold">Rotation Dashboard</h2>
            <p className="text-xs uppercase tracking-wide text-blue-300">Today: {todayPlan?.focus ?? "Loading..."}</p>
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

function SupersetCard({
  exercise,
  onDone,
}: {
  exercise: WorkoutExercise | null | undefined;
  onDone: () => void;
}) {
  if (!exercise) return null;

  const completedCount = exercise.sets.filter((s) => s.completed).length;
  const totalCount = exercise.sets.length;
  const currentSetIndex = exercise.sets.findIndex((s) => !s.completed);
  const currentSet = currentSetIndex >= 0 ? exercise.sets[currentSetIndex] : null;
  const isComplete = currentSet === null && totalCount > 0;

  // Shorten long names
  const shortName =
    exercise.name.length > 18
      ? exercise.name.split(" ").slice(0, 2).join(" ")
      : exercise.name;

  return (
    <div
      className={`flex-1 rounded-xl p-3 ${
        isComplete
          ? "bg-green-900/30 border border-green-500/30"
          : "bg-slate-800/80"
      }`}
    >
      <p className="text-sm font-semibold text-slate-100 truncate">{shortName}</p>

      {totalCount === 0 ? (
        <p className="text-xs text-slate-500 mt-1">No sets</p>
      ) : isComplete ? (
        <div className="flex items-center gap-1.5 mt-1">
          <span className="text-green-400">✓</span>
          <span className="text-xs text-green-400 font-medium">Done!</span>
        </div>
      ) : currentSet ? (
        <>
          <p className="text-xs text-slate-400 mt-1">
            Set {completedCount + 1} of {totalCount}
          </p>
          <div className="flex items-baseline gap-1 mt-1">
            <span className="text-lg font-bold tabular-nums text-white">
              {currentSet.targetWeight}
            </span>
            <span className="text-xs text-slate-500">lbs</span>
            <span className="text-slate-500 mx-0.5">×</span>
            <span className="text-lg font-bold tabular-nums text-white">
              {currentSet.targetReps}
            </span>
          </div>
          <button
            onClick={onDone}
            className="mt-2 w-full rounded-md bg-blue-600 py-1.5 text-xs font-semibold text-white hover:bg-blue-500 transition"
          >
            Done
          </button>
        </>
      ) : null}
    </div>
  );
}
