"""
coach.py - the AI brain behind workout advice

uses LangChain to talk to Groq's LLM (llama 3.3 70b). the cool part is
we inject all the user's training data into the prompt so the AI actually
knows what's going on - it's not just generic advice.

how it works:
1. build a prompt with user stats (ACWR, strain, volume, etc.)
2. send it to Groq via LangChain
3. if no API key, fall back to rule-based responses (still useful!)

the fallback mode isn't just a cop-out - it uses the same sports science
logic as the main AI, just without the natural language generation.

- ben
"""

import os
import json
from typing import Dict, Any, List, Optional
import logging
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# LangChain imports
try:
    from langchain_core.prompts import ChatPromptTemplate, SystemMessagePromptTemplate, HumanMessagePromptTemplate
    from langchain_core.output_parsers import StrOutputParser
    from langchain_groq import ChatGroq  # Using Groq (free & fast)
    LANGCHAIN_AVAILABLE = True
except ImportError:
    LANGCHAIN_AVAILABLE = False
    print("LangChain not installed. Run: pip install langchain langchain-groq")

logger = logging.getLogger(__name__)


# the prompt template - this is what the AI "sees" before answering
# variables in {braces} get filled in with real user data

SYSTEM_PROMPT = """You are GymQuest AI Coach - direct, actionable fitness advice.

USER: {name} | Goal: {goal} | Level: {level} | Days/Week: {days_per_week}
Injuries: {injuries}

TRAINING METRICS:
- ACWR: {acwr} (0.8-1.3 optimal, >1.5 = injury risk)
- Strain: {strain_score}/100
- Sessions this week: {sessions_this_week}
- Avg RPE: {avg_rpe}

VOLUME BY MUSCLE:
{weekly_volume}

RULES:
1. MAX 3 sentences unless asked for details
2. Reference their actual numbers
3. If ACWR > 1.5 or strain > 80, recommend deload
4. Be specific: "3x10 at RPE 7" not "moderate intensity"
5. End with ONE clear action
"""


class EnhancedCoach:
    """
    the main coach class. tries to use Groq's LLM for smart responses,
    but if there's no API key it'll still give decent advice using
    if-then rules based on the user's numbers.
    """

    def __init__(self):
        if LANGCHAIN_AVAILABLE:
            # Build the prompt template
            self.system_template = SystemMessagePromptTemplate.from_template(SYSTEM_PROMPT)
            self.human_template = HumanMessagePromptTemplate.from_template("{question}")
            self.chat_prompt = ChatPromptTemplate.from_messages([
                self.system_template,
                self.human_template
            ])
            self.output_parser = StrOutputParser()

    async def get_advice(
        self,
        prompt: str,
        profile: Dict[str, Any],
        workouts: List[Dict],
        load_metrics: Dict[str, Any],
        api_key: Optional[str] = None
    ) -> str:
        """
        main method - takes a user question and returns coaching advice.
        tries Groq first, falls back to rule-based if no API key.
        """
        if not LANGCHAIN_AVAILABLE:
            return self._fallback_response(prompt, profile, load_metrics)

        # Use Groq API key (free tier available at console.groq.com)
        key = api_key or os.getenv("GROQ_API_KEY")
        if not key:
            return self._fallback_response(prompt, profile, load_metrics)

        try:
            volume_text = self._format_volume(load_metrics.get("weekly_volume", {}))

            # stuff all the user's data into a dict for the prompt template
            chain_input = {
                "name": profile.get("name", "Athlete"),
                "goal": profile.get("goal", "General Fitness"),
                "level": profile.get("level", 1),
                "days_per_week": profile.get("days_per_week", 4),
                "injuries": profile.get("injuries") or "None",
                "acwr": load_metrics.get("acwr", 1.0),
                "strain_score": load_metrics.get("strain_score", 0),
                "sessions_this_week": load_metrics.get("sessions_this_week", 0),
                "avg_rpe": load_metrics.get("avg_rpe_this_week", 0),
                "weekly_volume": volume_text,
                "question": prompt
            }

            # groq gives us free access to llama 3.3 70b - pretty wild
            # the "chain" is LangChain's way of piping: prompt -> llm -> parse output
            llm = ChatGroq(
                api_key=key,
                model="llama-3.3-70b-versatile",
                temperature=0.7,  # some creativity, not too random
                max_tokens=300    # keep responses concise
            )

            chain = self.chat_prompt | llm | self.output_parser
            response = await chain.ainvoke(chain_input)  # async so we don't block

            return response

        except Exception as e:
            logger.error(f"LangChain/Groq error: {str(e)}")
            return self._fallback_response(prompt, profile, load_metrics)

    def _format_volume(self, volume: Dict[str, int]) -> str:
        """turn the volume dict into something readable for the prompt"""
        if not volume:
            return "No data yet"

        lines = []
        for muscle, sets in sorted(volume.items()):
            status = "LOW" if sets < 8 else "HIGH" if sets > 18 else "GOOD"
            lines.append(f"- {muscle}: {sets} sets ({status})")
        return "\n".join(lines)

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

        # check what they're asking about and respond accordingly
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

        # didn't match anything specific, give a general status
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
