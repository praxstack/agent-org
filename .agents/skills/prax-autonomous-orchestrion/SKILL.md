---
name: autonomous-orchestrion
aliases:
  - autonomous
  - pure-autonomous
  - autonomous-work
  - autonomous-agent
  - orchestrion-autonomy
  - pure-work-protocol
  - agentic-orchestrion
  - council-swarm
  - autonomous-swarm
  - subagent-orchestration
description: >
  Host-neutral autonomous software work protocol. Use this when a human gives any non-trivial task and expects the agent to own discovery, planning, council review, execution, verification, documentation, and handoff without constant permission requests. Coordinates Superpowers, gstack, Matt Pocock skills, llm-council-plus, MCPs, local tools, and fallback reasoning across Claude Code, Codex, OpenCode, Hermes, OpenClaw, Cline, KiloCode, Antigravity-style IDE agents, Cursor, Windsurf, Aider, Augment, Gemini CLI, Copilot-like agents, or unknown hosts.
---

# Autonomous Orchestrion: Council-Swarm Pure Work Protocol

A host-neutral autonomous skill for agents that must turn vague human intent into verified work using skill routing, llm-council-plus, specialist subagents, red-team review, evidence gates, and reversible execution.

This skill merges two protocols:

1. **Orchestrion**: universal host-neutral skill discovery, loading, routing, and fallback semantics.
2. **Autonomous Agent**: phase lifecycle, ThinkBeforeAct, error carry-forward, keep-or-revert, verification loops, council escalation, safety rails, observability, and self-improvement sandbox.

It assumes the human may be **temporarily unavailable for routine clarifications**, but it must **not** frame this as the human sleeping, going away, or being absent for a specific reason. It does **not** assume the agent is Claude, Codex, OpenCode, Hermes, OpenClaw, Cline, KiloCode, Antigravity, or any other specific host. It does **not** impose arbitrary time, token, or API-cost limits unless the human or platform explicitly gives a cap.

## 0. Activation

Use this skill for any non-trivial task, including:

- Build, modify, debug, refactor, test, review, document, ship, or deploy software.
- Continue work from vague, messy, incomplete, contradictory, or emotional human instructions.
- Convert a human request into a TODO plan, implementation, verification evidence, and handoff.
- Coordinate skills from Superpowers, gstack, Matt Pocock skills, llm-council-plus, or other installed skill packs.
- Run autonomous local work while preserving safety and reversibility.
- Use council review heavily when decisions are risky or uncertain.
- Work in an unfamiliar repository or unknown agent host.

If the task is trivial, such as a one-line grammar edit, do not over-orchestrate. Apply the smallest safe path.

## 1. Non-assumptions

The agent must not assume any of the following:

- The human is asleep, away, or absent for a specific reason.
- The human wants reckless action.
- The agent is running in a specific host.
- A slash command exists merely because a skill name is known.
- A skill ran successfully unless its output or host confirmation exists.
- A missing tool excuses low quality.
- A PR, deployment, or merge is always the required final deliverable.
- Time, token use, or paid API use is a reason to lower quality unless an explicit cap exists.

When the human says to work autonomously, interpret it as:

> Treat the human as potentially unavailable for routine back-and-forth. Proceed through reversible, local, evidence-backed work without asking for permission at every step. Pause only for true blockers, unsafe irreversible actions, missing external credentials, legal/compliance ambiguity, or equally valid product directions that evidence cannot break.

## 2. Prime directive

The agent owns the task from intake to verified handoff.

Default loop:

```text
INTAKE
-> HOST DISCOVERY
-> SKILL DISCOVERY
-> AMBIGUITY REDUCTION
-> PLAN
-> LLM COUNCIL
-> TODO DAG
-> ISOLATED EXECUTION
-> TDD / DEBUG / IMPLEMENT
-> REVIEW
-> QA / SECURITY / PERFORMANCE
-> VERIFICATION
-> DOCS / MEMORY
-> SHIP / HANDOFF / RETRO
```

Do not jump straight into editing code unless the task is genuinely tiny and unambiguous.

## 3. Constitutional rules

### 3.1 ThinkBeforeAct

Before any meaningful interaction with code, files, tools, web, MCPs, tests, subagents, install commands, or deployment surfaces, produce a brief internal or visible rationale:

```markdown
## Action Rationale
- Intent:
- Why this should work:
- What would falsify it:
- Safety/reversibility:
```

Keep it concise. Do not write theatre. Do not skip this because a task feels easy.

### 3.2 ErrorHandlingCarriesForward

Every failure becomes structured side information:

```yaml
attempted: ""
expected: ""
actual: ""
error_excerpt: ""
what_this_rules_out: ""
next_hypothesis: ""
```

Never treat errors as noise. Failed tests, failed tool calls, failed council votes, failed installs, and failed assumptions must shape the next attempt.

### 3.3 LoopUntilVerified

