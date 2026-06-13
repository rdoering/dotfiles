# Personal Rules

- use programming rules KISS, DYI
- avoid emojis
- personal dotfiles are manged by checzmoi

---

# OpenCode Model Compatibility Test Results

**Generated:** 2026-03-20
**Tested:** 89 models via `opencode run -m <model> "Respond with OK."` (30s timeout)

## Summary

| Status | Count |
|--------|-------|
| PASS | 34 |
| FAIL | 30 |
| SKIP (Non-chat) | 8 |
| TIMEOUT | 8 |

### By Provider

| Provider | Total | PASS | FAIL | TIMEOUT |
|----------|-------|------|------|---------|
| opencode | 6 | 6 | 0 | 0 |
| github-copilot | 25 | 16 | 9 | 0 |
| google/antigravity | 5 | 4 | 1 | 0 |
| google/standard | 22 | 3 | 4 | 15 |
| anthropic | 23 | 1 | 9 | 0 |

### Root Causes

1. **Anthropic (pre-fix):** 13x `claude-opus-4-*` and `claude-sonnet-4-*` failed with "Unrecognized key 'editor'" in opencode.json. **FIXED** - key removed from config.

2. **Anthropic legacy:** 9x `claude-3-5-haiku-*`, `claude-3-haiku-*`, `claude-3-opus-*`, `claude-3-sonnet-*` return API 404 - **deprecated by Anthropic**.

3. **GitHub Copilot:** 9x "not supported" - newer models (opus-4.6, opus-41, sonnet-4.6, gpt-5.x, gpt-5.3+, gemini-3.1-pro-preview) not in this Copilot subscription tier.

4. **Google standard:** 4x 403 Forbidden (gemini-2.5-flash, gemini-2.5-flash-lite, gemini-2.5-pro) - requires Google API key. 15x TIMEOUT - older gemini-1.5.x, 2.0.x models have no/broken endpoints.

5. **Google antigravity:** 4x PASS, 1x DEPRECATED (antigravity-gemini-3-pro says "no longer available").

6. **Google latest:** 3x PASS (gemini-3-flash-preview, gemini-3.1-pro-preview, gemini-3.1-pro-preview-customtools).

---

## Current oh-my-opencode.json Analysis

**Models configured in `oh-my-opencode.json` vs. test results:**

| Config Model | Expected Status |
|--------------|----------------|
| `anthropic/claude-opus-4-6` | Should PASS now (config fixed) |
| `anthropic/claude-sonnet-4-6` | Should PASS now (config fixed) |
| `anthropic/claude-haiku-4-5` | PASS |
| `anthropic/claude-sonnet-4-7` | Likely PASS now (similar to sonnet-4-6) |
| `google/gemini-3-flash-preview` | PASS |
| `google/gemini-3-pro-preview` | TIMEOUT (pre-fix test) |

---

## Recommended Model Configuration

### Primary Models (High capability)

| Agent | Recommended | Alternative |
|-------|-------------|-------------|
| sisyphus | `anthropic/claude-sonnet-4-6` | `opencode/big-pickle` |
| oracle | `anthropic/claude-opus-4-6` | `anthropic/claude-sonnet-4-6` |
| prometheus | `anthropic/claude-opus-4-6` | `anthropic/claude-sonnet-4-6` |
| metis | `anthropic/claude-sonnet-4-6` | `opencode/big-pickle` |
| momus | `anthropic/claude-opus-4-6` | `anthropic/claude-sonnet-4-6` |
| atlas | `anthropic/claude-sonnet-4-6` | `opencode/big-pickle` |
| sisyphus-junior | `anthropic/claude-sonnet-4-6` | `anthropic/claude-haiku-4-5` |
| deep | `anthropic/claude-opus-4-6` | `opencode/big-pickle` |
| ultrabrain | `anthropic/claude-opus-4-6` | `anthropic/claude-sonnet-4-6` |
| artistry | `google/gemini-3.1-pro-preview` | `opencode/big-pickle` |

### Light Models (Fast, cheap)

| Agent | Recommended | Alternative |
|-------|-------------|-------------|
| explore | `anthropic/claude-haiku-4-5` | `opencode/big-pickle` |
| quick | `anthropic/claude-haiku-4-5` | `opencode/gpt-5-nano` |
| unspecified-low | `anthropic/claude-haiku-4-5` | `opencode/gpt-5-nano` |
| unspecified-high | `anthropic/claude-sonnet-4-6` | `opencode/big-pickle` |

### Special Purpose

| Agent | Recommended | Notes |
|-------|-------------|-------|
| multimodal-looker | `google/gemini-3-flash-preview` | Supports images/PDFs |
| writing | `google/gemini-3-flash-preview` | Fast and capable |
| librarian | `anthropic/claude-haiku-4-5` | Fast search |

### Categories

| Category | Recommended | Alternative |
|----------|-------------|-------------|
| visual-engineering | `google/gemini-3-flash-preview` | `anthropic/claude-haiku-4-5` |
| ultrabrain | `anthropic/claude-opus-4-6` | `anthropic/claude-sonnet-4-6` |
| artistry | `google/gemini-3.1-pro-preview` | `anthropic/claude-sonnet-4-6` |
| quick | `anthropic/claude-haiku-4-5` | `opencode/gpt-5-nano` |
| unspecified-low | `anthropic/claude-haiku-4-5` | `opencode/gpt-5-nano` |
| unspecified-high | `anthropic/claude-sonnet-4-6` | `opencode/big-pickle` |
| writing | `google/gemini-3-flash-preview` | `anthropic/claude-haiku-4-5` |
| deep | `anthropic/claude-opus-4-6` | `anthropic/claude-sonnet-4-6` |

---

## Providers Status

- **opencode/*** - All 6 PASS. Good free fallback models.
- **anthropic/*** - After config fix, most should work. Legacy claude-3.x deprecated.
- **github-copilot/*** - 16/25 PASS. Some newer models not in subscription.
- **google/antigravity/*** - 4/5 PASS. Good for Gemini-family if Anthropic unavailable.
- **google/standard** - 3/27 PASS. Not usable without Google API key.

---

## Available Models (PASS only)

### opencode (6/6)
- opencode/big-pickle
- opencode/gpt-5-nano
- opencode/mimo-v2-omni-free
- opencode/mimo-v2-pro-free
- opencode/minimax-m2.5-free
- opencode/nemotron-3-super-free

### github-copilot (16/25)
- github-copilot/claude-haiku-4.5
- github-copilot/claude-opus-4.5
- github-copilot/claude-sonnet-4
- github-copilot/claude-sonnet-4.5
- github-copilot/gemini-2.5-pro
- github-copilot/gemini-3-flash-preview
- github-copilot/gemini-3-pro-preview
- github-copilot/gpt-4.1
- github-copilot/gpt-4o
- github-copilot/gpt-5-mini
- github-copilot/gpt-5.1
- github-copilot/gpt-5.1-codex
- github-copilot/gpt-5.1-codex-max
- github-copilot/gpt-5.1-codex-mini
- github-copilot/gpt-5.2
- github-copilot/gpt-5.2-codex
- github-copilot/grok-code-fast-1

### anthropic (1/23)
- anthropic/claude-haiku-4-5

### google/antigravity (4/5)
- google/antigravity-claude-opus-4-6-thinking
- google/antigravity-claude-sonnet-4-6
- google/antigravity-gemini-3-flash
- google/antigravity-gemini-3.1-pro

### google/standard (3/22)
- google/gemini-3-flash-preview
- google/gemini-3.1-pro-preview
- google/gemini-3.1-pro-preview-customtools
