Python backend for advanced AI coaching using **FastAPI**, **LangChain**, **FAISS**, and training-load analytics.

## What it does
- **AI Coach (`coach.py`)**: LangChain-based coaching that uses user profile + recent workouts + retrieved knowledge; includes **heuristic fallback** when no API key is provided.
- **RAG (`rag_engine.py`)**: Semantic search over an exercise knowledge base using **FAISS** + **Sentence Transformers** (`all-MiniLM-L6-v2`).
- **Training Load (`training_load.py`)**: **ACWR**, per-muscle volume tracking, fatigue/strain scoring, and rule-based deload / recovery suggestions.

## Quick Start
```bash
python3 -m venv venv
source venv/bin/activate  # Windows: venv\\Scripts\\activate
pip install -r requirements.txt

# Optional
export OPENAI_API_KEY="your-key-here"

uvicorn main:app --reload --host 0.0.0.0 --port 8000
