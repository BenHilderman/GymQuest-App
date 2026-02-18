"""
run_eval.py - evaluation harness for GymQuest AI Coach

runs 25 test cases (~120 sessions) against the RAG engine and
training load calculator to verify correctness.

modes:
  --dry-run  : tests RAG retrieval + training load metrics only (no LLM, fast)
  --full     : runs through the LLM agent, checks response keywords

usage:
    cd backend
    python eval/run_eval.py --dry-run
    python eval/run_eval.py --full
"""

import json
import sys
import os
import argparse
import asyncio
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, Any, List, Tuple

# add parent dir to path so we can import backend modules
sys.path.insert(0, str(Path(__file__).parent.parent))

from training_load import TrainingLoadCalculator
from rag_engine import RAGEngine


def shift_dates_to_present(workouts: List[Dict]) -> List[Dict]:
    """shift workout dates so the most recent one is today, preserving spacing"""
    if not workouts:
        return workouts

    # find the most recent date in the case
    dates = []
    for w in workouts:
        try:
            dates.append(datetime.fromisoformat(w["date"]).date())
        except (ValueError, KeyError):
            pass

    if not dates:
        return workouts

    max_date = max(dates)
    today = datetime.now().date()
    offset = today - max_date

    shifted = []
    for w in workouts:
        w_copy = dict(w)
        try:
            original = datetime.fromisoformat(w["date"]).date()
            w_copy["date"] = (original + offset).isoformat()
        except (ValueError, KeyError):
            pass
        shifted.append(w_copy)

    return shifted


def load_cases() -> List[Dict[str, Any]]:
    cases_path = Path(__file__).parent / "cases.json"
    with open(cases_path) as f:
        data = json.load(f)
    return data["cases"]


def check_metrics(metrics: Dict[str, Any], expected: Dict[str, Any]) -> List[Tuple[str, bool, str]]:
    """check training load metrics against expected conditions"""
    checks = []

    mc = expected.get("metrics_check", {})
    if not mc:
        return checks

    acwr = metrics.get("acwr", 0)
    strain = metrics.get("strain_score", 0)
    monotony = metrics.get("monotony", 0)
    volume_status = metrics.get("volume_status", {})

    if "acwr_above" in mc:
        threshold = mc["acwr_above"]
        passed = acwr > threshold
        checks.append((f"ACWR > {threshold}", passed, f"actual={acwr:.2f}"))

    if "acwr_below" in mc:
        threshold = mc["acwr_below"]
        passed = acwr < threshold
        checks.append((f"ACWR < {threshold}", passed, f"actual={acwr:.2f}"))

    if "acwr_between" in mc:
        low, high = mc["acwr_between"]
        passed = low <= acwr <= high
        checks.append((f"ACWR in [{low}, {high}]", passed, f"actual={acwr:.2f}"))

    if "strain_above" in mc:
        threshold = mc["strain_above"]
        passed = strain > threshold
        checks.append((f"strain > {threshold}", passed, f"actual={strain:.1f}"))

    if "monotony_above" in mc:
        threshold = mc["monotony_above"]
        passed = monotony > threshold
        checks.append((f"monotony > {threshold}", passed, f"actual={monotony:.2f}"))

    if "volume_over" in mc:
        for muscle in mc["volume_over"]:
            status = volume_status.get(muscle, "unknown")
            passed = status in ("high", "over")
            checks.append((f"{muscle} volume high/over", passed, f"actual={status}"))

    return checks


