# R0-05 Learning Science Lead

M1 tests willingness to type steps, never learning.

**Definitions.** Eight issued codes; ten problems each from a 24-item bank; no brackets or fractions.
- Attempt: one Check press on a non-empty line.
- Input failure: attempt the parser rejects, or accepted line flagged "not what I meant" on the rendered echo.
- Step completion: multi-operation problem solved with at least one self-typed intermediate line, no bottom-out hint. Jumping to x=3 is valid but does not count.
- Abandonment: set unfinished, or no export 72 hours after issuing the code.

**Stop rule.** A person passes by finishing with step completion on at least 70% of multi-operation problems. Stop and redesign if 4 or fewer pass, or 3 or more exceed 20% input failure after their first two problems. A valid step marked wrong voids that session; fix and rerun.

These are preset judgement lines, not benchmarks. Computed: true pass rates of 30/50/80% clear the gate 6/36/94% of the time. It detects catastrophe only; even 8/8 has a 95% lower bound of 63%.

**Data path.** Server writes nothing. The tab holds events in memory. The end screen shows plain text: code, counts, relative times, rejected strings. The adult sends it by hand. Only the owner files it, as P0n.txt outside the repo, publishing aggregates and deleting raw files afterwards. Closed tabs export nothing, so the denominator is issued codes: silence counts as abandonment. Five sessions unmoderated; three observed, owner taking paper notes. Test: scripted sentinel string, zero hits in server logs.

**Feedback.** Immediate; person retypes the wrong line (Corbett and Anderson, programming only). Rejection shows the exact counterexample. Hints on authored paths: nudge, operation, next line. Bottom-out needs one attempt and retyping. Valid off-path lines get a generic nudge; count them. First problem is a worked example teaching input. No mal-rule naming (Sleeman and Selent nulls).

**Risks.** (1) Friendly, numerate adults false-pass: require five non-contacts rusty at algebra. (2) False rejections corrupt every measure. (3) Adult results do not transfer to learners.

**Cut.** Rule names, mastery, mixed review, gaming detection, surveys.

**Will not work.** Authored paths alone reject valid steps, breaking "never wrong". The report's browser numeric check breaks frontend-holds-no-truth. M1 needs a throwaway SBCL endpoint: reduce each side to ax+b exactly, compare solution sets, otherwise "not judged". "Will not type" conflates "need not": competent adults skip lines. The owner must rule that consented adult exports are not stored student data.

**Verified versus assumed.** Verified: binomials computed here; claims match the notes, primaries unopened. Not used: report-flagged RAND, WWC and Pane figures, ASSISTments test, gaming link. Khanmigo's 17% is not a benchmark. Assumed: ten-problem duration, 72 hours, every threshold, recruitable rusty adults, free host with logs off.
