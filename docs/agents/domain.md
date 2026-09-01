# Domain Docs

Before exploring, read relevant root `CONTEXT.md` and decisions in `docs/adr/`.
If they do not exist, proceed silently. Create them lazily only when domain terms or architectural decisions need recording.

## File structure

Single-context repository:

```
/
├── CONTEXT.md
├── docs/adr/
└── src/
```

Use vocabulary defined in `CONTEXT.md`. Flag any conflict with an existing ADR rather than silently overriding it.
