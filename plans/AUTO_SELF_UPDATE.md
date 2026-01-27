# Auto Self-Update Plan

> Status: IMPLEMENTED - See `.github/workflows/`

## Overview

GitHub Actions that keep the wizard in sync with Claude Code updates automatically.

## What's Implemented

### Daily Update Check (`.github/workflows/daily-update.yml`)
- **Trigger:** Daily at 9 AM UTC + manual dispatch
- **Checks:** Claude Code GitHub releases
- **Action:** Creates PR for HIGH/MEDIUM relevance updates

### Weekly Community Scan (`.github/workflows/weekly-community.yml`)
- **Trigger:** Sundays at 9 AM UTC + manual dispatch
- **Checks:** Reddit, HN, dev blogs, official channels
- **Action:** Creates digest issue for notable findings

## Key Design Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| Official sources | Daily | Releases every 1-2 days, need timely updates |
| Community sources | Weekly | Less urgent, more noise, digest format |
| State storage | Files in repo | Simple, transparent, version-controlled |
| Analysis | Claude API | Nuanced understanding of wizard philosophy |
| Confidence threshold | MEDIUM+ creates PR | Prevents noise |
| Default stance | Don't add | Only suggest if genuinely needed |

## Files Created

```
.github/
├── workflows/
│   ├── daily-update.yml      # Official release monitoring
│   └── weekly-community.yml  # Community discussion scanning
├── prompts/
│   ├── analyze-release.md    # Claude prompt for release analysis
│   └── analyze-community.md  # Claude prompt for community scan
├── last-checked-version.txt  # Last processed Claude Code version
└── last-community-scan.txt   # Last community scan date
```

## Required Secrets

- `ANTHROPIC_API_KEY` - for Claude analysis in workflows

## Philosophy Preserved

- KISS - minimal files, simple flow
- Human-in-the-loop - PRs/issues require review
- Wizard philosophy - baked into analysis prompts
- No bloat - only HIGH/MEDIUM confidence creates PRs
- Use official when available - prompts check for plugin replacements