def check_rag_retrieval(rag: RAGEngine, prompt: str, expected: Dict[str, Any]) -> List[Tuple[str, bool, str]]:
    """check that RAG can retrieve the expected exercises.

    tries multiple queries: the user prompt, plus targeted queries derived
    from the expected exercise names (simulating what the agent would search for).
    """
    checks = []

    expected_exercises = expected.get("rag_should_retrieve", [])
    if not expected_exercises:
        return checks

    # build a pool of retrieved names from multiple search strategies
    all_retrieved = set()

    # 1. search with the user's prompt
    results = rag.search(prompt, top_k=10)
    for r in results:
        all_retrieved.add(r["source"])

    # 2. search with each expected exercise name (simulates agent's targeted queries)
    for ex_name in expected_exercises:
        results = rag.search(ex_name, top_k=5)
        for r in results:
            all_retrieved.add(r["source"])

    for exercise_name in expected_exercises:
        found = any(exercise_name.lower() in name.lower() for name in all_retrieved)
        checks.append((
            f"RAG retrieves '{exercise_name}'",
            found,
            f"pool size: {len(all_retrieved)}"
        ))

    return checks


def check_response_keywords(response: str, expected: Dict[str, Any]) -> List[Tuple[str, bool, str]]:
    """check that the LLM response mentions/avoids expected keywords"""
    checks = []
    response_lower = response.lower()

    for keyword in expected.get("should_mention", []):
        found = keyword.lower() in response_lower
        checks.append((f"mentions '{keyword}'", found, f""))

    for keyword in expected.get("should_not_mention", []):
        found = keyword.lower() in response_lower
        checks.append((f"avoids '{keyword}'", not found, f""))

    return checks


def run_dry_eval(cases: List[Dict], rag: RAGEngine, calc: TrainingLoadCalculator) -> Dict[str, Any]:
    """dry run: RAG retrieval + training load metrics only, no LLM"""
    results = {"total": 0, "passed": 0, "failed": 0, "cases": [], "by_category": {}}

    for case in cases:
        case_result = {
            "id": case["id"],
            "name": case["name"],
            "category": case["category"],
            "checks": [],
            "passed": True,
        }

        # shift dates to present so ACWR/strain calculations are meaningful
        workouts = shift_dates_to_present(case["workouts"])

        # compute training load metrics
        metrics = calc.calculate_metrics(workouts)

        # check metrics
        metric_checks = check_metrics(metrics, case["expected"])
        case_result["checks"].extend(metric_checks)

        # check RAG retrieval
        rag_checks = check_rag_retrieval(rag, case["prompt"], case["expected"])
        case_result["checks"].extend(rag_checks)

        # did this case pass?
        if case_result["checks"]:
            case_result["passed"] = all(c[1] for c in case_result["checks"])
        results["total"] += 1

        if case_result["passed"]:
            results["passed"] += 1
        else:
            results["failed"] += 1

        results["cases"].append(case_result)

        # track by category
        cat = case["category"]
        if cat not in results["by_category"]:
            results["by_category"][cat] = {"total": 0, "passed": 0}
        results["by_category"][cat]["total"] += 1
        if case_result["passed"]:
            results["by_category"][cat]["passed"] += 1

    return results


async def run_full_eval(cases: List[Dict], rag: RAGEngine, calc: TrainingLoadCalculator) -> Dict[str, Any]:
    """full run: includes LLM agent responses"""
    from coach import EnhancedCoach

    coach = EnhancedCoach(rag_engine=rag, training_calculator=calc)
    results = {"total": 0, "passed": 0, "failed": 0, "cases": [], "by_category": {}}

    for case in cases:
        case_result = {
            "id": case["id"],
            "name": case["name"],
            "category": case["category"],
            "checks": [],
            "passed": True,
            "response": "",
        }

        # shift dates to present so ACWR/strain calculations are meaningful
        workouts = shift_dates_to_present(case["workouts"])

        # compute training load
        metrics = calc.calculate_metrics(workouts)

        # check metrics
        metric_checks = check_metrics(metrics, case["expected"])
        case_result["checks"].extend(metric_checks)

        # check RAG retrieval
        rag_checks = check_rag_retrieval(rag, case["prompt"], case["expected"])
        case_result["checks"].extend(rag_checks)

        # get LLM response
        try:
            response = await coach.get_advice(
                prompt=case["prompt"],
                profile=case["profile"],
                workouts=workouts,
                load_metrics=metrics,
            )
            case_result["response"] = response

            # check response keywords
            keyword_checks = check_response_keywords(response, case["expected"])
            case_result["checks"].extend(keyword_checks)
        except Exception as e:
            case_result["checks"].append((f"LLM call", False, str(e)))

        # did this case pass?
        if case_result["checks"]:
            case_result["passed"] = all(c[1] for c in case_result["checks"])
        results["total"] += 1

        if case_result["passed"]:
            results["passed"] += 1
        else:
            results["failed"] += 1

        results["cases"].append(case_result)

        cat = case["category"]
        if cat not in results["by_category"]:
            results["by_category"][cat] = {"total": 0, "passed": 0}
        results["by_category"][cat]["total"] += 1
        if case_result["passed"]:
            results["by_category"][cat]["passed"] += 1

    return results


