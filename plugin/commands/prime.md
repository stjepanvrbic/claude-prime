---
description: Prime context for current session - analyzes codebase and provides LLM-optimized context
argument-hint: [description] or --skip
---

Context priming command that launches specialized subagents to analyze the codebase and provide targeted, LLM-optimized context for the current session.

## Invocation Handling

Parse the arguments provided: `$ARGUMENTS`

**If `--skip` flag is present:**
1. Mark the session as primed by running: `bash "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/mark-primed.sh"`
2. Report: "Session marked as primed (skipped analysis)"
3. Stop here - do not launch any agents

**If no arguments provided (empty or whitespace only):**
1. Use the general-overview agent via Task tool
2. This triggers the predefined general overview flow
3. Pass the agent output to the synthesizer agent
4. Return the synthesized output (~300 lines max)

**If arguments provided (description/prompt):**
1. Use the coordinator agent via Task tool
2. Pass the full prompt/description to the coordinator
3. The coordinator will analyze and launch appropriate agents (documentation, deep-dive, surface-sweep)
4. All agent outputs go to the synthesizer agent
5. Return the synthesized output (~500-600 lines max)

## Progress Updates

Provide concise status updates as agents complete:
- "Launching coordinator..."
- "Coordinator dispatched: [agent names]"
- "Documentation analysis complete"
- "Deep-dive analysis complete"
- "Surface-sweep complete"
- "Synthesizing results..."

## After Completion

1. Mark session as primed by running: `bash "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/mark-primed.sh"`
2. Return the final synthesized context to the user

## Agent Invocation

Use the Task tool with these subagent types:
- `prime:general-overview` - for no-prompt flow
- `prime:coordinator` - for with-prompt flow
- `prime:synthesizer` - always called last to format output

The coordinator internally launches:
- `prime:documentation` - when task involves documented features
- `prime:deep-dive` - when implementation details needed
- `prime:surface-sweep` - for broad project understanding

## Critical Rules

1. All agents are READ-ONLY - they cannot modify any files
2. Show progress updates between agent completions
3. Always mark session as primed after successful completion
4. Output format must be LLM-optimized (see synthesizer agent for format)