A phase is not complete until its acceptance criteria pass or a legitimate stop condition fires.

Forbidden phrases without proof:

```text
Done.
Should work.
Looks good.
Probably fixed.
```

Replace them with verification evidence.

### 3.4 KeepOrRevert

For optimization, refactor, performance, prompt, skill, or architecture experiments:

```text
baseline -> hypothesis -> change -> measure -> keep if strictly better -> otherwise revert and log side_info
```

Do not accumulate uncertain improvements.

### 3.5 Council before ego

Use `llm-council-plus` aggressively for non-trivial decisions. A single model's confidence is not a plan.

Council is mandatory for:

- Architecture choices.
- Data model changes.
- Security-sensitive changes.
- Auth, permissions, payments, secrets, PII, file uploads, infra, or deployment changes.
- Large refactors.
- Irreversible migrations.
- Debugging where multiple plausible root causes remain.
- Product direction tradeoffs.
- UI direction with meaningful product impact.
- Performance tradeoffs.
- Any plan that will take many files or many commits.
- Any task where two skills disagree.
- Final diff review for high-impact changes.

Council is optional for trivial edits, formatting, simple docs, and tiny local fixes.

## 4. Host-neutral adapter

The agent must use these abstract operations. Implement them using whatever the current host supports.

### 4.1 DISCOVER_HOST()

Determine the current host without assuming it.

Check, when available:

```text
- Executable name and parent process.
- Environment variables.
- Current working directory conventions.
- Agent memory/rules files.
- Skill directories.
- MCP/tool registry.
- Slash-command registry.
- Project files such as AGENTS.md, CLAUDE.md, GEMINI.md, .cursorrules, .windsurfrules, .clinerules, .kilocode, .opencode, codex config, hermes config, openclaw config.
```

Return:

```yaml
host_name: unknown | claude-code | codex | opencode | hermes | openclaw | cline | kilocode | antigravity | cursor | windsurf | aider | augment | gemini-cli | copilot-like | other
interactive: true | false | unknown
supports_slash_commands: true | false | unknown
supports_skills: true | false | unknown
supports_mcp: true | false | unknown
supports_subagents: true | false | unknown
supports_browser: true | false | unknown
supports_shell: true | false | unknown
supports_git: true | false | unknown
notes: []
```

### 4.2 DISCOVER_CAPABILITIES()

List what the host can actually do.

```yaml
capabilities:
  file_read: true|false|unknown
  file_write: true|false|unknown
  shell: true|false|unknown
  git: true|false|unknown
  web_search: true|false|unknown
  browser: true|false|unknown
  tests: true|false|unknown
  mcp: true|false|unknown
  subagents: true|false|unknown
  installed_skills: []
  available_tools: []
  missing_critical_tools: []
```

If a capability is missing, route around it or report the narrow gap. Do not invent capability.

### 4.3 DISCOVER_SKILLS()

Search for skills in host-specific, project, and common user paths.

Common paths to inspect when the environment permits:

```bash
./.claude/skills
./.codex/skills
./.opencode/skills
./.cursor/skills
./.config/skills
~/.claude/skills
~/.codex/skills
~/.config/opencode/skills
~/.cursor/skills
~/.config/Cursor/skills
~/.config/windsurf/skills
~/.cline/skills
~/.kilocode/skills
~/.gemini/skills
~/.hermes/skills
~/.openclaw/skills
~/.pi/agent/skills
~/.agents/skills
~/gstack
~/superpowers
```

Also inspect host plugin registries, slash command lists, MCP tool names, and project docs.

Output:

```yaml
skills_found:
  - name:
    source:
    path_or_command:
    load_method:
    verified: true|false
skills_missing:
  - name:
    importance: critical|high|normal|optional
    fallback_available: true|false
```

### 4.4 LOAD_SKILL(name)

Use the current host's native loading mechanism if available.

Examples, not assumptions:

```text
- Slash command invocation.
- Skill/plugin command.
- Reading SKILL.md and applying it as procedural guidance.
- MCP tool call.
- Built-in host action.
- Project-specific command.
```

Rules:

- Do not claim `LOAD_SKILL(name)` succeeded unless the skill is actually available or its SKILL.md was read.
- If unavailable, use `FALLBACK_SKILL(name)` and log that fallback was used.
- If the missing skill is critical and no fallback exists, trigger a blocker.

### 4.5 INSTALL_SKILL(name)

Install only if the host, project policy, and user permission context allow installation. Installation must be reversible and validated.

Discovery order:

```text
1. Native host marketplace or plugin mechanism.
2. Known repo/skill source from project docs.
3. npx or package-based installer if the environment supports it.
4. Direct GitHub clone only from a trusted source.
5. Direct SKILL.md copy only if source is trusted and validated.
```

Validation before activation:

```text
- SKILL.md exists.
- Frontmatter parses when present.
- Description is non-empty.
- No obvious embedded secrets.
- Scripts are inspected before execution.
- Installation path is scoped to skill/plugin directories, not arbitrary system paths.
```

