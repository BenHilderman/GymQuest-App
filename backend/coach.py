"""
coach.py - agentic AI coaching with tool use

upgraded from a single-shot prompt to a ReAct agent that can:
1. retrieve exercises from the FAISS knowledge base (RAG)
2. calculate training load metrics (ACWR, strain, volume)
3. check volume status against Israetel's volume landmarks

the agent reasons step by step: it checks your training load, searches
for relevant exercises, then gives grounded advice that references
actual exercises and your actual numbers.

still falls back to rule-based responses if no API key is set.

- ben
"""

import os
import json
from typing import Dict, Any, List, Optional
import logging
from dotenv import load_dotenv

load_dotenv()

# LangChain imports
try:
    from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
    from langchain_core.tools import tool
    from langchain_groq import ChatGroq
    from langchain.agents import create_react_agent, AgentExecutor
    from langchain_core.prompts import PromptTemplate
    LANGCHAIN_AVAILABLE = True
except ImportError:
    LANGCHAIN_AVAILABLE = False
    print("LangChain not installed. Run: pip install langchain langchain-groq")

logger = logging.getLogger(__name__)


AGENT_SYSTEM_PROMPT = """You are GymQuest AI Coach - an expert fitness advisor that uses tools to give grounded, data-driven advice.

USER: {name} | Goal: {goal} | Level: {level} | Days/Week: {days_per_week}
Injuries: {injuries}

You have access to these tools:
- retrieve_exercises: Search the exercise knowledge base for exercises matching a query
- calculate_training_load: Analyze workout history to get ACWR, strain, volume metrics
- check_volume_status: Check if a muscle group is under/optimal/over volume

RULES:
1. Always check training load before recommending workout changes
2. Search for exercises when recommending specific movements
3. Reference actual numbers from the tools (ACWR, strain, sets)
4. If ACWR > 1.5 or strain > 80, recommend deload
5. If the user has injuries, search for safe alternatives
6. Be specific: "3x10 at RPE 7" not "moderate intensity"
7. MAX 4 sentences unless asked for details
8. End with ONE clear action item

{agent_scratchpad}"""


# ReAct prompt template - this drives the agent's think/act/observe loop
REACT_PROMPT = """Answer the following questions as best you can. You have access to the following tools:

{tools}

Use the following format:

Question: the input question you must answer
Thought: you should always think about what to do
Action: the action to take, should be one of [{tool_names}]
Action Input: the input to the action
Observation: the result of the action
... (this Thought/Action/Action Input/Observation can repeat N times)
Thought: I now know the final answer
Final Answer: the final answer to the original question

CONTEXT:
User: {name} | Goal: {goal} | Level: {level} | Days/Week: {days_per_week}
Injuries: {injuries}

RULES:
1. Always check training load before recommending workout changes
2. Search for exercises when recommending specific movements
3. Reference actual numbers (ACWR, strain, sets)
4. If ACWR > 1.5 or strain > 80, recommend deload
5. If the user has injuries, avoid contraindicated movements
6. Be specific with prescriptions: "3x10 at RPE 7" not "moderate intensity"
7. MAX 4 sentences unless asked for details
8. End with ONE clear action item

Begin!

Question: {input}
Thought:{agent_scratchpad}"""


