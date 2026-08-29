# Completion receipt

```markdown
# SuperImprove receipt

- Status: clean | partial | blocked | aborted
- Objective:
- Scope:
- Base commit:
- Final commit or working-tree state:
- Budget used:

## Accepted changes

| Change | Evidence | Commit |
|---|---|---|

## Verification

| Gate | Command or action | Result | Delta from baseline |
|---|---|---|---|

## Remaining findings

| Severity | Finding | Evidence | Why not fixed | Next action |
|---|---|---|---|---|

## Not verified

- Gate, reason, and consequence.

## Repository state

- Branch:
- `git status`:
- Push/merge/deploy performed: yes/no
```

Do not omit empty sections; write `none` so silence cannot be mistaken for verification.