If installation fails, continue using the best known methodology and log the gap.

## 5. Core skill families

### 5.1 Superpowers: discipline and workflow gates

Prefer loading these first when applicable:

```text
using-superpowers
brainstorming
systematic-debugging
writing-plans
executing-plans
test-driven-development
using-git-worktrees
subagent-driven-development
dispatching-parallel-agents
verification-before-completion
requesting-code-review
receiving-code-review
finishing-a-development-branch
writing-skills
```

Use Superpowers for process discipline before implementation.

### 5.2 Matt Pocock skills: engineering clarity

Use when the task needs alignment, PRDs, issues, TDD, diagnosis, or architecture hygiene:

```text
setup-matt-pocock-skills
grill-me
grill-with-docs
to-prd
to-issues
tdd
diagnose
triage
zoom-out
improve-codebase-architecture
prototype
handoff
caveman
write-a-skill
git-guardrails-claude-code
setup-pre-commit
migrate-to-shoehorn
scaffold-exercises
```

### 5.3 gstack: specialist product factory

Use for product, design, engineering review, QA, security, docs, release, and browser workflows:

```text
office-hours
autoplan
plan-ceo-review
plan-eng-review
plan-design-review
plan-devex-review
review
investigate
qa
qa-only
ship
land-and-deploy
canary
benchmark
cso
retro
design-consultation
design-shotgun
design-html
design-review
devex-review
document-generate
document-release
careful
freeze
guard
unfreeze
learn
setup-gbrain
sync-gbrain
browse
open-gstack-browser
setup-browser-cookies
```

### 5.4 LLM Council Plus: deliberation court

Treat `llm-council-plus` as a phase gate and escalation path, not decoration.

Invoke it with:

```markdown
# Council Request

## Task

## Current context
- Repo / workspace:
- Host and capabilities:
- User goal:
- Constraints:
- Relevant files:
- Known failures:

## Options
1. Option A
2. Option B
3. Option C

## Ask
Evaluate correctness, simplicity, maintainability, security, testability, user impact, reversibility, implementation risk, and hidden failure modes.

## Required output
- Recommended option
- Rejected alternatives
- Required tests
- Stop/go decision
- Risks to track during execution
```

Council handling:

```text
- Read all panel outputs, not only the chair synthesis.
- Extract agreements and disagreements.
- Address findings supported by evidence or multiple panelists.
- Do not blindly obey council.
- Record unresolved disagreement in the session log or ADR.
```

Council round types:

```text
architecture-council: options, tradeoffs, hidden coupling
risk-council: safety, security, privacy, compliance, misuse
debug-council: competing root causes and experiment design
eval-council: rubrics, judges, gold sets, Goodhart risk
diff-council: final patch review and release risk
postmortem-council: repeated failures and systemic fixes
```

Minimum council packet for high-impact work:

```markdown
## Evidence
- Code paths:
- Logs/tests:
- Prior decisions:
- Research sources:

## Options
- A:
- B:
- C:
- Do nothing:

## Constraints
- Safety:
- Reversibility:
- Time/resource:
- User preference:

## Required judgement
- Which option should win?
- What would make it wrong?
- What tests/evidence are required before action?
- What should be deferred?
```

### 5.5 Optional and situational skills

Discover before use. Treat these as optional aliases unless actually installed:

```text
smoke-test
root-cause-tracing
premortem
devils-advocate
code-review
code-review-expert
dhh-code-reviewer
chaos-engineer
secrets-management
finding-duplicate-functions
skill-creator
skill-auditor
skill-validator
compound-learnings
self-improving-agent
autoresearch-agent
learning-keeper
prompt-optimize
frontend-design
ui-ux-pro-max-skill
docx
pptx
xlsx
pdf
obsidian-vault
obsidian-cli
session-checkpoint
resume-session
firecrawl
valyu
deep-research
external-llm-consulting
```

## 5.6 Advanced agentic skill families

Discover these skill families before use. Names vary by host. Treat them as capabilities, not guaranteed commands.

### Deep research and evidence acquisition

Use when the task needs current, niche, external, or multi-source evidence.

```text
agentic-dive-deep
agentic-deep-research
deep-research
external-llm-consulting
web-research
firecrawl
valyu
context7
sourcegraph
repo-map
paper-search
github-research
```

Rules:

- Research agents must produce citations, source quality notes, and uncertainty.
- Research agents must distinguish primary sources, docs, code, papers, blogs, and forum claims.
- For code tasks, external research does not replace repo inspection.
- For medical, legal, financial, security, or mental-health-adjacent domains, research must include safety and policy risks.

### Adversarial and red-team skills

Use before trusting plans, evals, prompts, agents, safety gates, and high-impact changes.

```text
premortem
devils-advocate
red-team
chaos-engineer
threat-model
security-review
privacy-review
safety-review
prompt-injection-review
judge-reliability-review
eval-red-team
```

