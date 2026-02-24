#!/usr/bin/env python3
"""
One-time script to fuzzy-match Lift AI exercise names to ExerciseDB IDs.
NOT shipped with the app — used to generate exercisedb_mapping.json.

Usage:
    python3 build_exercisedb_mapping.py

Requirements:
    pip install requests rapidfuzz

The script:
1. Fetches all exercises from ExerciseDB public API
2. Fuzzy-matches each app exercise name to find the best ExerciseDB match
3. Outputs candidate mappings for manual verification
4. Writes final exercisedb_mapping.json
"""

import json
import os
import sys

try:
    import requests
    from rapidfuzz import fuzz, process
except ImportError:
    print("Install dependencies: pip install requests rapidfuzz")
    sys.exit(1)

# All 160 exercises from ExtendedExerciseDatabase
APP_EXERCISES = [
    # Chest
    "Bench Press", "Incline Bench Press", "Dumbbell Press", "Push-ups",
    "Cable Fly", "Decline Bench Press", "Dumbbell Fly", "Chest Dips",
    "Incline Dumbbell Press", "Machine Chest Press", "Landmine Press", "Svend Press",
    # Back
    "Deadlift", "Barbell Row", "Pull-ups", "Lat Pulldown",
    "Seated Cable Row", "T-Bar Row", "Face Pulls", "Dumbbell Row",
    "Chest-Supported Row", "Rack Pull", "Meadows Row", "Straight Arm Pulldown",
    # Shoulders
    "Overhead Press", "Lateral Raises", "Arnold Press", "Front Raises",
    "Rear Delt Fly", "Upright Row", "Cable Lateral Raise", "Shoulder Landmine Press",
    "Rear Delt Face Pulls", "Seated Dumbbell Press",
    # Biceps
    "Bicep Curls", "Barbell Curl", "Hammer Curls", "Preacher Curls",
    "Concentration Curls", "Incline Dumbbell Curls", "Cable Curls", "Spider Curls",
    # Triceps
    "Tricep Pushdown", "Skull Crushers", "Overhead Tricep Extension",
    "Close-Grip Bench Press", "Tricep Dips", "Kickbacks", "Diamond Push-ups", "JM Press",
    # Quads
    "Squat", "Leg Press", "Front Squat", "Goblet Squat",
    "Leg Extension", "Hack Squat", "Bulgarian Split Squat", "Sissy Squat",
    "Walking Lunges", "Step-Ups",
    # Hamstrings
    "Romanian Deadlift", "Lying Leg Curl", "Seated Leg Curl", "Nordic Curls",
    "Good Mornings", "Glute-Ham Raise", "Single-Leg RDL", "Stiff-Leg Deadlift",
    # Glutes
    "Hip Thrust", "Glute Bridge", "Cable Kickback", "Glute-Focused BSS",
    "Sumo Deadlift", "Frog Pumps", "Hip Abduction Machine", "Curtsy Lunge",
    # Calves
    "Standing Calf Raise", "Seated Calf Raise", "Donkey Calf Raise",
    "Leg Press Calf Raise", "Single-Leg Calf Raise",
    # Core
    "Plank", "Leg Raises", "Hanging Leg Raise", "Cable Crunch",
    "Ab Wheel Rollout", "Russian Twist", "Pallof Press", "Dead Bug",
    "Bicycle Crunches", "Woodchoppers", "Dragon Flag", "L-Sit",
    # Cardio
    "Treadmill Run", "Outdoor Run", "Cycling", "Indoor Cycling",
    "Rowing Machine", "Swimming", "Hiking", "Jump Rope",
    "Stair Climber", "Elliptical", "Walking", "Sprints", "Battle Ropes",
    # HIIT
    "Assault Bike", "Sled Push",
    # Full Body
    "Burpees", "Box Jumps", "Kettlebell Swings", "Thrusters",
    "Wall Balls", "Clean and Jerk", "Power Clean", "Snatch",
    "Man Makers", "Turkish Get-Up", "Farmer's Walk",
    # Calisthenics
    "Muscle-ups", "Handstand Push-ups", "Pistol Squats", "L-Sit",
    "Human Flag", "Front Lever", "Back Lever", "Planche",
    "Ring Dips", "Toes to Bar",
    # Flexibility
    "Sun Salutation", "Warrior I", "Warrior II", "Downward Dog",
    "Foam Rolling", "Pigeon Pose", "Cat-Cow Stretch", "Hip Opener Flow",
    "Shoulder Mobility", "Thoracic Spine Mobility", "Hamstring Stretch", "Quad Stretch",
    # Martial Arts
    "Heavy Bag Work", "Shadow Boxing", "Kick Combos", "Grappling Drills",
    "Speed Bag", "Mitt Work", "Clinch Work", "Ground and Pound",
    # Sport/Agility
    "Agility Ladder", "Cone Drills", "Sprint Drills", "Vertical Jump Training",
    "Lateral Shuffles", "Reaction Drills", "Tire Flips", "Prowler Push",
]