def print_results(results: Dict[str, Any], verbose: bool = False):
    """pretty-print evaluation results"""
    total = results["total"]
    passed = results["passed"]
    failed = results["failed"]
    score = (passed / total * 100) if total > 0 else 0

    print(f"\n{'='*60}")
    print(f"  GymQuest AI Coach Evaluation")
    print(f"{'='*60}")
    print(f"  Total cases:  {total}")
    print(f"  Passed:       {passed}")
    print(f"  Failed:       {failed}")
    print(f"  Score:        {score:.1f}%")
    print(f"{'='*60}")

    # per-category breakdown
    print(f"\n  Category Breakdown:")
    print(f"  {'-'*50}")
    for cat, stats in sorted(results["by_category"].items()):
        cat_score = (stats["passed"] / stats["total"] * 100) if stats["total"] > 0 else 0
        status = "PASS" if stats["passed"] == stats["total"] else "FAIL"
        print(f"  [{status}] {cat:<25} {stats['passed']}/{stats['total']} ({cat_score:.0f}%)")

    # per-case details
    print(f"\n  Case Details:")
    print(f"  {'-'*50}")
    for case in results["cases"]:
        status = "PASS" if case["passed"] else "FAIL"
        print(f"  [{status}] #{case['id']:02d} {case['name']}")

        if verbose or not case["passed"]:
            for check_name, check_passed, detail in case["checks"]:
                icon = "  OK" if check_passed else "FAIL"
                detail_str = f" ({detail})" if detail else ""
                print(f"       [{icon}] {check_name}{detail_str}")

            if "response" in case and case["response"]:
                preview = case["response"][:120].replace("\n", " ")
                print(f"       Response: {preview}...")

    print()


def main():
    parser = argparse.ArgumentParser(description="GymQuest AI Coach Evaluation")
    parser.add_argument("--dry-run", action="store_true", help="RAG + metrics only, no LLM")
    parser.add_argument("--full", action="store_true", help="Full eval including LLM responses")
    parser.add_argument("--verbose", "-v", action="store_true", help="Show all check details")
    args = parser.parse_args()

    if not args.dry_run and not args.full:
        args.dry_run = True  # default to dry run

    cases = load_cases()
    total_sessions = sum(len(c["workouts"]) for c in cases)
    print(f"Loaded {len(cases)} cases ({total_sessions} sessions)")

    # init services
    calc = TrainingLoadCalculator()
    rag = RAGEngine()
    print(f"RAG engine: {len(rag.exercises)} exercises indexed")

    if args.dry_run:
        print("Running dry evaluation (RAG + metrics, no LLM)...")
        results = run_dry_eval(cases, rag, calc)
        print_results(results, verbose=args.verbose)
    elif args.full:
        print("Running full evaluation (RAG + metrics + LLM)...")
        results = asyncio.run(run_full_eval(cases, rag, calc))
        print_results(results, verbose=args.verbose)


if __name__ == "__main__":
    main()