Rules:

- Red-team agents should use fresh context, not the main agent's assumptions.
- They must identify how the plan can fail, be gamed, or cause harm.
- Their output must include severity, likelihood, detection, mitigation, and rollback.

### Evaluation and judge skills

Use when building or changing evals, judges, rubrics, quality gates, or self-improvement loops.

```text
eval-design
judge-calibration
rubric-builder
golden-set-builder
metamorphic-testing
adversarial-probe-generator
llm-as-judge-review
champion-challenger
pareto-promotion
regression-harness
```

Rules:

- No single judge may become authoritative without calibration.
- Prefer pairwise evaluation with position swaps for subjective quality.
- Separate hard safety floors from quality scores.
- Log judge version, rubric version, probe version, input source, and candidate version.
- Treat judge disagreement as signal, not noise.

### Self-improvement and optimization skills

Use only after measurement and safety floors exist.

```text
self-improving-agent
autoresearch-agent
pi-autoresearch
karpathy-autoresearch
gepa
reflective-prompt-evolution
gear
population-search
dspy
miprov2
opro
ape
textgrad
prompt-optimize
policy-optimizer
retrieval-tuning
```

Rules:

- Optimizers may generate candidates, not silently promote them.
- Candidates must run through champion-challenger, safety floors, council review, and rollback gates.
- Scalar-only optimization is forbidden for multi-axis safety domains.
- Use Pareto/non-dominated promotion when safety and quality trade off.
- Every candidate needs diff, rationale, expected behavior change, eval results, failure cases, and rollback.

### Project memory and continuity skills

Use when the work spans sessions, long tasks, product strategy, or user-specific project context.

```text
learn
sync-gbrain
setup-gbrain
byterover
obsidian-vault
obsidian-cli
session-checkpoint
resume-session
handoff
compound-learnings
learning-keeper
adr-writer
decision-log
```

Rules:

- Memory is evidence only when it points to artifacts or the user explicitly treats it as authoritative.
- Past decisions are inputs, not law.
- If memory conflicts with code, logs, tests, or current docs, current evidence wins.
- Important reversals must be explicitly recanted in ADRs or session logs.

## 5.7 Skill priority ladder

When several skills could apply, use this order:

```text
1. Safety / policy / irreversible-action guardrails
2. Host and capability discovery
3. Superpowers dispatcher / process skills
4. Ambiguity reduction and product framing
5. Repo/codebase inspection
6. External research if freshness or breadth matters
7. Architecture/design planning
8. llm-council-plus architecture review
9. TODO DAG / issue slicing
10. Isolated execution and TDD
11. Specialist subagents
12. Code review / red-team / security
13. QA / browser / performance
14. Verification-before-completion
15. Docs / memory / handoff / ship
```

Do not use implementation skills before process skills unless the task is tiny and unambiguous.

## 5.8 Council-swarm policy

For non-trivial work, combine `llm-council-plus` with specialist subagents.

Default council-swarm pattern:

```text
Lead agent
-> Research subagent(s)
-> Codebase mapper subagent
-> Architecture critic subagent
-> Security/privacy red-team subagent
-> Test/eval designer subagent
-> Implementation agent(s)
-> Reviewer subagent(s)
-> llm-council-plus synthesis
-> Lead agent final decision
```

Rules:

- Subagents gather evidence and produce structured outputs.
- Council judges tradeoffs, architecture, risks, and unresolved disagreements.
- The lead agent remains accountable. Do not outsource responsibility to the council or subagents.
- For high-impact work, run council at least twice:
  - before implementation, on the plan
  - after implementation, on the diff/evidence
- If council and evidence disagree, investigate. Do not pick the answer that merely sounds smartest.

## 6. Ambiguity blockers

Pause and ask the human only for these:

```text
- Irreversible destructive action with no tested rollback.
- Production data writes, payments, public posts, sent emails, force-push to protected branches, secret rotation, or permission/IAM changes.
- Missing credentials or OAuth that only the human can provide.
- Security boundary ambiguity.
- Legal/compliance/license/PII/export-control ambiguity.
- Two equally valid product directions where evidence and council cannot break the tie.
- A task requires a specific unavailable skill/tool and no reasonable fallback exists.
- Self-modification would escape the sandbox or weaken safety rules.
```

Not blockers:

```text
- Requirements are a little vague. Infer, document assumptions, and proceed reversibly.
- Tests are failing. Debug.
- A skill is missing but a procedural fallback exists. Use fallback and log it.
- The work may take time. Continue while the current session and tools allow.
- The work may use paid APIs. If no explicit cap exists, prefer quality, track usage, and use council where valuable.
```

## 7. Universal phase contract

Every phase follows this shape:

```text
1. self_inspect: read task, repo, prior notes, current state.
2. self_update: declare binary acceptance criteria.
3. interact: act after ThinkBeforeAct rationale.
4. self_inspect: score pass/fail.
5. continue_improve: retry failures with side_info until pass or stop condition.
```

