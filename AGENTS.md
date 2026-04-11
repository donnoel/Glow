# AGENTS.md

This repo is an Apple-platform app codebase. You are an engineering agent (Codex) collaborating with the human. Your job is to make small, correct, testable changes with a clean build at every step.

## Hard requirements (do not violate)
- **No build warnings.** Treat warnings as errors in practice.
- **No large rewrites.** Prefer small, surgical diffs.
- **Apple-native only.** No third-party libraries unless explicitly requested.
- **SwiftUI + SwiftData.** Keep UI declarative; keep logic in view models/domain/utilities.
- **Concurrency correctness.** Keep UI/view-model state on the main actor; avoid broad `@MainActor` on domain/services unless required.
- **CloudKit-safe models.** Preserve SwiftData + CloudKit compatibility constraints.
- **Widget sync must stay reliable.** App-group progress writes and widget reload behavior must remain intact.
- **Privacy-first.** No unexpected network calls.
- **Preserve behavior contracts.** Do not regress onboarding, reminders, scheduling, archive, trends, or widget flows without explicitly calling it out.

## Workflow
1. Read existing code and architecture before editing.
2. Propose a minimal plan in 2-5 bullets.
3. Implement the smallest viable patch.
4. Ensure build passes with **zero warnings**.
5. Run relevant tests (or all tests for risky changes). Add tests for non-trivial logic.
6. If behavior changed, update docs (`README.md` / `AGENTS.project.md`) in the same patch.

## Code style
- Keep types small and focused.
- Prefer deterministic, testable view-model/domain logic.
- Prefer structured logging/status over noisy ad-hoc prints.
- Keep date/schedule logic explicit and timezone-safe.
- Keep persistence and sync code idempotent where practical.
- Avoid global mutable state unless explicitly designed.

## Deliverables for each change
- Mention which files were modified and why.
- Provide a short commit message suggestion.
- Mention any user-visible behavior changes explicitly.
- Call out test/build commands run and their result.

## What not to do
- Don't introduce new dependencies.
- Don't disable warnings or concurrency checks to make code compile.
- Don't broadly add `@MainActor` to silence isolation issues.
- Don't change reminder/scheduling semantics without tests.
- Don't silently swallow failures in data-loss-sensitive paths.
- Don't change public behavior without stating it.

If something is ambiguous, default to the simplest solution that preserves correctness and forward progress, then ask for clarification.
