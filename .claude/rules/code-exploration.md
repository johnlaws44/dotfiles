# Code Exploration Policy

## Tool Use Efficiency

- **Read only what's needed.** Do not read files for background context unless directly required by the task.
- **Search before reading.** Use Grep or Glob to locate the relevant section before opening a file.
- **No speculative reads.** Do not open related files "just in case" — wait until they're actually needed.
- **Prefer targeted edits.** Don't re-read a file you've already read in the same session unless the task requires it.

## Code Intelligence

Prefer structured code intelligence over brute-force text traversal.

### LSP (priority for code navigation)

Use LSP operations when navigating source code — they are semantic, exact, and ~600x faster than grep:

| Intent | LSP operation |
|--------|--------------|
| Find where something is defined | `goToDefinition` |
| Find all usages of a symbol | `findReferences` |
| Get type info or docs inline | `hover` |
| Search symbols across the project | `workspaceSymbol` |
| Find interface implementations | `goToImplementation` |
| Trace call chains | `incomingCalls` / `outgoingCalls` |

**Rule:** Use LSP for any code navigation. Reserve Grep for text/string/comment searches where semantic context is not needed.

### ast-grep (priority for structural search)

Use `ast-grep` for any search that requires understanding code structure rather than raw text:

```bash
ast-grep --lang <language> -p '<pattern>'
```

Examples of when to use ast-grep instead of Grep:
- "Find all async functions without error handling"
- "Find all React components using a specific hook"
- "Find all calls to a method with a specific argument shape"

**Rule:** If a search requires understanding syntax (not just matching strings), use `ast-grep`. Plain text/string matches still use Grep.