EXERCISEDB_API = "https://exercisedb.p.rapidapi.com/exercises"
HEADERS = {
    "X-RapidAPI-Key": os.environ.get("RAPIDAPI_KEY", "YOUR_KEY_HERE"),
    "X-RapidAPI-Host": "exercisedb.p.rapidapi.com",
}

MATCH_THRESHOLD = 60  # Minimum fuzzy match score to consider


def fetch_exercisedb_exercises():
    """Fetch all exercises from ExerciseDB API."""
    print("Fetching exercises from ExerciseDB...")
    params = {"limit": 1500, "offset": 0}
    resp = requests.get(EXERCISEDB_API, headers=HEADERS, params=params, timeout=30)
    resp.raise_for_status()
    return resp.json()


def build_mapping(db_exercises):
    """Fuzzy-match app exercises to ExerciseDB exercises."""
    # Build lookup: exercise name -> id
    db_lookup = {ex["name"].lower(): ex["id"] for ex in db_exercises}
    db_names = list(db_lookup.keys())

    mappings = {}
    unmatched = []

    for app_name in APP_EXERCISES:
        # Try exact match first
        lower = app_name.lower()
        if lower in db_lookup:
            mappings[app_name] = db_lookup[lower]
            continue

        # Fuzzy match
        result = process.extractOne(
            lower,
            db_names,
            scorer=fuzz.token_sort_ratio,
            score_cutoff=MATCH_THRESHOLD,
        )

        if result:
            matched_name, score, _ = result
            db_id = db_lookup[matched_name]
            mappings[app_name] = {
                "id": db_id,
                "matched_to": matched_name,
                "score": score,
                "needs_review": score < 85,
            }
        else:
            unmatched.append(app_name)

    return mappings, unmatched


def main():
    try:
        db_exercises = fetch_exercisedb_exercises()
    except Exception as e:
        print(f"API fetch failed: {e}")
        print("Using offline mode — manually verify exercisedb_mapping.json")
        return

    print(f"Fetched {len(db_exercises)} exercises from ExerciseDB")

    mappings, unmatched = build_mapping(db_exercises)

    # Print results for review
    print(f"\n{'='*60}")
    print(f"MATCHED: {len(mappings)} exercises")
    print(f"UNMATCHED: {len(unmatched)} exercises")
    print(f"{'='*60}\n")

    # Show matches that need review
    needs_review = {k: v for k, v in mappings.items() if isinstance(v, dict) and v.get("needs_review")}
    if needs_review:
        print("NEEDS REVIEW (low confidence matches):")
        for name, info in sorted(needs_review.items()):
            print(f"  {name:30s} -> {info['matched_to']:40s} (score: {info['score']})")
        print()

    # Show unmatched
    if unmatched:
        print("UNMATCHED (no ExerciseDB equivalent):")
        for name in unmatched:
            print(f"  {name}")
        print()

    # Write clean mapping file
    clean_mappings = {}
    for name, value in mappings.items():
        if isinstance(value, dict):
            clean_mappings[name] = value["id"]
        else:
            clean_mappings[name] = value

    output = {
        "mappings": clean_mappings,
        "gif_url_pattern": "https://v2.exercisedb.io/image/{id}",
    }

    output_path = os.path.join(
        os.path.dirname(os.path.dirname(__file__)),
        "GymQuest", "Resources", "exercisedb_mapping.json",
    )
    with open(output_path, "w") as f:
        json.dump(output, f, indent=2)
    print(f"Written to {output_path}")


if __name__ == "__main__":
    main()
