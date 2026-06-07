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
    # 1. Gather all candidates for tests directory
    candidates = []
    
    # Try relative to script location
    try:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        backend_dir = os.path.dirname(script_dir)
        candidates.append(os.path.join(backend_dir, "tests", "e2e"))
    except Exception:
        pass
        
    # Standard fallbacks relative to CWD
    candidates.extend([
        "e2e",
        "tests/e2e",
        "superwizor-backend/tests/e2e",
        "../superwizor-backend/tests/e2e",
        "../../superwizor-backend/tests/e2e",
        "../tests/e2e",
    ])
    
    # Walk up from CWD to find where tests are
    cwd = os.getcwd()
    for _ in range(5):
        candidates.append(os.path.join(cwd, "superwizor-backend/tests/e2e"))
        candidates.append(os.path.join(cwd, "tests/e2e"))
        parent = os.path.dirname(cwd)
        if parent == cwd:
            break
        cwd = parent

    # Find the first candidate that exists and actually contains Go test files
    tests_dir = None
    for cand in candidates:
        cand = os.path.abspath(cand)
        if os.path.isdir(cand):
            try:
                has_go_tests = any(f.endswith("_test.go") for f in os.listdir(cand))
                if has_go_tests:
                    tests_dir = cand
                    break
            except Exception:
                pass

    test_names = []
    if tests_dir and os.path.exists(tests_dir):
        # Scan files in alphabetical order to preserve definition order
        try:
            files = sorted(os.listdir(tests_dir))
            for f in files:
                if f.endswith("_test.go"):
                    with open(os.path.join(tests_dir, f), "r") as file:
                        for line in file:
                            match = re.match(r"^func (Test\w+)\(", line)
                            if match:
                                name = match.group(1)
                                if name not in test_names:
                                    test_names.append(name)
        except Exception:
            pass

    return test_names

def main():
    tests = get_all_tests()
    total_tests = len(tests) if tests else 33
    current_test = ""
    completed_top_level_tests = set()
    passed_count = 0
    failed_count = 0
    skipped_count = 0
    has_failed = False
    completed_count = 0
    
    # Map test names to their index in the definition order
    test_map = {name: idx for idx, name in enumerate(tests)}
    
    sys.stdout.write(f"{BOLD}{CYAN}🧪 Uruchamianie E2E z paskiem postępu... (Wykryto {total_tests} testów){RESET}\n")
    sys.stdout.flush()

    try:
        for line in sys.stdin:
            clean_line = line.rstrip("\r\n")
            
            # Check for test start
            run_match = re.search(r"=== RUN\s+(Test\w+)(\S*)", clean_line)
            if run_match:
                test_name = run_match.group(1)
                suffix = run_match.group(2)
                # Only update current test if it's a top-level test
                if not suffix.startswith("/"):
                    current_test = test_name
            
            # Check for pass/fail/skip to update statistics
            pass_match = re.search(r"--- PASS:\s+(Test\w+)(\S*)", clean_line)
            fail_match = re.search(r"--- FAIL:\s+(Test\w+)(\S*)", clean_line)
            skip_match = re.search(r"--- SKIP:\s+(Test\w+)(\S*)", clean_line)
            
            if pass_match:
                test_name = pass_match.group(1)
                suffix = pass_match.group(2)
                clean_line = clean_line.replace("--- PASS:", f"{GREEN}✓ PASS:{RESET}")
                if not suffix.startswith("/"):
                    completed_top_level_tests.add(test_name)
                    passed_count += 1
            elif fail_match:
                test_name = fail_match.group(1)
                suffix = fail_match.group(2)
                clean_line = clean_line.replace("--- FAIL:", f"{RED}✗ FAIL:{RESET}")
                if not suffix.startswith("/"):
                    completed_top_level_tests.add(test_name)
                    failed_count += 1
                    has_failed = True
            elif skip_match:
                test_name = skip_match.group(1)
                suffix = skip_match.group(2)
                clean_line = clean_line.replace("--- SKIP:", f"{YELLOW}⚠ SKIP:{RESET}")
                if not suffix.startswith("/"):
                    completed_top_level_tests.add(test_name)
                    skipped_count += 1
            
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
            
            # Estimate completed count: either how many have finished, or the index of currently running
            est_completed = len(completed_top_level_tests)
            if current_test in test_map:
                est_completed = max(est_completed, test_map[current_test])
            completed_count = max(completed_count, est_completed)
                
            # Re-draw progress bar with terminal width protection
            try:
                cols = os.get_terminal_size().columns
            except Exception:
                cols = 80
                
            pct = int((completed_count / total_tests) * 100) if total_tests else 0
            bar_len = 15
            filled_len = int(bar_len * completed_count // total_tests) if total_tests else 0
            bar = "█" * filled_len + "░" * (bar_len - filled_len)
            
            stats = f"{GREEN}{passed_count} ok{RESET}"
            if failed_count:
                stats += f", {RED}{failed_count} fail{RESET}"
                
            # Calculate safety margin for test name to fit in one line
            plain_stats = f"{passed_count} ok" + (f", {failed_count} fail" if failed_count else "")
            fixed_len = 1 + bar_len + 2 + 4 + 3 + len(plain_stats) + 13  # '[' + bar_len + '] ' + '100%' + ' | ' + stats + ' | Aktualny: '
            available = cols - fixed_len - 3
            
            display_test = current_test
            if len(display_test) > available and available > 5:
                display_test = display_test[:available-3] + "..."
            elif available <= 5:
                display_test = ""
                
            progress_bar = f"\r{BOLD}[{bar}] {pct}% | {stats} | Aktualny: {CYAN}{display_test}{RESET}"
            sys.stdout.write(progress_bar)
            sys.stdout.flush()
            
    except KeyboardInterrupt:
        has_failed = True
    finally:
        # Clear progress bar line
        sys.stdout.write("\r\033[K")
        sys.stdout.flush()
        
        if has_failed or failed_count > 0:
            sys.stdout.write(f"\n{BOLD}{RED}❌ NIEKTÓRE TESTY E2E ZAKOŃCZYŁY SIĘ NIEPOWODZENIEM!{RESET}\n")
            sys.stdout.write(f"📊 {BOLD}Podsumowanie uruchomienia:{RESET}\n")
            sys.stdout.write(f"  {GREEN}✅ Zdane testy:{RESET}  {passed_count}\n")
            sys.stdout.write(f"  {RED}❌ Niezdane:{RESET}     {failed_count}\n")
            if skipped_count:
                sys.stdout.write(f"  {YELLOW}🟡 Pominięte:{RESET}    {skipped_count}\n")
            sys.stdout.write(f"\n{YELLOW}🔍 Przejrzyj logi powyżej, aby zidentyfikować i poprawić błędy. Do dzieła! 💪{RESET}\n\n")
            sys.stdout.flush()
            sys.exit(1)
        else:
            sys.stdout.write(f"\n{BOLD}{GREEN}✨ WSZYSTKIE TESTY E2E ZAKOŃCZONE SUKCESEM! ✨{RESET}\n")
            sys.stdout.write(f"📊 {BOLD}Podsumowanie uruchomienia:{RESET}\n")
            sys.stdout.write(f"  {GREEN}✅ Zdane testy:{RESET}  {passed_count} / {total_tests}\n")
            if skipped_count:
                sys.stdout.write(f"  {YELLOW}🟡 Pominięte:{RESET}    {skipped_count}\n")
            sys.stdout.write(f"\n{GREEN}🎉 Środowisko lokalne działa w 100% stabilnie! Świetna robota! 🚀{RESET}\n\n")
            sys.stdout.flush()

if __name__ == "__main__":
    main()
