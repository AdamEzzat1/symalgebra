# R0-09 Privacy and security (not legal advice)

**Host:** Render free Docker service, no card, so overage suspends.

**Data by milestone**
- M0, M2, M4: no visitor data.
- M1, M3: IP and headers at platform; problem ID and step strings in RAM per request.
- M5: licensed datasets offline, never in image or public repo.
- M6: linked delayed tests require stored pseudonymous data.

**Server may log:** time, route, status, verdict enum, error enum, latency bucket, version. Never bodies, expressions, headers or IP. Steps go in POST bodies, never URLs. Use `--disable-debugger`, map errors to enums, capture swipl stderr: backtraces print terms into runtime logs (Hobby: 7 days). CI posts a canary string and fails if logged.

**Not controllable:** Render's load balancer terminates TLS, so Render handles every IP and step in transit; Cloudflare supplies DDoS protection. Browser-only checking would not send steps. The site must say so; "we store nothing" would be false.

**Limits:** body 1 KB; step 256 chars; 64 tokens; depth 16, counted before recursing; integer literals 8 digits; `^` takes literal exponents 0..8, no towers; result precheck 4096 bits; 64 polynomial terms; fuel counters in Lisp, `call_with_inference_limit` in Prolog. Over-budget returns OUT_OF_FRAGMENT, never rejection. Two concurrent checks, queue 8, then 503; 32 sockets; same-origin only. No per-IP limiter: it reads IPs. One abuser can deny service; accept that.

**Maths-only:** server-side allowlist. Letters: only the problem's declared variable, so "adam" fails rather than parsing as a product. The digit cap blocks phones and SSNs. No feedback box, no user-entered problems.

**M1 testers:** direct invitations to adults, 18+ statement, unlisted link. Browser counters only: steps, completion, error codes per problem. Failed input exports as token shape (`N V + ?`), never raw text. Tester presses "Copy results" and sends it; owner transcribes aggregates and deletes the message. No results endpoint.

**Top risks**
1. Crash output leaking expressions into platform logs.
2. A false privacy claim.
3. The 5 GB allowance: about 10,000 loads of a 500 KB page suspends the site for the month.

**Cut:** analytics, session IDs, SymChess's `*` origin and 64 KB messages.

**Will not work in the brief**
- "Logged as a rule-coverage test case": at runtime this stores expressions. Restrict to CI.
- "Real observation" for mal-rules: only voluntary adult exports can supply it.
- "No stored student data" conflicts with M6.
- Render discourages free services for production; waking takes about a minute. Report warm and cold p95.

**Verified 2026-10-31:** Render facts above; Fly: no free tier, 2-hour trial; Koyeb: free instance, card with $29 hold; Oracle Always Free shapes.
**Unverified:** Render IP retention, DPA terms, Cloudflare plaintext access, Oracle card (403). No-card Render signup: secondary source. Limit values are untested judgement.
