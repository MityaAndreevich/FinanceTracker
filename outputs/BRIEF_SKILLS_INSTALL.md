# BRIEF (Claude Code) — Install the skills we actually need

Run in **Claude Code** (skills can't be installed from Cowork). Model: **Sonnet** (mechanical setup).
Context: we already have `app-store` / `release-review` / `security` / `ui-ux-pro-max` skills installed — do NOT duplicate those. We evaluated 4 repos; only the items below fill real gaps (rigorous debug/TDD discipline + iOS Simulator automation).

## 1. Superpowers — INSTALL (trusted: Anthropic official marketplace, 243k★, MIT)
Gives: `systematic-debugging` (4-phase root cause), `test-driven-development` (RED-GREEN), `verification-before-completion`, `brainstorming`, `writing-plans`, `requesting-code-review`. This is exactly the discipline our save-bug brief needs.
```
/plugin install superpowers@claude-plugins-official
```
If that name isn't found, use the author marketplace:
```
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace
```
After install, the debugging + TDD skills should auto-trigger. Immediately re-run the save-bug work under `systematic-debugging` + `test-driven-development`.

## 2. iOS Simulator skill — INSTALL after reviewing (single-author, review SKILL.md first)
Repo: https://github.com/conorluddy/ios-simulator-skill — lets Claude drive the iOS Simulator to test/debug the app (reproduce the save-duplication bug, run QA loop).
Steps:
1. Clone and READ `SKILL.md` + any scripts before trusting it (3rd-party code that runs with tool access).
2. If clean, copy the skill folder into your Claude Code skills directory (`~/.claude/skills/` or the project `.claude/skills/`).
3. Report back what commands it exposes.

## 3. SwiftUI design skill — OPTIONAL (review; docs are in Chinese)
Repo: https://github.com/wholiver/swiftui-design-skill — SwiftUI anti-"AI-slop" design review, relevant to the redesign. Only add if #1/#2 land well and you want a design-review pass. Review SKILL.md first.

## SKIP (with reason)
- **jeffallan/claude-skills** (66 skills): web-stack (NestJS/React/Python), almost no Swift/iOS; general debug/test/review overlaps superpowers + our installed skills; workflow cmds need Atlassian/Jira MCP. Not worth the context.
- **ComposioHQ/awesome-claude-skills** & **rohitg00/awesome-claude-code-toolkit**: these are CATALOGS (link lists), not skills. Keep the URLs as bookmarks; nothing Swift/finance-specific to install.

## Note
None of these cover ASO/marketing — our AppStudio playbooks + NotebookLM already do that better. No action there.