Do not weaken criteria mid-loop just to pass. If a criterion is wrong, revise it with rationale, restart the phase, and log the change.

## 8. Lifecycle

### Phase 0: Bootstrap

Outcome: agent knows host, tools, repo, rules, skills, and limits.

TODO:

```markdown
- [ ] Capture human task verbatim.
- [ ] Run DISCOVER_HOST().
- [ ] Run DISCOVER_CAPABILITIES().
- [ ] Read repo guidance files if present: AGENTS.md, CLAUDE.md, GEMINI.md, README, CONTRIBUTING, docs, rules.
- [ ] Capture git branch, SHA, dirty files if git exists.
- [ ] Run DISCOVER_SKILLS().
- [ ] Load `using-superpowers` if available.
- [ ] Load or fallback to `autonomous-orchestrion` rules.
- [ ] Identify required skill families.
- [ ] Install missing skills only when safe and allowed.
- [ ] Open session log if writable.
```

### Phase 1: Recon

Outcome: territory understood before plan.

TODO:

```markdown
- [ ] Map entry points, modules, tests, public APIs, data flows.
- [ ] Search for related existing code and duplicate functionality.
- [ ] Check dependency versions using current docs/tools when available.
- [ ] Identify unknowns, risks, and relevant files.
- [ ] If codebase is unfamiliar, load `zoom-out`.
- [ ] If product intent is unclear, load `brainstorming`, `grill-with-docs`, or `office-hours`.
- [ ] Produce Recon Note.
```

### Phase 2: Plan

Outcome: executable plan, not wish list.

TODO:

```markdown
- [ ] Load planning skills: `brainstorming`, `writing-plans`, `grill-with-docs`, `to-prd`, `to-issues` as needed.
- [ ] Load gstack planning roles: `/autoplan`, `/plan-ceo-review`, `/plan-eng-review`, `/plan-design-review`, `/plan-devex-review` as applicable.
- [ ] Define SPEC: requirements, non-goals, assumptions, risks.
- [ ] Define BLUEPRINT: steps, files, tests, edge cases, rollback.
- [ ] Define TODO DAG with dependencies and DoD.
- [ ] Run premortem or devils-advocate if available.
- [ ] Spawn `repo-cartographer`, `research-scout`, `architecture-critic`, and `red-team` subagents when the plan is large or risky.
- [ ] Send plan, subagent findings, risks, and unresolved options to `llm-council-plus` for non-trivial work.
- [ ] Revise plan based on council findings.
- [ ] Record rejected alternatives and why.
```

### Phase 3: Isolate

Outcome: safe workspace.

TODO:

```markdown
- [ ] Use `using-git-worktrees` if available and appropriate.
- [ ] Create branch/worktree when shell and git are available.
- [ ] Ensure guardrails for dangerous git operations.
- [ ] Snapshot baseline tests or current failures.
- [ ] If file writes are unavailable, switch to patch/handoff mode.
```

### Phase 4: Execute

Outcome: work built in small verified slices.

TODO:

```markdown
- [ ] Use `test-driven-development` or `tdd` for code changes.
- [ ] For each leaf task: write failing test first where practical.
- [ ] Implement minimal change.
- [ ] Run focused tests.
- [ ] Refactor only while tests pass.
- [ ] Commit or checkpoint each clean slice when possible.
- [ ] If blocked by unclear failure, switch to `systematic-debugging`, `diagnose`, and `/investigate`.
- [ ] If repeated failure occurs, call `llm-council-plus` with failure trace.
```

### Phase 5: Review

Outcome: defects found before the human finds them.

TODO:

```markdown
- [ ] Run `/review` if available.
- [ ] Run `requesting-code-review` if available.
- [ ] Run `receiving-code-review` for returned feedback.
- [ ] Run `code-review` / `code-review-expert` / specialist reviewers if available.
- [ ] Run `llm-council-plus` final-diff review for non-trivial changes.
- [ ] Address major findings.
- [ ] Defer minor findings only with rationale.
```

### Phase 6: QA, security, performance

Outcome: changed surface verified from user and system perspectives.

TODO:

```markdown
- [ ] Run `/qa-only` if report-only mode.
- [ ] Run `/qa` if fixes are allowed.
- [ ] Run browser/UI checks if browser tools exist.
- [ ] Run `/design-review` if UI changed.
- [ ] Run `/devex-review` if developer-facing experience changed.
- [ ] Run `/cso` for security-sensitive work.
- [ ] Run `/benchmark` for performance-sensitive work.
- [ ] Add regression tests for verified bugs.
```

### Phase 7: Verify

Outcome: proof replaces confidence.

TODO:

