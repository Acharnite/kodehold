LANGUAGE: English for all code, comments, commit messages, and agent communication.
(When KODEHOLD_LIGHT=1: English only — token optimization.)
(Danish may be spoken for local context — respond in English.)

CODING STYLE:
- Python: Follow PEP 8. Use type hints. Prefer explicit imports over wildcard.
- JavaScript/TypeScript: Use ES6+ syntax. Prefer const over let. Use async/await over callbacks.
- Shell: Use #!/usr/bin/env bash. Set -euo pipefail. Prefer [[ ]] over [ ].
- Rust: Follow rustfmt. Use clippy. Document public APIs.
- Go: Follow gofmt. Use golangci-lint.

NAMING:
- Files: kebab-case for config/scripts, snake_case for Python modules, PascalCase for React components.
- Git branches: kebab-case with type prefix: feat/, fix/, docs/, refactor/.
- Git commits: Conventional Commits: type(scope): description. E.g., feat(auth): add OAuth2 login.

PROJECT STRUCTURE:
- Source in src/ or project root.
- Tests in test/ or alongside source (__test__/ or .test.ts).
- Docs in docs/.
- Config in .config/ or root.

PREFERENCES:
- Prefer simple, readable code over clever/optimized.
- Add comments for WHY, not WHAT. The code says what it does.
- Error messages should tell you what happened AND what to do about it.