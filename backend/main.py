"""
main.py - FastAPI server for GymQuest

Backend that powers the AI coach. Three main components:
1. training load math (ACWR, strain) - see training_load.py
2. RAG engine (FAISS + sentence-transformers) - see rag_engine.py
3. agentic AI coaching with tool use - see coach.py

to run locally:
    pip install -r requirements.txt
    uvicorn main:app --reload --port 8000

- ben
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List
import logging
from dotenv import load_dotenv

# Load .env file at startup
load_dotenv()

from training_load import TrainingLoadCalculator
from rag_engine import RAGEngine
from coach import EnhancedCoach

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="GymQuest AI Backend",
    description="Training load analytics, exercise RAG, and agentic AI coaching",
    version="2.0.0"
)

# let the iOS app talk to us
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- services ---
training_calculator = TrainingLoadCalculator()
rag_engine = RAGEngine()
coach = EnhancedCoach(rag_engine=rag_engine, training_calculator=training_calculator)


# --- pydantic models for request/response validation ---

class WorkoutSession(BaseModel):
    date: str
    type: str
    duration: int
    rpe: int
    total_sets: int
    exercises: List[dict]


class UserProfile(BaseModel):
    name: str
    goal: str
    days_per_week: int
    level: int
    injuries: Optional[str] = ""


class CoachRequest(BaseModel):
    prompt: str
    profile: UserProfile
    workouts: List[WorkoutSession]
    api_key: Optional[str] = None


class CoachResponse(BaseModel):
    response: str
    training_load: dict
    suggestions: List[str]
    needs_deload: bool


class SearchRequest(BaseModel):
    query: str
    top_k: Optional[int] = 5


# --- endpoints ---

@app.get("/")
async def root():
    """quick health check"""
    return {
        "status": "healthy",
        "service": "GymQuest AI Backend",
        "version": "2.0.0",
        "rag_indexed": len(rag_engine.exercises),
    }


@app.post("/api/coach", response_model=CoachResponse)
async def get_coach_advice(request: CoachRequest):
    """main endpoint - runs the agentic coach with RAG + training load tools"""
    try:
        logger.info(f"Coach request from {request.profile.name}")

        # crunch the numbers first
        load_metrics = training_calculator.calculate_metrics(
            [w.model_dump() for w in request.workouts]
        )

        # rule-based suggestions (always included, even if AI fails)
        suggestions = training_calculator.get_suggestions(
            load_metrics,
            request.profile.goal,
            request.profile.days_per_week
        )

        needs_deload = load_metrics.get("acwr", 1.0) > 1.5 or load_metrics.get("strain_score", 0) > 80

        # run the agentic coach (ReAct loop with tool use)
        ai_response = await coach.get_advice(
            prompt=request.prompt,
            profile=request.profile.model_dump(),
            workouts=[w.model_dump() for w in request.workouts],
            load_metrics=load_metrics,
            api_key=request.api_key
        )

        return CoachResponse(
            response=ai_response,
            training_load=load_metrics,
            suggestions=suggestions,
            needs_deload=needs_deload
        )

    except Exception as e:
        logger.error(f"Coach error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/search")
async def search_exercises(request: SearchRequest):
    """semantic search over the exercise knowledge base via FAISS"""
    try:
        results = rag_engine.search(request.query, top_k=request.top_k)
        return {
            "query": request.query,
            "results": results,
            "count": len(results),
        }
    except Exception as e:
        logger.error(f"Search error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/training-load")
async def get_training_load(workouts: List[WorkoutSession]):
    """just the numbers - ACWR, strain, volume, etc. no AI advice."""
    try:
        metrics = training_calculator.calculate_metrics(
            [w.model_dump() for w in workouts]
        )
        return {
            "metrics": metrics,
            "interpretation": training_calculator.interpret_metrics(metrics)
        }
    except Exception as e:
        logger.error(f"Training load error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