class EnhancedCoach:
    """
    agentic coach that reasons step by step using tools.

    the ReAct loop:
      1. THINK: what does the user need?
      2. ACT: call a tool (retrieve exercises, check load, etc.)
      3. OBSERVE: read the tool output
      4. repeat until confident, then give a final answer

    falls back to rule-based responses when no API key is available.
    """

    def __init__(self, rag_engine=None, training_calculator=None):
        self.rag_engine = rag_engine
        self.training_calculator = training_calculator
        self._tools = None
        self._agent_executor = None

    def _build_tools(self, workouts: List[Dict], load_metrics: Dict[str, Any]):
        """create LangChain tools that close over the current request context"""

        rag = self.rag_engine
        calc = self.training_calculator

        @tool
        def retrieve_exercises(query: str) -> str:
            """Search the exercise knowledge base for exercises matching a query. Use this to find exercises for a muscle group, movement pattern, or equipment type."""
            if rag is None:
                return "Exercise search unavailable"
            results = rag.search(query, top_k=5)
            if not results:
                return "No matching exercises found"
            lines = []
            for r in results:
                ex = r.get("exercise", {})
                name = r["source"]
                muscle = ex.get("muscleGroup", "unknown")
                equipment = ex.get("equipment", "unknown")
                secondary = ", ".join(ex.get("secondaryMuscles", []))
                cues = "; ".join(ex.get("cues", [])[:2])
                compound = "compound" if ex.get("isCompound") else "isolation"
                score = r["relevance_score"]
                lines.append(f"- {name} ({muscle}, {equipment}, {compound}, score={score:.2f}) secondary=[{secondary}] cues=[{cues}]")
            return "\n".join(lines)

        @tool
        def calculate_training_load(analysis_request: str) -> str:
            """Analyze the user's recent workout history to get training load metrics including ACWR, strain score, weekly volume by muscle, and session count. Pass any string to trigger the analysis."""
            return json.dumps({
                "acwr": load_metrics.get("acwr", 1.0),
                "strain_score": load_metrics.get("strain_score", 0),
                "sessions_this_week": load_metrics.get("sessions_this_week", 0),
                "avg_rpe": load_metrics.get("avg_rpe_this_week", 0),
                "weekly_volume": load_metrics.get("weekly_volume", {}),
                "monotony": load_metrics.get("monotony", 1.0),
                "acute_load": load_metrics.get("acute_load", 0),
                "chronic_load": load_metrics.get("chronic_load", 0),
            }, indent=2)

        @tool
        def check_volume_status(muscle_group: str) -> str:
            """Check if a specific muscle group is under/optimal/high/over volume based on Israetel's volume landmarks. Input should be a muscle group name like 'Chest', 'Back', 'Legs', etc."""
            volume_status = load_metrics.get("volume_status", {})
            weekly_volume = load_metrics.get("weekly_volume", {})

            # volume landmarks from training_load.py
            landmarks = {
                "Chest":     {"MV": 10, "MEV": 12, "MAV": 20, "MRV": 24},
                "Back":      {"MV": 10, "MEV": 14, "MAV": 22, "MRV": 26},
                "Shoulders": {"MV": 8,  "MEV": 10, "MAV": 18, "MRV": 22},
                "Biceps":    {"MV": 6,  "MEV": 8,  "MAV": 16, "MRV": 20},
                "Triceps":   {"MV": 6,  "MEV": 8,  "MAV": 16, "MRV": 20},
                "Legs":      {"MV": 8,  "MEV": 12, "MAV": 20, "MRV": 26},
                "Core":      {"MV": 4,  "MEV": 6,  "MAV": 12, "MRV": 16},
            }

            # try to match the muscle group (case-insensitive)
            matched = None
            for key in landmarks:
                if key.lower() == muscle_group.lower():
                    matched = key
                    break

            if matched is None:
                return f"Unknown muscle group: {muscle_group}. Known groups: {', '.join(landmarks.keys())}"

            current_sets = weekly_volume.get(matched, 0)
            status = volume_status.get(matched, "no data")
            lm = landmarks[matched]

            return json.dumps({
                "muscle_group": matched,
                "current_weekly_sets": current_sets,
                "status": status,
                "landmarks": {
                    "MV_maintenance": lm["MV"],
                    "MEV_minimum_effective": lm["MEV"],
                    "MAV_max_adaptive": lm["MAV"],
                    "MRV_max_recoverable": lm["MRV"],
                },
            }, indent=2)

        return [retrieve_exercises, calculate_training_load, check_volume_status]

    async def get_advice(
        self,
        prompt: str,
        profile: Dict[str, Any],
        workouts: List[Dict],
        load_metrics: Dict[str, Any],
        api_key: Optional[str] = None
    ) -> str:
        """
        main method - runs the ReAct agent to answer the user's question.
        the agent will use tools to look up exercises, check training load,
        and assess volume before giving its final answer.
        """
        if not LANGCHAIN_AVAILABLE:
            return self._fallback_response(prompt, profile, load_metrics)

        key = api_key or os.getenv("GROQ_API_KEY")
        if not key:
            return self._fallback_response(prompt, profile, load_metrics)

        try:
            # build tools that close over the current request data
            tools = self._build_tools(workouts, load_metrics)

            llm = ChatGroq(
                api_key=key,
                model="llama-3.3-70b-versatile",
                temperature=0.7,
                max_tokens=500,
            )

            # build the ReAct agent
            react_prompt = PromptTemplate.from_template(REACT_PROMPT)

            agent = create_react_agent(
                llm=llm,
                tools=tools,
                prompt=react_prompt,
            )

            executor = AgentExecutor(
                agent=agent,
                tools=tools,
                verbose=False,
                max_iterations=5,
                handle_parsing_errors=True,
            )

            result = await executor.ainvoke({
                "input": prompt,
                "name": profile.get("name", "Athlete"),
                "goal": profile.get("goal", "General Fitness"),
                "level": profile.get("level", 1),
                "days_per_week": profile.get("days_per_week", 4),
                "injuries": profile.get("injuries") or "None",
            })

            return result.get("output", self._fallback_response(prompt, profile, load_metrics))

        except Exception as e:
            logger.error(f"Agent error: {str(e)}")
            return self._fallback_response(prompt, profile, load_metrics)

    def _fallback_response(
        self,
        prompt: str,
        profile: Dict[str, Any],
        metrics: Dict[str, Any]
    ) -> str:
        """
        no API key? no problem. this gives decent advice using simple
        if-then rules. it's the same logic the iOS app uses in demo mode.
        """
        name = profile.get("name", "there")
        acwr = metrics.get("acwr", 1.0)
        strain = metrics.get("strain_score", 0)
        sessions = metrics.get("sessions_this_week", 0)
        prompt_lower = prompt.lower()

        # safety first - if they're overtraining, warn them
        if acwr > 1.5 or strain > 80:
            return f"Hold up {name}. ACWR at {acwr:.1f}, strain at {strain:.0f}%. " \
                   f"You need a deload - cut volume 40-50%, focus on recovery."

        if "warm" in prompt_lower:
            return "5 min cardio, dynamic stretches, 2 light sets at 50%. Done."

        if "rest" in prompt_lower or "push" in prompt_lower or "train" in prompt_lower:
            if strain > 60:
                return f"Strain at {strain:.0f}%. Train light (RPE 7 max) or take a rest day."
            return f"{sessions} sessions in. You're good to push it today."

        if "volume" in prompt_lower:
            volume = metrics.get("weekly_volume", {})
            high = [m for m, s in volume.items() if s > 18]
            low = [m for m, s in volume.items() if s < 8]
            if high:
                return f"Dial back {', '.join(high)} - volume is high. Drop 2-3 sets."
            if low:
                return f"Add more work for {', '.join(low)}. 2 sets per session."
            return "Volume balanced. Stay the course."

        if "deload" in prompt_lower:
            if acwr > 1.3:
                return f"ACWR is {acwr:.1f}. Time to deload - half the volume, same weights."
            return f"ACWR at {acwr:.1f}. No deload needed yet."

        return f"What's up {name}? {sessions} sessions this week, ACWR {acwr:.1f}. " \
               f"Ask about volume, deloads, or if you should train today."


if __name__ == "__main__":
    import asyncio

    async def test():
        coach = EnhancedCoach()
        response = await coach.get_advice(
            prompt="Should I train today?",
            profile={"name": "Marcus", "goal": "Hypertrophy", "level": 15, "days_per_week": 4},
            workouts=[],
            load_metrics={"acwr": 1.2, "strain_score": 55, "sessions_this_week": 3, "avg_rpe_this_week": 7}
        )
        print(response)

    asyncio.run(test())
