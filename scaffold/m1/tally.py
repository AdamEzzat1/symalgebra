"""M1 gate figures from pasted session summaries, as defined in ARCHITECTURE section 6.

Usage: tally.py <summary.json> ...   Each file holds one session's copied summary.
Nothing here identifies a person; the code is the only key.
"""

import json
import math
import sys

MULTI_PER_SESSION = 6
PASS_SHARE = 0.70
CANNOT_SHARE = 0.20
SETTLING_PROBLEMS = 2


def tally(session):
    counted = [p for p in session["problems"] if p["kind"] != "worked"]
    after_settling = counted[SETTLING_PROBLEMS:]
    attempts = sum(p["attempts"] for p in after_settling)
    # A flagged line was already an attempt, so every input failure has one behind it.
    failures = sum(p["input_failures"] for p in after_settling)
    completed = sum(
        1
        for p in counted
        if p["kind"] == "multi"
        and p["solved"]
        and p["intermediate_lines"] >= 1
        and not p["bottom_out"]
    )
    # A person who stops early is measured against the full six, so stopping cannot pass.
    needed = math.ceil(MULTI_PER_SESSION * PASS_SHARE)
    failure_share = failures / attempts if attempts else 0.0
    return {
        "code": session["code"],
        "completed": completed,
        "needed": needed,
        "passed": completed >= needed,
        "attempts": attempts,
        "failures": failures,
        "cannot": failure_share > CANNOT_SHARE,
    }


def main():
    for path in sys.argv[1:]:
        with open(path, encoding="utf-8") as f:
            row = tally(json.load(f))
        print(
            f"{row['code']}: completed {row['completed']} of {MULTI_PER_SESSION}, "
            f"need {row['needed']}, {'PASS' if row['passed'] else 'NOT PASS'}; "
            f"input failures {row['failures']} of {row['attempts']} attempts"
            f"{', CANNOT' if row['cannot'] else ''}"
        )


main()
