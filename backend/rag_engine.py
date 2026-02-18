"""
rag_engine.py - semantic exercise search via FAISS + Sentence Transformers

loads exercises.json, embeds each exercise into a 384-dim vector using
all-MiniLM-L6-v2, then indexes them with FAISS for cosine similarity search.

usage:
    engine = RAGEngine()
    results = engine.search("chest compound push exercises", top_k=5)
    # -> [{content: str, source: str, relevance_score: float}, ...]

the index lives in memory - no disk persistence needed since the exercise
database is small (~72 exercises) and embedding takes < 2 seconds.
"""

import json
import os
import logging
import numpy as np
from typing import List, Dict, Any, Optional
from pathlib import Path

logger = logging.getLogger(__name__)

# optional imports - graceful degradation if not installed
try:
    from sentence_transformers import SentenceTransformer
    SENTENCE_TRANSFORMERS_AVAILABLE = True
except ImportError:
    SENTENCE_TRANSFORMERS_AVAILABLE = False

try:
    import faiss
    FAISS_AVAILABLE = True
except ImportError:
    FAISS_AVAILABLE = False


class RAGEngine:
    """
    retrieval-augmented generation engine for exercise knowledge.

    embeds exercise descriptions with sentence-transformers, indexes them
    with FAISS (IndexFlatIP on L2-normalized vectors = cosine similarity),
    and returns ranked results for natural language queries.
    """

    MODEL_NAME = "sentence-transformers/all-MiniLM-L6-v2"
    EMBEDDING_DIM = 384

    def __init__(self, data_path: Optional[str] = None):
        self.exercises: List[Dict[str, Any]] = []
        self.documents: List[str] = []
        self.index = None
        self.model = None

        # find exercises.json
        if data_path is None:
            data_path = os.path.join(os.path.dirname(__file__), "data", "exercises.json")

        self._load_exercises(data_path)
        self._build_index()

    def _load_exercises(self, path: str) -> None:
        """load exercises from JSON and build text documents for embedding"""
        try:
            with open(path, "r") as f:
                data = json.load(f)

            raw_exercises = data.get("exercises", data) if isinstance(data, dict) else data
            self.exercises = raw_exercises
            self.documents = [self._exercise_to_document(ex) for ex in raw_exercises]
            logger.info(f"Loaded {len(self.exercises)} exercises from {path}")
        except Exception as e:
            logger.error(f"Failed to load exercises: {e}")
            self.exercises = []
            self.documents = []

    def _exercise_to_document(self, exercise: Dict[str, Any]) -> str:
        """concatenate exercise fields into a searchable text document"""
        parts = [
            exercise.get("name", ""),
            f"muscle group: {exercise.get('muscleGroup', '')}",
        ]

        secondary = exercise.get("secondaryMuscles", [])
        if secondary:
            parts.append(f"secondary muscles: {', '.join(secondary)}")

        equipment = exercise.get("equipment", "")
        if equipment:
            parts.append(f"equipment: {equipment}")

        pattern = exercise.get("movementPattern", "")
        if pattern:
            parts.append(f"movement: {pattern}")

        if exercise.get("isCompound"):
            parts.append("compound exercise")
        else:
            parts.append("isolation exercise")

        cues = exercise.get("cues", [])
        if cues:
            parts.append(f"cues: {'; '.join(cues)}")

        return " | ".join(parts)

    def _build_index(self) -> None:
        """embed all documents and build the FAISS index"""
        if not self.documents:
            logger.warning("No documents to index")
            return

        if not SENTENCE_TRANSFORMERS_AVAILABLE:
            logger.warning("sentence-transformers not installed, RAG search disabled")
            return

        if not FAISS_AVAILABLE:
            logger.warning("faiss-cpu not installed, RAG search disabled")
            return

        try:
            logger.info(f"Loading embedding model: {self.MODEL_NAME}")
            self.model = SentenceTransformer(self.MODEL_NAME)

            # embed all exercise documents
            embeddings = self.model.encode(self.documents, show_progress_bar=False)
            embeddings = np.array(embeddings, dtype=np.float32)

            # L2 normalize so inner product = cosine similarity
            faiss.normalize_L2(embeddings)

            # IndexFlatIP = exact inner product search (fast enough for ~72 exercises)
            self.index = faiss.IndexFlatIP(self.EMBEDDING_DIM)
            self.index.add(embeddings)

            logger.info(f"FAISS index built: {self.index.ntotal} vectors, {self.EMBEDDING_DIM}d")
        except Exception as e:
            logger.error(f"Failed to build FAISS index: {e}")
            self.index = None

    def search(self, query: str, top_k: int = 5) -> List[Dict[str, Any]]:
        """
        semantic search over the exercise knowledge base.

        returns a list of dicts with:
          - content: the exercise document text
          - source: exercise name
          - relevance_score: cosine similarity (0-1)
          - exercise: the full exercise dict from exercises.json
        """
        if self.index is None or self.model is None:
            return self._fallback_search(query, top_k)

        try:
            # embed the query
            query_embedding = self.model.encode([query])
            query_embedding = np.array(query_embedding, dtype=np.float32)
            faiss.normalize_L2(query_embedding)

            # search
            k = min(top_k, self.index.ntotal)
            scores, indices = self.index.search(query_embedding, k)

            results = []
            for score, idx in zip(scores[0], indices[0]):
                if idx < 0 or idx >= len(self.exercises):
                    continue
                exercise = self.exercises[idx]
                results.append({
                    "content": self.documents[idx],
                    "source": exercise.get("name", "Unknown"),
                    "relevance_score": round(float(score), 4),
                    "exercise": exercise,
                })

            return results

        except Exception as e:
            logger.error(f"FAISS search failed: {e}")
            return self._fallback_search(query, top_k)

    def _fallback_search(self, query: str, top_k: int) -> List[Dict[str, Any]]:
        """keyword-based fallback when FAISS/sentence-transformers aren't available"""
        query_lower = query.lower()
        scored = []

        for i, exercise in enumerate(self.exercises):
            doc = self.documents[i].lower() if i < len(self.documents) else ""
            # simple keyword overlap scoring
            query_words = set(query_lower.split())
            doc_words = set(doc.split())
            overlap = len(query_words & doc_words)
            if overlap > 0:
                score = overlap / max(len(query_words), 1)
                scored.append((score, i))

        scored.sort(key=lambda x: x[0], reverse=True)

        results = []
        for score, idx in scored[:top_k]:
            exercise = self.exercises[idx]
            results.append({
                "content": self.documents[idx],
                "source": exercise.get("name", "Unknown"),
                "relevance_score": round(score, 4),
                "exercise": exercise,
            })

        return results


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    engine = RAGEngine()
    print(f"\nIndexed {len(engine.exercises)} exercises\n")

    queries = ["chest compound push", "back exercises for lats", "leg isolation machine"]
    for q in queries:
        print(f"Query: '{q}'")
        results = engine.search(q, top_k=3)
        for r in results:
            print(f"  {r['relevance_score']:.3f}  {r['source']}")
        print()
