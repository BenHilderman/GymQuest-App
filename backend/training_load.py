"""
training_load.py - calculates how hard you've been training

the main thing here is ACWR (acute:chronic workload ratio). it compares
your last week of training to your last month. if you're doing way more
than usual, injury risk goes up. sports science stuff.

acwr cheat sheet:
  < 0.8  = undertrained, not doing enough
  0.8-1.3 = sweet spot
  1.3-1.5 = caution zone
  > 1.5  = back off, you're asking for an injury

- ben
"""

import numpy as np
import pandas as pd
from datetime import datetime, timedelta
from typing import List, Dict, Any


class TrainingLoadCalculator:
    """
    crunches the numbers on training load. uses a few key metrics:

    - sRPE (session RPE) = how hard × how long. a 60min workout at RPE 8 = 480 load
    - ACWR = this week's load / average weekly load. tells you if you're overdoing it
    - strain = accumulated fatigue. recent workouts count more (exponential weighting)
    - monotony = are you doing the same thing every day? that's bad for gains and joints
    """

    def __init__(self):
        self.ACUTE_WINDOW = 7      # "acute" = last 7 days
        self.CHRONIC_WINDOW = 28   # "chronic" = last 28 days (4 weeks)

        # how long each muscle group needs to recover (hours)
        # legs take forever, bis/tris bounce back quick
        self.RECOVERY_TIMES = {
            "Chest": 48, "Back": 48, "Shoulders": 36,
            "Biceps": 24, "Triceps": 24, "Legs": 72,
            "Core": 24, "Glutes": 48,
        }

        # volume landmarks from dr. mike israetel's research
        # MV = maintenance, MEV = minimum to grow, MAV = max adaptive, MRV = can't recover past this
        self.VOLUME_LANDMARKS = {
            "Chest":     {"MV": 10, "MEV": 12, "MAV": 20, "MRV": 24},
            "Back":      {"MV": 10, "MEV": 14, "MAV": 22, "MRV": 26},
            "Shoulders": {"MV": 8,  "MEV": 10, "MAV": 18, "MRV": 22},
            "Biceps":    {"MV": 6,  "MEV": 8,  "MAV": 16, "MRV": 20},
            "Triceps":   {"MV": 6,  "MEV": 8,  "MAV": 16, "MRV": 20},
            "Legs":      {"MV": 8,  "MEV": 12, "MAV": 20, "MRV": 26},
            "Core":      {"MV": 4,  "MEV": 6,  "MAV": 12, "MRV": 16},
        }

    def calculate_metrics(self, workouts: List[Dict]) -> Dict[str, Any]:
        """
        main function - takes workout history, spits out all the metrics.
        returns acwr, strain, volume by muscle, etc.
        """
        if not workouts:
            return self._empty_metrics()

        # pandas makes time-series stuff easy
        df = self._workouts_to_dataframe(workouts)

        # session load = RPE × duration (standard formula)
        df['load'] = df['rpe'] * df['duration']

        # split into acute (this week) and chronic (this month)
        today = datetime.now().date()
        acute_start = today - timedelta(days=self.ACUTE_WINDOW)
        chronic_start = today - timedelta(days=self.CHRONIC_WINDOW)

        acute_df = df[df['date'] >= acute_start]
        chronic_df = df[df['date'] >= chronic_start]

        acute_load = acute_df['load'].sum()
        chronic_load = chronic_df['load'].sum() / 4  # weekly average

        # the magic ratio
        acwr = acute_load / max(chronic_load, 1)  # avoid divide by zero

        # other metrics
        strain_score = self._calculate_strain(df)
        monotony = self._calculate_monotony(df)
        weekly_volume = self._calculate_weekly_volume(workouts)
        volume_status = self._assess_volume_status(weekly_volume)

        # numpy types don't serialize to JSON, so cast everything
        return {
            "acwr": float(round(acwr, 2)),
            "acute_load": float(round(acute_load, 1)),
            "chronic_load": float(round(chronic_load, 1)),
            "strain_score": float(round(strain_score, 1)),
            "monotony": float(round(monotony, 2)),
            "weekly_volume": {k: int(v) for k, v in weekly_volume.items()},
            "volume_status": volume_status,
            "sessions_this_week": int(len(acute_df)),
            "avg_rpe_this_week": float(round(acute_df['rpe'].mean(), 1)) if len(acute_df) > 0 else 0.0
        }

    def _workouts_to_dataframe(self, workouts: List[Dict]) -> pd.DataFrame:
        """convert workout dicts to a dataframe for easier manipulation"""
        records = []
        for w in workouts:
            if isinstance(w.get('date'), str):
                try:
                    date = datetime.fromisoformat(w['date'].replace('Z', '+00:00')).date()
                except:
                    date = datetime.now().date()
            else:
                date = datetime.now().date()

            records.append({
                'date': date,
                'type': w.get('type', 'Unknown'),
                'duration': w.get('duration', 0),
                'rpe': w.get('rpe', 5),
                'total_sets': w.get('total_sets', 0),
                'exercises': w.get('exercises', [])
            })

        return pd.DataFrame(records)

    def _calculate_strain(self, df: pd.DataFrame) -> float:
        """
        strain uses EWMA (exponentially weighted moving average).

        basically: recent workouts affect your fatigue more than old ones.
        yesterday's brutal leg day hits different than last week's.

        the math: EWMA_t = alpha * value + (1-alpha) * EWMA_previous
        pandas handles this with .ewm(span=7) - span controls the decay rate
        """
        if len(df) == 0:
            return 0

        df_sorted = df.sort_values('date')
        ewma_load = df_sorted['load'].ewm(span=7, adjust=False).mean()
        current_strain = ewma_load.iloc[-1] if len(ewma_load) > 0 else 0

        # normalize to 0-100
        strain_score = min(100, (current_strain / 50) * 100)
        return strain_score

    def _calculate_monotony(self, df: pd.DataFrame) -> float:
        """
        monotony = mean daily load / std deviation

        high monotony (>2.0) means you're doing the same thing every day.
        that's actually bad - same stimulus = diminishing returns, plus
        repetitive strain injuries. you want some hard days and easy days.
        """
        if len(df) < 3:
            return 1.0

        daily_load = df.groupby('date')['load'].sum()
        if len(daily_load) < 2:
            return 1.0

        mean_load = daily_load.mean()
        std_load = daily_load.std()

        if std_load == 0:
            return 2.0  # no variation = max monotony

        return mean_load / std_load

    def _calculate_weekly_volume(self, workouts: List[Dict]) -> Dict[str, int]:
        """count sets per muscle group for this week"""
        volume = {}
        today = datetime.now().date()
        week_start = today - timedelta(days=today.weekday())

        for workout in workouts:
            if isinstance(workout.get('date'), str):
                try:
                    date = datetime.fromisoformat(workout['date'].replace('Z', '+00:00')).date()
                except:
                    continue
            else:
                continue

            if date < week_start:
                continue

            for exercise in workout.get('exercises', []):
                muscle = exercise.get('muscle', 'Unknown')
                sets = exercise.get('sets', 0)
                volume[muscle] = volume.get(muscle, 0) + sets

        return volume

    def _assess_volume_status(self, weekly_volume: Dict[str, int]) -> Dict[str, str]:
        """check if each muscle is getting enough/too much volume"""
        status = {}
        for muscle, sets in weekly_volume.items():
            landmarks = self.VOLUME_LANDMARKS.get(muscle, {"MV": 8, "MEV": 10, "MAV": 18, "MRV": 22})

            if sets < landmarks["MEV"]:
                status[muscle] = "under"
            elif sets <= landmarks["MAV"]:
                status[muscle] = "optimal"
            elif sets <= landmarks["MRV"]:
                status[muscle] = "high"
            else:
                status[muscle] = "over"

        return status

    def _empty_metrics(self) -> Dict[str, Any]:
        """default values when there's no data"""
        return {
            "acwr": 0, "acute_load": 0, "chronic_load": 0,
            "strain_score": 0, "monotony": 0, "weekly_volume": {},
            "volume_status": {}, "sessions_this_week": 0, "avg_rpe_this_week": 0
        }

    def get_suggestions(self, metrics: Dict[str, Any], goal: str, target_days: int) -> List[str]:
        """
        generate recommendations based on the numbers.

        these are heuristics (if-then rules), not ML. for training advice,
        rules work better because the science is well-established and
        edge cases could hurt someone.
        """
        suggestions = []
        acwr = metrics.get("acwr", 1.0)
        strain = metrics.get("strain_score", 0)
        monotony = metrics.get("monotony", 1.0)
        sessions = metrics.get("sessions_this_week", 0)
        avg_rpe = metrics.get("avg_rpe_this_week", 5)
        volume_status = metrics.get("volume_status", {})

        # acwr warnings
        if acwr > 1.5:
            suggestions.append(f"ACWR is {acwr:.1f} (danger zone). Take a deload week: reduce volume by 40-50%.")
        elif acwr > 1.3:
            suggestions.append(f"ACWR is {acwr:.1f} (caution). Consider reducing intensity - drop RPE by 1-2 points.")
        elif acwr < 0.8 and metrics.get("chronic_load", 0) > 0:
            suggestions.append(f"ACWR is {acwr:.1f} (undertrained). You can push harder this week - add 1-2 sets per muscle.")

        # fatigue check
        if strain > 80:
            suggestions.append(f"Strain score is high ({strain:.0f}/100). Prioritize sleep and consider an extra rest day.")

        # variety check
        if monotony > 2.0:
            suggestions.append(f"Training monotony is high ({monotony:.1f}). Add variety: different exercises, rep ranges, or intensities.")

        # volume imbalances
        under_volume = [m for m, s in volume_status.items() if s == "under"]
        over_volume = [m for m, s in volume_status.items() if s == "over"]

        if under_volume:
            suggestions.append(f"Low volume on: {', '.join(under_volume)}. Add 2-3 sets per session for these muscles.")
        if over_volume:
            suggestions.append(f"High volume on: {', '.join(over_volume)}. Reduce by 20-30% to allow recovery.")

        # frequency
        if sessions < target_days - 1:
            suggestions.append(f"Only {sessions} sessions this week (target: {target_days}). Try to fit in another workout.")

        # rpe check
        if avg_rpe > 8.5:
            suggestions.append(f"Average RPE is {avg_rpe:.1f}. Leave 1-2 reps in reserve - training to failure increases fatigue.")
        elif avg_rpe < 6 and goal == "Hypertrophy":
            suggestions.append(f"Average RPE is {avg_rpe:.1f}. For hypertrophy, aim for RPE 7-8 to ensure sufficient stimulus.")

        return suggestions if suggestions else ["Training load looks good. Keep it up!"]

    def interpret_metrics(self, metrics: Dict[str, Any]) -> Dict[str, str]:
        """human-readable summary of the metrics"""
        acwr = metrics.get("acwr", 1.0)
        strain = metrics.get("strain_score", 0)

        if acwr > 1.5:
            acwr_status = "High risk - deload recommended"
        elif acwr > 1.3:
            acwr_status = "Elevated - reduce intensity"
        elif acwr >= 0.8:
            acwr_status = "Optimal training zone"
        else:
            acwr_status = "Undertrained - can increase load"

        if strain > 80:
            strain_status = "High fatigue - prioritize recovery"
        elif strain > 60:
            strain_status = "Moderate fatigue - normal training"
        elif strain > 30:
            strain_status = "Low fatigue - can push harder"
        else:
            strain_status = "Fresh - ready for intense work"

        return {
            "acwr": acwr_status,
            "strain": strain_status,
            "recommendation": self._get_overall_recommendation(metrics)
        }

    def _get_overall_recommendation(self, metrics: Dict[str, Any]) -> str:
        acwr = metrics.get("acwr", 1.0)
        strain = metrics.get("strain_score", 0)

        if acwr > 1.5 or strain > 80:
            return "DELOAD: Take it easy this week. Light technique work only."
        elif acwr > 1.3 or strain > 60:
            return "MAINTAIN: Keep current volume but reduce intensity by 10-15%."
        elif acwr < 0.8:
            return "PROGRESS: Good time to increase volume or intensity."
        else:
            return "STEADY: Continue current program. You're in the optimal zone."
