# Changelog

## 1.6.0

### Added
- Getting started guide for ideation-first workflow (no app needed to start)
- Piotr decision library — real decision patterns extracted from code reviews and architecture choices
- Personas table in Getting Started
- `app-spec/` detection for ideation-first flow
- Scaffold into same directory — app-spec stays in place

### Changed
- Restructured README for ideation-first flow
- Recommend `create-mercato-app@develop` in getting started
- Slimmed om-product-manager
- Polished plugin metadata, added `.gitignore`

### Fixed
- Broken cross-skill references
- Sync script path rewriting
- Hook completeness
- Misleading "activates all skills" wording in building section

## 1.5.0

### Added
- **User Proxy** (`om-user-proxy`) — pipeline-level decision interceptor that answers routine agent questions on the user's behalf, learning from corrections
- **Proxy gates** in om-product-manager, om-cto, om-pre-implement-spec, om-implement-spec, om-code-review — all findings/questions pass through the proxy before reaching the user
- **Piotr Decision Library** — 10 real decision patterns extracted from code reviews and architecture choices
- **Cross-story impact analysis** in om-product-manager — matrix of state changes, affected stories, conflict patterns
- **Failure and alternate paths** required for every user story — happy-path-only stories are rejected
- **Toolkit Review** (`om-toolkit-review`) — 8-dimension audit of the skill corpus for context waste, duplication, and structural drift
- Daily CI workflow for automated skill sync from upstream with auto version bump
- Getting started guide for ideation-first workflow (no app needed to start)

### Changed
- Renamed Mat persona to Marty Cagan for clarity
- Converted om-cto into lean task router (4.4 KB) with on-demand reference loading
- Removed 4 orchestration wrapper skills — Piotr dispatches base OM skills directly with dispatch context
- Replaced static platform-capabilities checklist with live discovery (AGENTS.md + `gh search code`)
- Restructured README for ideation-first flow with `app-spec/` detection

## 1.1.0

### Added
- **Spec & Implementation Orchestrator** in om-cto — autonomous spec writing and implementation coordination
- Piotr feedback triage — classifies user feedback as code bug / spec gap / business change
- 5 additional upstream OM skills: om-eject-and-customize, om-data-model-design, om-module-scaffold, om-system-extension, om-troubleshooter
- 7 framework architecture guides vendored from upstream
- Cross-skill handoffs between orchestrator and implementation skills

### Changed
- Enforced pipeline lock and auto-chain code review in implementation flow
- Session-start hook now proactively guides users through the pipeline sequence

## 1.0.0

### Added
- Initial plugin with 7 skills: om-product-manager, om-cto, om-ux, om-spec-writing, om-implement-spec, om-pre-implement-spec, om-code-review
- SessionStart hook with OM project detection
- Sync script for vendoring OM platform skills and AGENTS.md references
- Marketplace registration