```markdown
- [ ] Run `verification-before-completion` if available.
- [ ] Run full relevant test suite.
- [ ] Run typecheck, lint, format, build, and smoke tests where available.
- [ ] Compare behavior to acceptance criteria.
- [ ] Confirm no unrelated changes.
- [ ] Explain every anomaly.
- [ ] Do not report done until checks are green or explicitly deferred.
```

### Phase 8: Docs, memory, handoff

Outcome: future humans and agents inherit the result.

TODO:

```markdown
- [ ] Run `/document-release` for code changes that affect docs.
- [ ] Run `/document-generate` if missing docs are discovered.
- [ ] Update README, ADRs, CONTEXT.md, AGENTS.md, or equivalent if conventions changed.
- [ ] Run `learn`, `sync-gbrain`, `obsidian-vault`, or host memory tools if available.
- [ ] Run `handoff` if another session or agent may continue.
- [ ] Record missing skills/tools in `.learnings/missing-skills.md` if writable.
```

### Phase 9: Ship or final handoff

Outcome: deliverable reaches the appropriate endpoint.

TODO:

```markdown
- [ ] If PR workflow exists and is requested/appropriate, run `/ship` or `finishing-a-development-branch`.
- [ ] If deploy workflow exists and is approved, run `/land-and-deploy`.
- [ ] After deploy, run `/canary`.
- [ ] If no PR/deploy is required, produce a final patch, summary, and verification evidence.
- [ ] Run `/retro` for non-trivial work.
```

## 9. Task router

### 9.1 New feature

```text
using-superpowers
-> brainstorming
-> grill-with-docs
-> office-hours
-> autoplan
-> plan-ceo-review
-> plan-eng-review
-> plan-design-review if UI exists
-> plan-devex-review if developer-facing
-> llm-council-plus
-> to-prd
-> to-issues
-> using-git-worktrees
-> writing-plans
-> tdd/test-driven-development
-> review
-> qa
-> verification-before-completion
-> ship/handoff
```

### 9.2 Bug or regression

```text
using-superpowers
-> systematic-debugging
-> diagnose
-> investigate
-> zoom-out if architecture unclear
-> llm-council-plus if root cause remains disputed
-> tdd/test-driven-development
-> review
-> qa
-> verification-before-completion
```

### 9.3 Architecture/refactor

```text
using-superpowers
-> zoom-out
-> improve-codebase-architecture
-> plan-eng-review
-> llm-council-plus
-> to-prd/to-issues if needed
-> using-git-worktrees
-> tdd/test-driven-development
-> review
-> verification-before-completion
```

### 9.4 UI/UX/frontend

```text
using-superpowers
-> brainstorming
-> grill-with-docs
-> plan-design-review
-> design-consultation if design system unclear
-> design-shotgun if options useful
-> design-html if converting mockup to implementation
-> frontend-design if available
-> design-review
-> qa
-> benchmark if performance-sensitive
```

### 9.5 API, SDK, CLI, docs, onboarding

```text
using-superpowers
-> grill-with-docs
-> plan-devex-review
-> devex-review
-> to-prd
-> to-issues
-> tdd
-> document-generate/document-release
-> qa if browser flow exists
```

### 9.6 Security-sensitive

```text
using-superpowers
-> careful/guard/git-guardrails
-> cso
-> llm-council-plus
-> review
-> verification-before-completion
```

### 9.7 Docs-only

```text
using-superpowers
-> grill-with-docs
-> document-generate if missing docs
-> document-release if docs drifted from code
-> devex-review if onboarding docs
-> verification-before-completion
```

## 10. Subagents and parallelism

Use subagents whenever the host supports them and the work naturally decomposes. Subagents are not decoration. They are for reducing blind spots, parallelizing independent work, and creating fresh-context review pressure.

### 10.1 When to spawn subagents

Spawn subagents for:

```text
- Codebase mapping in unfamiliar repos.
- External research.
- Architecture option comparison.
- Security/privacy review.
- Eval/rubric design.
- Red-team/adversarial probing.
- Test planning.
- Independent root-cause hypotheses.
- Large refactors with separable modules.
- Documentation audit.
- Fresh-context review of a plan or diff.
```

Do not spawn subagents for:

```text
- Tiny one-file edits.
- Work that requires shared mutable state without isolation.
- Tasks where the host cannot safely merge outputs.
- Sensitive data unless the subagent is allowed to see it.
```

### 10.2 Spawn contract

Every subagent must receive a structured contract:

```yaml
subject: "specific slug"
role: "researcher | mapper | implementer | reviewer | red-team | eval-designer | qa | security | docs | performance"
mission: ""
context_allowed:
  - ""
context_forbidden:
  - ""
inputs:
  - path_or_source: ""
    why_needed: ""
tools_allowed:
  - ""
tools_forbidden:
  - ""
output_schema:
  findings: []
  evidence: []
  risks: []
  recommendations: []
  open_questions: []
definition_of_done:
  - ""
stop_condition: ""
failure_handoff: ""
```

### 10.3 Standard subagent roles

Use these roles by default:

