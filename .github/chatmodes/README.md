# Chatmode Files

This directory contains interactive chatmode definitions for GitHub Copilot Chat.

## What are Chatmodes?

Chatmodes are interactive, conversational workflows that guide users through complex multi-step processes. Unlike traditional prompts that attempt to complete an entire workflow in one shot, chatmodes:

- **Enforce sequential steps** with mandatory validation
- **Require user confirmation** at key decision points
- **Block progress** when prerequisites aren't met
- **Provide clear feedback** at each stage
- **Handle errors gracefully** with recovery options
- **Maintain conversation state** across multiple turns

## Available Chatmodes

### backport-pr-to-release-branch.chatmode.md

**Purpose:** Guide users through backporting a merged PR to a PowerShell release branch.

**Use when:** You need to create a backport PR with proper branch naming, complete PR template, correct labels, and conflict resolution.

**Conversation starters:**
- "Backport PR 26398 to v7.4"
- "Show me PRs that need backporting to 7.5"
- "Help me backport a change to release/v7.4"

**Key features:**
- Mandatory initialization (reads all instruction files first)
- Interactive PR discovery and validation
- Guided conflict resolution with detailed summaries
- Preview-before-commit for PR body and labels
- Complete error handling with recovery options
- Clear success criteria and completion summary

**Why use chatmode vs prompt:**
- ✅ Can't skip required instruction files (enforced in first turn)
- ✅ User actively participates in verification
- ✅ Handles complex scenarios like merge conflicts interactively
- ✅ Clear progress indicators and state management
- ✅ Easy to recover from errors or change direction
- ✅ Reduces cognitive load by presenting one step at a time

## How to Use Chatmodes

1. **Start a conversation** with a chatmode-specific starter phrase
2. **Follow the prompts** - the chatmode will guide you step-by-step
3. **Provide confirmations** when requested (yes/no, proceed, etc.)
4. **Review previews** before committing to irreversible actions
5. **Trust the process** - each step builds on validated previous steps

## Benefits Over Traditional Prompts

| Aspect | Traditional Prompt | Chatmode |
|--------|-------------------|----------|
| **Step enforcement** | Can be skipped | Blocked until complete |
| **User validation** | Optional | Required at key points |
| **Error recovery** | Start over | Graceful handling |
| **State management** | All-or-nothing | Step-by-step progress |
| **Cognitive load** | High (entire workflow) | Low (one step at a time) |
| **Trust level** | Hope it works | Validated at each step |
| **Learning curve** | Read entire prompt | Guided interactively |

## When to Use Chatmode vs Prompt

**Use Chatmode when:**
- Process has many sequential steps
- Steps have dependencies on each other
- User needs to make decisions along the way
- Complex error conditions require human judgment
- High cost of failure (wrong labels, incorrect formats, etc.)
- Process requires reading instruction files

**Use Traditional Prompt when:**
- Single-purpose, one-shot task
- Minimal dependencies between steps
- Low risk if something goes wrong
- User is expert and just needs a reminder
- Speed is more important than validation

## Creating New Chatmodes

To create a new chatmode:

1. Create a `.chatmode.md` file in this directory
2. Include required sections:
   - **Description** - Brief purpose statement
   - **Conversation Starters** - Example phrases to trigger the chatmode
   - **Instructions** - Complete step-by-step flow
   - **Validation Rules** - Prerequisites for each step
   - **Error Handling** - What to do when things go wrong
   - **Success Criteria** - How to know you're done
3. Use clear conversation flow with:
   - Explicit step numbers
   - User confirmation points
   - Preview-before-commit for important actions
   - Error recovery options
4. Test thoroughly with various scenarios

## Contributing

When improving chatmodes:
- Add more error handling scenarios
- Improve validation messages
- Add recovery options for edge cases
- Include more conversation starters
- Document lessons learned from failed attempts
