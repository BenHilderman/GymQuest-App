# GymQuest AI Backend

Python backend for agentic AI coaching using **FastAPI**, **LangChain ReAct agents**, **FAISS**, and training-load analytics.

## Architecture

```
backend/
├── main.py              FastAPI server (3 endpoints)
├── coach.py             ReAct agent with 3 tools
├── rag_engine.py        FAISS + Sentence Transformers RAG
├── training_load.py     ACWR, strain, volume analytics
├── data/
│   └── exercises.json   72-exercise knowledge base
├── eval/
│   ├── cases.json       25 test cases (~120 sessions)
│   └── run_eval.py      Evaluation runner
└── requirements.txt
```

## What It Does

### AI Coach (`coach.py`)
LangChain **ReAct agent** that reasons step by step using three tools:

1. **`retrieve_exercises`** — Semantic search over the exercise knowledge base via FAISS
2. **`calculate_training_load`** — ACWR, strain, volume metrics from workout history
3. **`check_volume_status`** — Israetel volume landmarks (MV/MEV/MAV/MRV) per muscle

The agent thinks, acts, observes, and repeats until it has enough context to give grounded advice. Falls back to rule-based heuristics when no API key is configured.

### RAG Engine (`rag_engine.py`)
Embeds 72 exercises with **Sentence Transformers** (`all-MiniLM-L6-v2`, 384-dim) and indexes them with **FAISS** (`IndexFlatIP` on L2-normalized vectors = cosine similarity). Supports natural language queries like "chest compound push exercises" and returns ranked results with relevance scores.

### Training Load (`training_load.py`)
Sports science analytics: **ACWR** (acute:chronic workload ratio), per-muscle volume tracking, fatigue/strain scoring via EWMA, monotony detection, and rule-based deload/recovery suggestions.

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/` | Health check |
| `POST` | `/api/coach` | Agentic coaching (ReAct + RAG + training load) |
| `POST` | `/api/search` | Semantic exercise search via FAISS |
| `POST` | `/api/training-load` | Training load metrics only |

## Quick Start

```bash
python3 -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt

# Optional - enables LLM responses (free tier at console.groq.com)
export GROQ_API_KEY="your-key-here"

uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

## Evaluation

```bash
# Dry run - tests RAG retrieval + training load metrics (no LLM needed)
python eval/run_eval.py --dry-run

# Full run - includes LLM agent responses (requires GROQ_API_KEY)
python eval/run_eval.py --full

# Verbose output
python eval/run_eval.py --dry-run -v
```

25 cases across 6 categories: deload detection, injury safety, volume balancing, exercise selection, beginner guidance, and recovery advice.
