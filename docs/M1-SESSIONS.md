# Running the M1 sessions

M1b is run by the project owner. This covers stage A and how to read the results. The full rules
and the reasons for them are in `docs/ARCHITECTURE.md`, section 6.

## Stage A: three people, observed

1. Start Docker, then run `sh scripts/serve-m1.sh` from the repository root. The first start needs
   the image, which `docker build -t symalgebra-ci .` creates in about 13 minutes.
2. Open `http://localhost:8080` on your machine. For the test phone, use this machine's LAN
   address on port 8080, on the same network.
3. Pick a random code for the person. Keep no list linking codes to names.
4. Let them work. Do not explain the input unless they are stuck for a long time, and note when
   you step in. The first problem is a worked example and is not counted.
5. At the end they press Copy and send you the summary. On a phone over plain HTTP, Copy falls
   back to selecting the text, so they copy it by hand. That is expected.
6. Save each summary as a file, then run the tally below. Delete the messages once the results
   are transcribed.

Zero passes out of 3 stops before stage B. Stage A cannot certify the milestone on its own.

## Reading the results

```bash
python scaffold/m1/tally.py summary-a.json summary-b.json summary-c.json
```

- **PASS** means at least 5 of the 6 multi-operation problems were solved with a self-typed
  intermediate line and no bottom-out hint (70% of 6 rounds up to 5).
- **CANNOT** means more than 20% input failure after the person's first two counted problems.
- A valid step marked wrong voids that session. Watch for this, since the summary cannot show it.
- Voided sessions and retests use new people.

The overall gate needs at least 5 passes of 8, at least 3 of 5 in stage B, and fewer than 3 people
marked CANNOT. If it fails and every failure is CANNOT, make one input fix and retest. Any other
failed gate stops the project for redesign.

## Stage B: five people, hosted

Stage B needs a hosted URL, and the host is still undecided. Its conditions in section 6 must all
be met first: no card, a log canary test on the hosted image, and the service suspended outside
slots. The page already carries the 18+ statement and the notice that the host sees IP addresses
and steps. Decide the host after stage A.
