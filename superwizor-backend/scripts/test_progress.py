#!/usr/bin/env python3
import sys
import os
import re

# ANSI colors
GREEN = "\033[32m"
RED = "\033[31m"
YELLOW = "\033[33m"
BLUE = "\033[34m"
MAGENTA = "\033[35m"
CYAN = "\033[36m"
RESET = "\033[0m"
BOLD = "\033[1m"

def get_all_tests():
    # 1. Resolve relative to script location (scripts/test_progress.py -> tests/e2e)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    backend_dir = os.path.dirname(script_dir)
    tests_dir = os.path.join(backend_dir, "tests", "e2e")
    
    # 2. Fallbacks
    if not os.path.exists(tests_dir):
        tests_dir = "tests/e2e"
    if not os.path.exists(tests_dir):
        tests_dir = "e2e"
    if not os.path.exists(tests_dir):
        tests_dir = "superwizor-backend/tests/e2e"
    if not os.path.exists(tests_dir):
        tests_dir = "../superwizor-backend/tests/e2e"
        
    test_names = []
    if os.path.exists(tests_dir):
        for f in os.listdir(tests_dir):
            if f.endswith("_test.go"):
                try:
                    with open(os.path.join(tests_dir, f), "r") as file:
                        for line in file:
                            # Match Test functions
                            match = re.match(r"^func (Test\w+)\(", line)
                            if match:
                                test_names.append(match.group(1))
                except Exception:
                    pass
    # Return unique sorted tests
    return sorted(list(set(test_names)))

def main():
    tests = get_all_tests()
    total_tests = len(tests) if tests else 33
    current_test = ""
    completed_count = 0
    passed_count = 0
    failed_count = 0
    has_failed = False
    
    # Map test names to index to estimate progress
    test_map = {name: idx for idx, name in enumerate(tests)}
    
    sys.stdout.write(f"{BOLD}{CYAN}🧪 Uruchamianie E2E z paskiem postępu... (Wykryto {total_tests} testów){RESET}\n")
    sys.stdout.flush()

    try:
        for line in sys.stdin:
            clean_line = line.rstrip("\r\n")
            
            # Check for test start
            run_match = re.search(r"=== RUN\s+(Test\w+)", clean_line)
            if run_match:
                current_test = run_match.group(1)
                if current_test in test_map:
                    completed_count = test_map[current_test]
            
            # Check for pass/fail/skip to update statistics
            pass_match = re.search(r"--- PASS:\s+(Test\w+)", clean_line)
            fail_match = re.search(r"--- FAIL:\s+(Test\w+)", clean_line)
            skip_match = re.search(r"--- SKIP:\s+(Test\w+)", clean_line)
            
            if pass_match:
                passed_count += 1
                clean_line = clean_line.replace("--- PASS:", f"{GREEN}✓ PASS:{RESET}")
            elif fail_match:
                failed_count += 1
                has_failed = True
                clean_line = clean_line.replace("--- FAIL:", f"{RED}✗ FAIL:{RESET}")
            elif skip_match:
                clean_line = clean_line.replace("--- SKIP:", f"{YELLOW}⚠ SKIP:{RESET}")
            
            if clean_line.startswith("FAIL"):
                has_failed = True
            
            # Highlight E2E indicators
            if "✓" in clean_line:
                clean_line = clean_line.replace("✓", f"{GREEN}✓{RESET}")
            if "⚠" in clean_line:
                clean_line = clean_line.replace("⚠", f"{YELLOW}⚠{RESET}")
            if "════" in clean_line:
                clean_line = f"{BLUE}{clean_line}{RESET}"
                
            # Clear the bottom progress bar line
            sys.stdout.write("\r\033[K")
            
            # Print the log line
            sys.stdout.write(clean_line + "\n")
            
            # Re-draw progress bar
            pct = int((completed_count / total_tests) * 100) if total_tests else 0
            bar_len = 25
            filled_len = int(bar_len * completed_count // total_tests) if total_tests else 0
            bar = "█" * filled_len + "░" * (bar_len - filled_len)
            
            stats = f"{GREEN}{passed_count} ok{RESET}"
            if failed_count:
                stats += f", {RED}{failed_count} fail{RESET}"
                
            progress_bar = f"\r{BOLD}[{bar}] {pct}% | {stats} | Aktualny: {CYAN}{current_test}{RESET}"
            sys.stdout.write(progress_bar)
            sys.stdout.flush()
            
    except KeyboardInterrupt:
        has_failed = True
    finally:
        # Clear progress bar line
        sys.stdout.write("\r\033[K")
        sys.stdout.flush()
        if has_failed or failed_count > 0:
            sys.exit(1)

if __name__ == "__main__":
    main()
