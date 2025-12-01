"use client";

import { useState, useRef, useCallback, useEffect } from "react";

type VoiceState = "idle" | "connecting" | "listening" | "thinking" | "speaking";

interface UseRealtimeVoiceOptions {
  onTranscript?: (text: string, isFinal: boolean) => void;
  onResponse?: (text: string) => void;
  onError?: (error: string) => void;
}

export function useRealtimeVoice(options: UseRealtimeVoiceOptions = {}) {
  const [state, setState] = useState<VoiceState>("idle");
  const [transcript, setTranscript] = useState("");
  const [assistantText, setAssistantText] = useState("");
  
  const wsRef = useRef<WebSocket | null>(null);
  const audioContextRef = useRef<AudioContext | null>(null);
  const mediaStreamRef = useRef<MediaStream | null>(null);
  const processorRef = useRef<ScriptProcessorNode | null>(null);
  const playbackQueueRef = useRef<ArrayBuffer[]>([]);
  const isPlayingRef = useRef(false);
  const responseTextRef = useRef("");

  // Get ephemeral token and connect
  const connect = useCallback(async () => {
    if (wsRef.current?.readyState === WebSocket.OPEN) return;
    
    setState("connecting");
    
    try {
      // Get ephemeral session token from our API
      const tokenResponse = await fetch("/api/realtime", { method: "POST" });
      if (!tokenResponse.ok) {
        throw new Error("Failed to get session token");
      }
      
      const data = await tokenResponse.json();
      // client_secrets returns value directly
      const secret = data.value;
      const config = data.config; // Our custom config with instructions and voice
      if (!secret) {
        console.error("Session response:", data);
        throw new Error("Invalid session response - no secret found");
      }
      console.log("Got ephemeral key:", secret.substring(0, 10) + "...");

      // Connect to OpenAI Realtime API with ephemeral key
      const ws = new WebSocket(
        `wss://api.openai.com/v1/realtime?model=gpt-4o-realtime-preview`,
        ["realtime", `openai-insecure-api-key.${secret}`]
      );

      ws.onopen = () => {
        console.log("Realtime connected");
        
        // Inject workout context as a user message at the start
        if (config?.instructions) {
          console.log("📝 Injecting workout context");
          ws.send(JSON.stringify({
            type: "conversation.item.create",
            item: {
              type: "message",
              role: "user",
              content: [{ 
                type: "input_text", 
                text: `[CONTEXT FOR THIS SESSION - don't respond to this, just use it as background info]\n\n${config.instructions}\n\n[END CONTEXT - wait for my actual question]`
              }]
            }
          }));
        }
        
        startAudioCapture();
        setState("listening");
      };

      ws.onmessage = (event) => {
        const data = JSON.parse(event.data);
        console.log("🔵 Server event:", data.type, data);
        handleServerEvent(data);
      };

      ws.onerror = (error) => {
        console.error("WebSocket error:", error);
        options.onError?.("Connection error");
        setState("idle");
      };

      ws.onclose = () => {
        console.log("Realtime disconnected");
        setState("idle");
        stopAudioCapture();
      };

      wsRef.current = ws;
    } catch (error) {
      console.error("Connection error:", error);
      options.onError?.(error instanceof Error ? error.message : "Connection failed");
      setState("idle");
    }
  }, [options]);

  const disconnect = useCallback(() => {
    stopAudioCapture();
    wsRef.current?.close();
    wsRef.current = null;
    setState("idle");
  }, []);

  const handleServerEvent = useCallback((event: any) => {
    switch (event.type) {
      case "session.created":
        console.log("✅ Session created:", event.session?.id);
        break;
        
      case "session.updated":
        console.log("✅ Session updated");
        break;
        
      case "input_audio_buffer.speech_started":
        console.log("🎙️ Speech started");
        setState("listening");
        break;
        
      case "input_audio_buffer.speech_stopped":
        console.log("🎙️ Speech stopped - thinking...");
        setState("thinking");
        break;
        
      case "input_audio_buffer.committed":
        console.log("📤 Audio buffer committed");
        break;
        
      case "conversation.item.created":
        console.log("💬 Conversation item created:", event.item?.type);
        break;
        
      case "conversation.item.input_audio_transcription.completed":
      case "input_audio_transcription.completed":
      case "transcription.completed":
        const userText = event.transcript || event.text || "";
        console.log("📝 User said:", userText);
        setTranscript(userText);
        options.onTranscript?.(userText, true);
        break;
        
      case "response.created":
        console.log("🤖 Response started");
        responseTextRef.current = "";
        setAssistantText("");
        break;
        
      case "response.output_audio_transcript.delta":
        // Accumulate transcript for display
        responseTextRef.current += event.delta || "";
        setAssistantText(responseTextRef.current);
        options.onResponse?.(event.delta || "");
        break;
        
      case "response.output_audio.delta":
        // Queue audio for playback
        if (event.delta) {
          console.log("🔊 Received audio chunk");
          const audioData = base64ToArrayBuffer(event.delta);
          playbackQueueRef.current.push(audioData);
          playAudioQueue();
        }
        setState("speaking");
        break;
        
      case "response.output_audio.done":
        console.log("🔊 Audio response done");
        setState("listening");
        break;
        
      case "response.done":
        console.log("✅ Response complete");
        break;
        
      case "error":
        console.error("❌ Realtime error:", event.error);
        options.onError?.(event.error?.message || "Unknown error");
        break;
        
      default:
        // Log unhandled events for debugging
        if (!event.type?.includes("delta")) {
          console.log("⚪ Unhandled event:", event.type);
        }
    }
  }, [options]);

  const startAudioCapture = useCallback(async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      mediaStreamRef.current = stream;
      
      const audioContext = new AudioContext({ sampleRate: 24000 });
      audioContextRef.current = audioContext;
      
      const source = audioContext.createMediaStreamSource(stream);
      const processor = audioContext.createScriptProcessor(4096, 1, 1);
      processorRef.current = processor;
      
      let audioChunkCount = 0;
      processor.onaudioprocess = (e) => {
        if (wsRef.current?.readyState !== WebSocket.OPEN) return;
        
        const inputData = e.inputBuffer.getChannelData(0);
        const pcm16 = float32ToPcm16(inputData);
        const base64 = arrayBufferToBase64(pcm16.buffer as ArrayBuffer);
        
        wsRef.current.send(JSON.stringify({
          type: "input_audio_buffer.append",
          audio: base64,
        }));
        
        audioChunkCount++;
        if (audioChunkCount % 50 === 0) {
          console.log(`🎤 Sent ${audioChunkCount} audio chunks`);
        }
      };
      
      source.connect(processor);
      processor.connect(audioContext.destination);
    } catch (error) {
      console.error("Audio capture error:", error);
      options.onError?.("Microphone access denied");
    }
  }, [options]);

  const stopAudioCapture = useCallback(() => {
    processorRef.current?.disconnect();
    mediaStreamRef.current?.getTracks().forEach(track => track.stop());
    if (audioContextRef.current && audioContextRef.current.state !== "closed") {
      audioContextRef.current.close();
    }
  }, []);

  const playAudioQueue = useCallback(async () => {
    if (isPlayingRef.current || playbackQueueRef.current.length === 0) return;
    
    isPlayingRef.current = true;
    console.log("▶️ Starting audio playback, queue size:", playbackQueueRef.current.length);
    
    // Create a new audio context for playback (separate from capture)
    const playbackContext = new AudioContext({ sampleRate: 24000 });
    
    while (playbackQueueRef.current.length > 0) {
      const data = playbackQueueRef.current.shift()!;
      const float32 = pcm16ToFloat32(new Int16Array(data));
      
      const buffer = playbackContext.createBuffer(1, float32.length, 24000);
      buffer.getChannelData(0).set(float32);
      
      const source = playbackContext.createBufferSource();
      source.buffer = buffer;
      source.connect(playbackContext.destination);
      source.start();
      
      await new Promise(resolve => {
        source.onended = resolve;
      });
    }
    
    console.log("⏹️ Audio playback complete");
    isPlayingRef.current = false;
    await playbackContext.close();
  }, []);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      disconnect();
    };
  }, [disconnect]);

  return {
    state,
    transcript,
    assistantText,
    connect,
    disconnect,
    isConnected: wsRef.current?.readyState === WebSocket.OPEN,
  };
}

// Audio conversion utilities
function float32ToPcm16(float32: Float32Array): Int16Array {
  const pcm16 = new Int16Array(float32.length);
  for (let i = 0; i < float32.length; i++) {
    const s = Math.max(-1, Math.min(1, float32[i]));
    pcm16[i] = s < 0 ? s * 0x8000 : s * 0x7FFF;
  }
  return pcm16;
}

function pcm16ToFloat32(pcm16: Int16Array): Float32Array {
  const float32 = new Float32Array(pcm16.length);
  for (let i = 0; i < pcm16.length; i++) {
    float32[i] = pcm16[i] / (pcm16[i] < 0 ? 0x8000 : 0x7FFF);
  }
  return float32;
}

function arrayBufferToBase64(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  let binary = "";
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

function base64ToArrayBuffer(base64: string): ArrayBuffer {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

