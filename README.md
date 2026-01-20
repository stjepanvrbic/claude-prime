# Prime - Context Priming Plugin

Context priming plugin that launches specialized subagents to analyze the codebase and provide targeted, LLM-optimized context. Designed as a context management technique to reduce main conversation token usage.

## Purpose

Instead of loading extensive context into CLAUDE.md, use `/prime` to:
- Get targeted context for specific tasks
- Keep CLAUDE.md minimal (~50 lines)
- Let subagents do exploration (their tokens don't accumulate in main context)
- Receive perfectly formatted context for LLM consumption

## Usage

```bash
# General project overview (~300 lines)
/prime

# Targeted analysis for a specific task (~500-600 lines)
/prime implement the backtest engine feature
/prime understand the data layer architecture
/prime F3.1 backtest engine

# Skip priming (mark session as primed without analysis)
/prime --skip
```

## Auto-Priming

If you don't manually run `/prime`, the plugin automatically primes on your first prompt:
- Uses your current git branch name as the priming prompt
- Example: `feature/F3.1-backtest-engine` → primes with "backtest engine"
- Falls back to general overview if not on a branch

To disable auto-priming for a session, run `/prime --skip` first.

## Architecture

### Multi-Agent Flow

**No-prompt flow (general overview):**
```
/prime
  └── general-overview agent
        └── synthesizer agent
              └── ~300 line output
```

**With-prompt flow (targeted analysis):**
```
/prime <description>
  └── coordinator agent
        ├── documentation agent (if needed)
        ├── deep-dive agent (if needed)
        └── surface-sweep agent (usually)
              └── synthesizer agent
                    └── ~500-600 line output
```

### Agents

| Agent | Model | Purpose |
|-------|-------|---------|
| coordinator | opus | Analyzes prompt, decides which agents to launch, handles failures |
| documentation | haiku | Targeted reading of spec.md, plan.md, tasks.md |
| deep-dive | sonnet | Detailed code analysis of specific areas |
| surface-sweep | haiku | Broad shallow analysis of entire project |
| synthesizer | opus | Combines all outputs into LLM-optimized format |
| general-overview | sonnet | Predefined flow for no-prompt case |

### Hooks

| Hook | Event | Purpose |
|------|-------|---------|
| session-start | SessionStart | Creates session state file (unprimed) |
| auto-prime-check | UserPromptSubmit | Checks if primed, injects instruction to prime if not |

## Output Format

The output is LLM-optimized, not human-optimized:

```
=PRIME [topic]

@PROJECT
purpose: single line description
stack: technologies

@STRUCTURE
path/       : role
path/       : role

@TASK
goal: what to accomplish
scope: areas involved

@FILES.critical
path/file.py:lines   # why critical

@FILES.related
path/file.py         # relevance

@PATTERNS
pattern: description @ location

@STATE
done: [list]
partial: [list]
missing: [list]

@DEPS
ClassA -> ClassB

@WARN
- warning with file:line

@START
entry: where to begin @ path:line
flow: step1 -> step2
```

## Installation

1. Copy the `prime` directory to your plugins location
2. Enable the plugin in Claude Code settings
3. Restart Claude Code

Or install via plugin directory flag:
```bash
claude --plugin-dir /path/to/prime
```

## Files

```
prime/
├── .claude-plugin/
│   └── plugin.json           # Plugin manifest
├── commands/
│   └── prime.md              # /prime command
├── agents/
│   ├── coordinator.md        # Orchestrates targeted analysis
│   ├── documentation.md      # Reads project docs
│   ├── deep-dive.md          # Detailed code analysis
│   ├── surface-sweep.md      # Broad project scan
│   ├── synthesizer.md        # Combines outputs
│   └── general-overview.md   # No-prompt overview
├── hooks/
│   ├── hooks.json            # Hook configuration
│   └── scripts/
│       ├── session-start.sh  # Creates session state
│       ├── auto-prime-check.sh # Checks if primed
│       └── mark-primed.sh    # Marks session as primed
└── README.md
```

## How It Works

1. **Session Start**: Hook creates a state file marking session as "unprimed"
2. **First Prompt**: If not primed, hook injects instruction to run `/prime` first
3. **Priming**: Subagents analyze codebase based on prompt (or general overview)
4. **Synthesis**: Synthesizer combines all outputs into optimized format
5. **Mark Primed**: Session is marked as primed, subsequent prompts proceed normally

## Notes

- All agents are READ-ONLY - they cannot modify files
- Agents run in parallel where possible for speed
- Coordinator handles agent failures by relaunching with adjusted parameters
- State files are stored in `.claude/` directory (gitignored)
