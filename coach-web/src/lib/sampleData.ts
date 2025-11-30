import userData from "./userData.json";

export type RotationTile = {
  label: string;
  daysSince: number;
};

export type WorkoutSet = {
  targetReps: number;
  targetWeight: number;
  completed?: boolean;
};

export type WorkoutExercise = {
  name: string;
  sets: WorkoutSet[];
};

export type WorkoutPlan = {
  focus: string;
  achilles: "heavy" | "light";
  notes: string;
  exercises: WorkoutExercise[];
};

// Calculate days since each workout type from real data
function calculateRotationStatus(): { primary: RotationTile[]; secondary: RotationTile[] } {
  const workouts = userData.workouts as Array<{
    date: number;
    day: string;
    exercises: Record<string, Array<{ weight: number; reps: number; warmup?: boolean }>>;
  }>;
  
  const now = Date.now() / 1000; // Convert to Unix timestamp
  const dayInSeconds = 86400;
  
  const daysSinceByType: Record<string, number> = {};
  
  // Find most recent workout for each type
  for (const workout of workouts) {
    const dayLower = workout.day.toLowerCase();
    const daysSince = Math.floor((now - workout.date) / dayInSeconds);
    
    // Map workout names to categories
    let category = "";
    if (dayLower.includes("leg")) category = "Leg";
    else if (dayLower.includes("push")) category = "Push";
    else if (dayLower.includes("pull")) category = "Pull";
    else if (dayLower.includes("core")) category = "Core";
    else if (dayLower.includes("achilles")) category = "Achilles";
    else if (dayLower.includes("hoop")) category = "Hoop";
    else if (dayLower.includes("bike")) category = "Bike";
    
    if (category && (!(category in daysSinceByType) || daysSince < daysSinceByType[category])) {
      daysSinceByType[category] = daysSince;
    }
  }
  
  return {
    primary: [
      { label: "Leg", daysSince: daysSinceByType["Leg"] ?? 999 },
      { label: "Push", daysSince: daysSinceByType["Push"] ?? 999 },
      { label: "Pull", daysSince: daysSinceByType["Pull"] ?? 999 },
      { label: "Core", daysSince: daysSinceByType["Core"] ?? 999 },
      { label: "Achilles", daysSince: daysSinceByType["Achilles"] ?? 999 },
    ],
    secondary: [
      { label: "Bike", daysSince: daysSinceByType["Bike"] ?? 999 },
      { label: "Hoop", daysSince: daysSinceByType["Hoop"] ?? 999 },
    ],
  };
}

// Get the most recent workout for a given day type and build today's plan
function buildTodayPlan(primaryDayId: string, secondaryDayId?: string): WorkoutPlan {
  const workouts = userData.workouts as Array<{
    date: number;
    day: string;
    exercises: Record<string, Array<{ weight: number; reps: number; warmup?: boolean }>>;
  }>;
  const workoutDays = userData.workoutDays as Array<{
    id: string;
    name: string;
    exercises: string[];
  }>;
  
  const primaryDay = workoutDays.find(d => d.id === primaryDayId);
  const secondaryDay = secondaryDayId ? workoutDays.find(d => d.id === secondaryDayId) : null;
  
  const focus = secondaryDay 
    ? `${primaryDay?.name ?? primaryDayId} + ${secondaryDay.name}`
    : primaryDay?.name ?? primaryDayId;
  
  const achilles: "heavy" | "light" = secondaryDayId?.includes("light") ? "light" : "heavy";
  
  // Get exercises from config
  const exerciseNames = [
    ...(primaryDay?.exercises ?? []),
    ...(secondaryDay?.exercises ?? []),
  ];
  
  // Build exercises with sets from most recent completion
  const exercises: WorkoutExercise[] = [];
  
  for (const exerciseName of exerciseNames) {
    // Find most recent workout containing this exercise
    let foundSets: WorkoutSet[] = [];
    
    const sortedWorkouts = [...workouts].sort((a, b) => b.date - a.date);
    for (const workout of sortedWorkouts) {
      if (workout.exercises[exerciseName]) {
        foundSets = workout.exercises[exerciseName].map(set => ({
          targetReps: set.reps,
          targetWeight: set.weight,
          completed: false,
        }));
        break;
      }
    }
    
    exercises.push({
      name: exerciseName,
      sets: foundSets.length > 0 ? foundSets : [{ targetReps: 10, targetWeight: 0, completed: false }],
    });
  }
  
  return {
    focus,
    achilles,
    notes: `${focus} workout loaded from your history.`,
    exercises,
  };
}

// Determine what the recommended workout is based on rotation
function getRecommendedWorkout(): { primaryId: string; secondaryId?: string } {
  const rotation = calculateRotationStatus();
  
  // Find which primary muscle group has been longest
  const primaryTypes = rotation.primary.filter(t => ["Leg", "Push", "Pull"].includes(t.label));
  primaryTypes.sort((a, b) => b.daysSince - a.daysSince);
  
  const recommendedPrimary = primaryTypes[0]?.label.toLowerCase() ?? "push";
  
  // Determine Achilles intensity based on recency
  const achillesDays = rotation.primary.find(t => t.label === "Achilles")?.daysSince ?? 999;
  const achillesIntensity = achillesDays >= 2 ? "heavy" : "light";
  
  return {
    primaryId: recommendedPrimary,
    secondaryId: `achilles-${achillesIntensity}`,
  };
}

// Export computed values
export const rotationStatus = calculateRotationStatus();

const recommended = getRecommendedWorkout();
export const todayPlan: WorkoutPlan = buildTodayPlan(recommended.primaryId, recommended.secondaryId);

export const trainingPrinciples = [
  "Two primary body-part focuses per day, rotate evenly.",
  "Daily Achilles rehab alternating heavy/light; add core on light days if time allows.",
  "Coach should keep answers under 220 characters unless user asks for detail.",
  "Always confirm the current set, ask for reps/weight, then prescribe the next set.",
];

// Export raw data for debugging
export const rawUserData = userData;
