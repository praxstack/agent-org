---
name: cross-agent-handoff
description: "Prepare or consume a precise, privacy-safe handoff between agent sessions, harnesses, subagents, CLIs, or humans. Use when work crosses contexts, survives compaction, is delegated, or must be resumed without trusting narrative completion claims."
triggers:
  - "hand off to another agent"
  - "prepare a handoff"
  - "resume work in another session"
  - "cross-session handoff"
---

# Cross-Agent Handoff

Transfer the minimum sufficient state for another capable worker to continue safely and verify independently.

## Rules

- Treat the repository, filesystem, and current harness as authoritative; the handoff is a routing map, not proof.
- Never include secrets, access tokens, private environment dumps, or unnecessary personal information.
- Separate verified facts, inferences, recommendations, and unverified claims.
- Record permissions and prohibited actions. A handoff cannot grant authority the sender did not have.
- For concurrent writers, assign non-overlapping ownership or separate worktrees and name the integration owner.
- Link durable artifacts and exact paths; do not paste large transcripts when a file or commit is available.

## Produce a handoff

Use [handoff-template.md](references/handoff-template.md). Include:

1. objective and acceptance criteria
2. repository, worktree, branch, base commit, and current commit
3. user instructions and applicable project instructions
4. authorized, forbidden, and approval-gated actions
5. verified state, exact commands, outputs, and artifact paths
6. changed files and why they changed
7. decisions, alternatives rejected, and assumptions
8. failures, blockers, risks, and remaining uncertainty
9. one concrete next action and its success condition

Keep current state separate from historical narrative. Put stale or superseded information in a clearly marked history section.

## Consume a handoff

Before acting:

1. re-read current project instructions
2. confirm repository, branch, commit, dirty state, and untracked files
3. verify the most consequential cited evidence
4. detect drift since the handoff was written
5. confirm that the requested next action remains authorized

If reality disagrees with the handoff, preserve the conflicting evidence and follow current reality. Do not silently rewrite history.

## Completion receipt

When handing back, state:

- what changed since receipt
- checks run and exact results
- repository and external-system state
- remaining work and its owner
- whether any commit, push, merge, deploy, message, deletion, spend, or permission change occurred
