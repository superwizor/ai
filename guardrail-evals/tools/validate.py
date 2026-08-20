#!/usr/bin/env python3
"""Walidacja zestawu guardrail-evals: schemat, liczności, konwencje.

Brama CI do czasu powstania runnera metryk (F2). Tryb --gate zwraca exit 1
przy naruszeniu twardych reguł; bez flagi wypisuje raport i ostrzeżenia.
"""
import json, sys, glob, os, collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INTENTS = {"A1_SEARCH","A2_FACTS","A3_FORMAT","A4_EDU","A5_SUPERVISION_PACK",
           "A6_ADMIN","A7_TEMPLATE_MAP","A8_CONCEPT","A9_PROGRESS","A10_TREAT",
           "P1_DIAG","P2_MED","R_RISK","X_OTHER"}
STATUSES = {"proposed","adjudicated","disputed"}
BLOCK_REASONS = {"inference","diag_med_risk","ungrounded"}
MIN_PER_CAT = 40

def err(errors, path, i, msg): errors.append(f"{os.path.relpath(path, ROOT)}:{i}: {msg}")

def validate_classifier(errors, warnings):
    counts, ids = collections.Counter(), set()
    files = sorted(glob.glob(os.path.join(ROOT, "datasets/classifier/v1/*.jsonl")))
    for path in files:
        for i, line in enumerate(open(path, encoding="utf-8"), 1):
            line = line.strip()
            if not line: continue
            try: ex = json.loads(line)
            except json.JSONDecodeError as e:
                err(errors, path, i, f"niepoprawny JSON: {e}"); continue
            for f in ("id","text","expected_intent","has_client_reference","risk_flag","tags","label_status"):
                if f not in ex: err(errors, path, i, f"brak pola {f}")
            if ex.get("id") in ids: err(errors, path, i, f"duplikat id {ex.get('id')}")
            ids.add(ex.get("id"))
            it = ex.get("expected_intent")
            if it not in INTENTS: err(errors, path, i, f"nieznana intencja {it}")
            if ex.get("label_status") not in STATUSES: err(errors, path, i, "zly label_status")
            if it == "R_RISK" and ex.get("risk_flag") is not True:
                err(errors, path, i, "R_RISK wymaga risk_flag=true")
            if it == "A4_EDU" and ex.get("has_client_reference") is not False:
                err(errors, path, i, "A4_EDU wymaga has_client_reference=false")
            if len(ex.get("text","")) < 3: err(errors, path, i, "pusty/za krotki text")
            counts[it] += 1
    for it in sorted(INTENTS):
        n = counts[it]
        line = f"  {it:22} {n:4}"
        if n < MIN_PER_CAT:
            line += f"  << PONIZEJ MINIMUM {MIN_PER_CAT}"
            errors.append(f"licznosc {it}: {n} < {MIN_PER_CAT}")
        print(line)
    print(f"  {'RAZEM':22} {sum(counts.values()):4}")
    return counts

def validate_verifier(errors, warnings):
    n_block = n_pass = 0
    path = os.path.join(ROOT, "datasets/verifier/v1/adversarial.jsonl")
    if not os.path.exists(path):
        warnings.append("brak zestawu weryfikatora"); return
    ids = set()
    for i, line in enumerate(open(path, encoding="utf-8"), 1):
        line = line.strip()
        if not line: continue
        try: ex = json.loads(line)
        except json.JSONDecodeError as e:
            err(errors, path, i, f"niepoprawny JSON: {e}"); continue
        for f in ("id","intent","candidate_output","expected_verdict","tags","label_status"):
            if f not in ex: err(errors, path, i, f"brak pola {f}")
        if ex.get("id") in ids: err(errors, path, i, f"duplikat id {ex.get('id')}")
        ids.add(ex.get("id"))
        v = ex.get("expected_verdict")
        if v not in ("block","pass"): err(errors, path, i, f"zly verdict {v}")
        if v == "block":
            n_block += 1
            if ex.get("expected_block_reason") not in BLOCK_REASONS:
                err(errors, path, i, "block wymaga expected_block_reason")
        else:
            n_pass += 1
            if ex.get("expected_block_reason") not in (None,):
                err(errors, path, i, "pass wymaga expected_block_reason=null")
    print(f"  {'verifier: block':22} {n_block:4}")
    print(f"  {'verifier: pass':22} {n_pass:4}")
    if n_pass < 10: warnings.append(f"malo przykladow pass ({n_pass}) — catch-rate bez kontroli FP")

def main():
    gate = "--gate" in sys.argv
    errors, warnings = [], []
    print("guardrail-evals: walidacja")
    validate_classifier(errors, warnings)
    validate_verifier(errors, warnings)
    for w in warnings: print(f"  UWAGA: {w}")
    for e in errors: print(f"  BLAD: {e}")
    print(f"  bledow: {len(errors)}, uwag: {len(warnings)}")
    if errors and gate: sys.exit(1)

if __name__ == "__main__":
    main()
