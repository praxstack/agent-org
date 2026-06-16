# Contributing to agent-org

Thanks for your interest. agent-org is intentionally small and dependency-light — the bar for new code is high, and the design principles below are non-negotiable because they're what make the tool *honest* rather than just plausible.

## Design principles (please don't violate these)

1. **The gate runs reality, not opinion.** Verification must be something a script executes (a build, tests, a behavioral check) — never an LLM merely *asserting* it passed. If you add a verification path, it must be machine-checkable.
2. **Tree, not mesh.** The driver orchestrates; agents do not talk directly to each other. No cycles.
3. **Single-threaded writes.** Only the driver commits, only after a PASS.
4. **Contracts, not histories.** Agents hand off structured verdicts, not whole transcripts.
5. **Hard exit.** Every loop needs a circuit breaker. No unbounded retries.
6. **No silent degradation.** If a capability is missing, fail loudly or skip explicitly — never quietly produce a worse result.
7. **Portable.** No hardcoded personal paths. Scripts self-locate; machine specifics go in env vars with sane defaults.

## Before you open a PR

- **Keep it bash-portable.** Target `bash 3.2` (macOS default). Run `bash -n` on every script. Watch for `set -u` traps (e.g. empty-array expansion needs `"${arr[@]+"${arr[@]}"}"`).
- **No secrets, no personal data.** Run a sweep before committing:
  ```bash
  grep -rIn -iE 'api[_-]?key|secret|token|bearer|/Users/|/home/[a-z]' . --exclude-dir=.git
  ```
- **Test it for real.** Run `review-loop.sh` against a throwaway git repo with a trivial task and confirm the full cycle (coder → gate → council → commit) works end to end. Describe what you observed in the PR — "tests pass" is not the same as "I ran it and watched it work."
- **Document any new env var** in the README table.

## Reporting bugs

Open an issue with: the exact command you ran, the `runs/run-*/` artifacts if relevant (redact anything private), what you expected, and what actually happened. A failing reproduction on a public repo or a minimal sandbox is ideal.

## Scope

This repo is the **minimal proven leaf unit**. Large additions (durable-execution backends, a full agent-org/CEO orchestrator, a web UI) are probably better as a separate project that *uses* this loop, or as an `examples/` contribution. Open an issue to discuss before building something big.

## License

By contributing you agree your contributions are licensed under the MIT License.
