# Global Claude Instructions

## Git Commits

Never attribute yourself in commits (no `Co-Authored-By`, no "Generated with"
footers) unless I explicitly ask in that message.

Never commit superpowers docs (`docs/superpowers/`) unless I explicitly ask in
that message. This directory is gitignored; do not stage it with `git add -f`.

Always use Conventional Commits: `<type>(<optional scope>): <description>`

- Types: `feat`, `fix`, `refactor`, `docs`, `chore`, `style`, `test`, `perf`
- Description in imperative mood — "add login button", not "added login button"
- Add a multi-line body explaining the *why* when the change is non-obvious

```
feat(auth): add google oauth login

Password reset traffic was 40% of support tickets. OAuth removes the
password from the flow entirely for the majority of users.
```

## Code Style

Order functions so a file reads as a top-down narrative: every function is
followed by those at the next level of abstraction down. Callers above callees.
A reader should be able to stop at any depth and still have understood the
level above it.

```ts
export function publishPost(draft: Draft) {   // level 1
  const post = renderPost(draft)
  return savePost(post)
}

function renderPost(draft: Draft) {           // level 2 — called by publishPost
  return { ...draft, html: toHtml(draft.body) }
}

function toHtml(body: string) { /* ... */ }   // level 3 — called by renderPost

function savePost(post: Post) { /* ... */ }   // level 2
```

Applies to new files and to files you are already restructuring. Do not reorder
an existing file purely to satisfy this rule when the diff would drown the
actual change.

## Function Interfaces

Design deep modules: simple interfaces hiding rich functionality. Resist
inventing narrow arg-object types when a domain entity already exists.

- Accept the domain entity, not a bespoke subset of its fields. Every ad-hoc
  `{ id: string; name: string; status: string }` arg type is a new concept
  readers must learn; the domain entity is already understood.
- A function that takes the whole entity can use additional fields later without
  changing its signature — the interface stays stable as functionality deepens.
- Callers shouldn't need to know which fields the function reads; that's an
  implementation detail the interface should hide.

Break this rule when: the function genuinely crosses domain boundaries and no
single entity covers its inputs, or when you intentionally want a narrow
contract to decouple from a large type (e.g., a pure utility that should not
know about your ORM).

## Comments

Write comments only where they carry information the code cannot.

Do NOT:

- Narrate what the code does. If a reader can see it from the code, the comment
  is noise.
- Add section-header or block comments above logical groups
  (`// Fetch the user`, `// Validate input`, `// --- Setup ---`).
- Restate function signatures, parameter names, or types in prose.
- Comment obvious control flow, imports, or variable assignments.
- Leave commentary about the change you are making (`// Added error handling
  here`, `// Updated to use v2 API`). That belongs in the commit message or PR
  description.
- Add TODO/FIXME unless I asked for it.

DO comment:

- Why a non-obvious decision was made, especially workarounds, ordering
  constraints, and deliberate deviations from the obvious approach.
- External context the code can't express: spec/RFC references, ticket IDs,
  vendor API quirks, links to upstream bugs.
- Invariants and preconditions a caller could plausibly violate.
- Genuinely subtle math, bit manipulation, or regex.

Prefer clearer names and smaller functions over explanatory comments. If a
comment is needed to explain *what* a block does, extract it into a well-named
function instead.

Docstrings/JSDoc: only on exported/public API surface, and only when they add
something beyond the signature. Skip them on internal helpers.

Existing comments: preserve them unless the code they describe changed. Do not
add comments to code you are only incidentally touching.
