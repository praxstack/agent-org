# Verification gates

Use two independent signals when the host permits it: execution evidence and a fresh-context review. A second model or subagent can strengthen review diversity, but it is optional and never substitutes for running the system.

| Gate | Evidence | Failure response |
|---|---|---|
| Scope | Diff contains only authorized work | Split or revert the unauthorized part |
| Behavior | Focused regression check fails before or is otherwise tied to the defect, then passes | Reject the iteration |
| Baseline | Applicable test, lint, typecheck, and build results do not regress | Reject the iteration |
| Real surface | Main user path is exercised with observable output | Mark not verified or reject a risky claim |
| Test integrity | No skipped, deleted, weakened, or hollow assertion | Stop the line |
| Security | No new secret, unsafe boundary, or permission expansion | Reject and investigate |
| Review | Cumulative diff has no unresolved critical or major finding | Continue within budget or exit partial |

Record exact commands, exit codes, relevant counts, and artifact paths. Summaries such as “tests pass” are not sufficient receipts.

If a gate requires credentials, devices, a production service, or unavailable tooling, do not improvise access. Mark it `not verified`, explain the impact, and downgrade the completion state when material.