| Role | Use when | Required output |
|---|---|---|
| `repo-cartographer` | unfamiliar codebase | module map, entry points, ownership, risk zones |
| `research-scout` | external/current knowledge needed | cited research brief, source quality ranking |
| `architecture-critic` | design or ADR choices | options matrix, hidden coupling, failure modes |
| `red-team` | safety/security/product-risk | attack paths, severity, mitigations |
| `test-strategist` | implementation/eval design | test matrix, fixtures, regression cases |
| `judge-calibrator` | LLM-as-judge or evals | bias risks, calibration protocol, gold set |
| `implementer` | isolated code slice | patch + tests + notes |
| `reviewer` | fresh-context code review | blocking/non-blocking findings with evidence |
| `qa-browser` | UI/product behavior | flows, screenshots/logs, bugs, reproduction |
| `docs-archivist` | docs/ADRs/handoff | docs delta, ADR updates, handoff notes |

### 10.4 Parallelism rules

```text
- Parallelize independent read/research tasks freely when supported.
- For filesystem writes, use isolated worktrees or clearly separated files.
- Do not allow two agents to edit the same file concurrently unless a merge strategy exists.
- Merge in dependency order, not completion order.
- Each subagent result must be checked by the lead agent before becoming truth.
- Fresh-context reviewers should not receive the lead agent's desired answer.
```

### 10.5 Subagent escalation

Escalate to `llm-council-plus` when:

```text
- Subagents disagree on architecture, root cause, or safety.
- A reviewer finds high-severity defects.
- A red-team finding threatens the plan.
- Research contradicts repo assumptions.
- The lead agent wants to override a subagent with evidence weaker than the subagent's evidence.
```

### 10.6 No responsibility laundering

The lead agent may say:

```text
"Subagent X found Y, supported by evidence Z."
```

The lead agent must not say:

```text
"The subagent said it, so it is true."
```

Lead agent owns synthesis, verification, and final handoff.

## 11. Retry and fallback matrix

| Error class | Action |
|---|---|
| Network or rate limit | Retry with backoff if host supports it. Preserve request/response evidence. |
| Tool flake | Retry once same input, once re-derived. |
| Bad input | Do not blind retry. Re-derive and log. |
| Bad model output | Tightened retry with quoted state, then stronger model or council. |
| Auth/permission | Stop and ask for credential or authorization. |
| Test failure | Treat as signal. Debug. Never weaken test to pass. |
| Subagent timeout | Kill or narrow scope. Capture partial. |
| Skill install failed | Try next safe source. If all fail, use fallback or blocker. |
| MCP auth required | Ask for auth when only human can complete it. |
| Repeated failure | Escalate to `llm-council-plus` with full trace. |

Fallback tiers:

```text
1. Reframe: same goal, narrower reversible scope.
2. Reroute: different skill, model, tool, or MCP.
3. Council: llm-council-plus with failure trace.
4. Decompose: split task and localize signal loss.
5. Acknowledged skip: document gap and continue only if safe.
6. Abort safely: rollback, checkpoint, postmortem.
```

No tier above 4 without first using council for non-trivial work.

## 12. Safety rails

### Reversible by default

Reversible examples:

```text
- Git-tracked edits.
- Local tests.
- Local builds.
- Local snapshots.
- Draft docs.
- Draft PR description.
```

Irreversible or externally visible examples:

```text
- Production DB writes.
- Payments.
- Sent emails or public posts.
- Force-push to protected branches.
- Secret rotation.
- Permission/IAM grants.
- Deleting data outside the repo.
- Merging sandbox self-modification into production skill paths.
```

Irreversible actions require explicit human allowance, dry run when possible, tested rollback, and logged intent.

### Secrets

```text
- Never echo secrets.
- Never commit .env.
- If a secret appears, stop the affected path and use secrets-management or a safe manual rotation plan.
```

### Resource posture

Do not self-impose arbitrary quality-reducing caps.

If the human has not set a budget:

```text
- Continue while the active session, platform, credentials, and tools allow.
- Prefer quality and verification over speed.
- Track expensive operations in the session log.
- Use council liberally for material decisions.
```

If the human or organization has set a cap, obey it.

## 13. Observability

If writable storage exists, create a session log:

```text
.agent/sessions/<ISO>-<slug>.md
or gbrain/sessions/<ISO>-<slug>.md
or .learnings/sessions/<ISO>-<slug>.md
or host-native memory/log path
```

Log:

```text
- Task verbatim.
- Host and capabilities.
- Skills discovered, loaded, missing, installed, or fallback-used.
- Phase criteria and pass/fail status.
- Council prompts and summaries.
- Tests and verification commands.
- Failures and side_info.
- Decisions and rationale.
- Final result and open follow-ups.
```

Telemetry labels, when useful:

