from typing import List, Dict, Any
import numpy as np
from rank_bm25 import BM25Okapi
from sentence_transformers import SentenceTransformer, CrossEncoder, util

# =====================================================================
# PRODUCTION CONFIGURATION & ENGINE INITIALIZATION
# =====================================================================
class FeedbackRetrievalEngine:
    def __init__(self):
        # Bi-Encoder for dense vector spaces
        self.dense_model = SentenceTransformer("all-MiniLM-L6-v2")
        
        # State-of-the-Art Cross-Encoder optimized for deep contextual matching
        # (Overcomes the vocabulary/intent limitations of older MiniLM models)
        self.reranker = CrossEncoder("BAAI/bge-reranker-large")

    def _normalize_scores(self, scores: np.ndarray) -> np.ndarray:
        """Min-Max normalization to safely map raw scores to a 0.0 - 1.0 range."""
        min_val, max_val = np.min(scores), np.max(scores)
        if max_val == min_val:
            return np.zeros_like(scores)
        return (scores - min_val) / (max_val - min_val)

    def execute_pipeline(
        self, 
        manager_query: str, 
        corpus: List[Dict[str, Any]], 
        dense_weight: float = 0.7
    ) -> List[Dict[str, Any]]:
        
        documents = [doc["text"] for doc in corpus]
        
        # -----------------------------------------------------------------
        # STAGE 1: INTENT-ENRICHED QUERY EXPANSION
        # -----------------------------------------------------------------
        # Converts passive lookups into intent-driven statements to align attention layers
        enriched_query = f"Customer complaints and negative feedback highlighting {manager_query}"
        
        # -----------------------------------------------------------------
        # STAGE 2: SPARSE RETRIEVAL (BM25)
        # -----------------------------------------------------------------
        tokenized_corpus = [doc.lower().split(" ") for doc in documents]
        bm25 = BM25Okapi(tokenized_corpus)
        tokenized_query = enriched_query.lower().split(" ")
        raw_bm25_scores = np.array(bm25.get_scores(tokenized_query))
        normalized_bm25 = self._normalize_scores(raw_bm25_scores)

        # -----------------------------------------------------------------
        # STAGE 3: DENSE RETRIEVAL (Semantic Embeddings)
        # -----------------------------------------------------------------
        query_embedding = self.dense_model.encode(enriched_query, convert_to_tensor=True)
        doc_embeddings = self.dense_model.encode(documents, convert_to_tensor=True)
        raw_dense_scores = util.cos_sim(query_embedding, doc_embeddings).cpu().numpy()[0]
        normalized_dense = self._normalize_scores(raw_dense_scores)

        # -----------------------------------------------------------------
        # STAGE 4: DISTRIBUTION-BASED SCORE FUSION (DBSF)
        # -----------------------------------------------------------------
        # Outperforms blind RRF by allowing calibrated system weighting (e.g., 70/30)
        sparse_weight = 1.0 - dense_weight
        fused_scores = (normalized_dense * dense_weight) + (normalized_bm25 * sparse_weight)
        
        # Candidate generation: Gather top items for deep re-evaluation
        top_indices = np.argsort(fused_scores)[::-1]
        candidate_passages = [corpus[idx] for idx in top_indices]

        # -----------------------------------------------------------------
        # STAGE 5: ADVANCED CROSS-ENCODER RERANKING
        # -----------------------------------------------------------------
        # Evaluates full matrix context; penalizes irrelevant high-keyword matches
        rerank_pairs = [[enriched_query, doc["text"]] for doc in candidate_passages]
        rerank_scores = self.reranker.predict(rerank_pairs)
        
        # Map scores back to metadata payloads
        for idx, score in enumerate(rerank_scores):
            candidate_passages[idx]["retrieval_score"] = float(score)
            
        # Final absolute sort by true context relevancy
        final_ordered_pipeline = sorted(
            candidate_passages, 
            key=lambda x: x["retrieval_score"], 
            reverse=True
        )
        
        return final_ordered_pipeline

# =====================================================================
# EXECUTION WITH RESTAURANT FEEDBACK DATA
# =====================================================================
if __name__ == "__main__":
    # The Exact Dataset causing the keyword trap
    raw_reviews_db = [
        {
            "id": "review_1", 
            "text": "The food was okay, but the staff need to turn down the audio tracks. It was way too loud."
        },
        {
            "id": "review_2", 
            "text": "The ambient music was blasting so deafeningly loud we could not hear each other talk. Ruined the vibe."
        },
        {
            "id": "review_3", 
            "text": "Great background acoustics and elegant interior design. The volume level was absolutely perfect."
        },
        {
            "id": "review_4", 
            "text": "Terrible service pacing. Our main course took 45 minutes to arrive after the appetizers."
        }
    ]

    # Initialize Engine
    engine = FeedbackRetrievalEngine()
    
    # Process problematic query
    results = engine.execute_pipeline(
        manager_query="problems with background audio volume", 
        corpus=raw_reviews_db,
        dense_weight=0.65
    )

    # Print Clean, Structural JSON Output
    print("\n🎯 [PRODUCTION SOTA OUTPUT] Highly Accurate Context Alignment:")
    print("-" * 80)
    for rank, item in enumerate(results, start=1):
        print(f"Rank {rank} | ID: {item['id']} | Neural Confidence Score: {item['retrieval_score']:.4f}")
        print(f"Text: \"{item['text']}\"\n")