```text
PHASE_ENTER
PHASE_EXIT
ITERATION
SPAWN
RETURN
RETRY
FALLBACK
COUNCIL
CHECKPOINT
GATE
KEEP_OR_REVERT
SKILL_DISCOVERED
SKILL_LOADED
SKILL_MISSING
SKILL_INSTALLED
MCP_REGISTERED
```

## 14. Self-improvement sandbox

Self-improvement is allowed only when explicitly requested or clearly in a dedicated self-improvement task.

Allowed in sandbox:

```text
- Draft improvements to skills.
- Draft routing evals.
- Draft agent rules.
- Draft missing skill proposals.
- Update session learnings.
```

Forbidden without explicit human approval:

```text
- Modifying production skill paths directly.
- Weakening constitutional rules.
- Removing verification, council, rollback, sandbox, or safety gates.
- Auto-merging self-modification proposals.
```

Self-mod gate ladder:

```text
skill changes: ratchet + council majority + human merge
agent rules: ratchet + council unanimous + human merge
this skill: ratchet + council unanimous + replay against prior tasks + human merge
```

No self-disabling: the agent may not modify paths that would weaken this section or the constitutional rules.

## 15. Human feedback ritual

At final handoff, identify:

```yaml
uncertain_decisions:
  - did: ""
    alternative: ""
    rationale: ""
    confidence: low|medium|high
surprises:
  - observation: ""
    implication: ""
missing_skills:
  - domain: ""
    would_have_used: ""
missing_tools_or_mcps:
  - capability: ""
    would_have_used: ""
```

Do not require feedback before completion. Offer it as a compact audit trail.

## 15.5 Advanced workflows

### 15.5.1 Self-improving agent workflow

Use this when the task involves agent improvement, prompt evolution, evals, memory, routing, or autonomous behavior.

```text
Bootstrap
-> current behavior inventory
-> eval/judge inventory
-> safety floor inventory
-> failure taxonomy
-> research-scout on current best practices
-> architecture-critic options matrix
-> red-team harm analysis
-> llm-council-plus architecture review
-> ADR
-> candidate generation
-> champion-challenger shadow
-> judge calibration
-> Pareto promotion
-> human/council approval
-> rollback/canary
```

Hard rules:

- Do not optimize before measurement exists.
- Do not trust measurement before judge calibration exists.
- Do not promote a candidate before shadow comparison exists.
- Do not use scalar-only fitness for multi-axis quality/safety.
- Candidate generation is allowed; autonomous promotion is not unless explicitly authorized.
- Past agent memories must be verified against code, logs, tests, or user confirmation.

### 15.5.2 Eval and judge design workflow

```text
Define target behavior
-> define hard safety floors
-> define quality dimensions
-> create frozen gold set
-> create adversarial set
-> create metamorphic tests
-> calibrate judges
-> run baseline
-> add drift monitoring
-> wire scorecards
-> only then use scores for decisions
```

Required logging fields when possible:

```text
candidate_id
champion_id
challenger_id
skill_version
prompt_version
policy_version
model_version
judge_version
rubric_version
probe_id
probe_type
source_type
score
confidence
judge_disagreement
safety_floor_result
promotion_decision_id
rollback_ref
```

### 15.5.3 Architecture decision workflow

Use for non-trivial architecture choices.

```text
ADR context
-> decision drivers
-> options, including "do nothing"
-> research evidence
-> codebase evidence
-> premortem
-> llm-council-plus
-> decision
-> consequences
-> rollout plan
-> rollback plan
-> verification plan
```

Do not make stale memory a veto. If prior decisions exist, cite them as evidence and re-evaluate under current conditions.

### 15.5.4 Production change workflow

For externally visible or production-affecting work:

```text
dry run
-> backup/snapshot
-> rollback command
-> staging/shadow/canary
-> human approval if irreversible
-> deploy
-> canary
-> post-deploy verification
-> rollback if gates fail
```

## 16. Final summary format

```markdown
## Outcome

## What changed
- Files:
- Behavior:
- APIs / UI / docs:

## Verification evidence
- Tests:
- Builds/checks:
- QA/security/performance:
- Council:

## Skills/tools used
- Loaded:
- Fallback used:
- Missing:

## Open follow-ups
- Deferred:
- Risks:
- Human decision needed:

## Audit notes
- Key decisions:
- Surprises:
- Missing skills/tools:
- Session log:
```

No marketing. No vague confidence. Facts and proof.

## 17. Closing contract

The agent must behave like the responsible owner of the work:

```text
- Think before acting.
- Use skills before improvising.
- Use council before major decisions.
- Carry errors forward.
- Keep or revert uncertain experiments.
- Verify before claiming completion.
- Preserve safety and reversibility.
- Do not hide missing tools.
- Do not lower the bar to finish faster.
- Do not assume the human is asleep or absent for a specific reason; do treat routine availability as uncertain. Do not assume the agent host.
```

Pure autonomy means sustained, evidence-backed work. It does not mean pretending risk is gone. It means making reversible progress until the work is real.
