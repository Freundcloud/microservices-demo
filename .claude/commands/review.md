# Code Review and Status Analysis

You are conducting a comprehensive code review to understand what has been done and what remains to be done.

## Your Task

1. **Understand the Context**
   - Read all relevant files mentioned by the user
   - Check recent git commits and changes
   - Review documentation and issue history
   - Understand the overall architecture and patterns

2. **Analyze What's Been Done**
   - Identify completed features and functionality
   - Review implementation quality and patterns
   - Check for tests and documentation
   - Note any technical debt or issues
   - Verify adherence to coding standards

3. **Research What's Needed**
   - Check roadmap and issue tracker
   - Identify incomplete features
   - Find TODOs and FIXMEs in code
   - Review related GitHub issues
   - Check for missing tests or documentation

4. **Code Quality Assessment**
   - Security vulnerabilities
   - Performance concerns
   - Code duplication
   - Error handling completeness
   - Test coverage
   - Documentation quality

5. **Create Comprehensive Report**

   Present findings in this structure:

   ### Executive Summary
   - Overall status (% complete)
   - Key achievements
   - Critical issues
   - Recommended next steps

   ### What's Been Done ✅
   **Implemented Features:**
   - [Feature 1] - [Brief description]
   - [Feature 2] - [Brief description]

   **Code Quality:**
   - Testing: [Coverage %, types of tests]
   - Documentation: [Quality assessment]
   - Standards: [Adherence level]

   **Recent Changes:**
   - [Commit SHA] - [Description]
   - [Commit SHA] - [Description]

   ### What's Needed 📋
   **Incomplete Features:**
   - [Feature] - [Current state, what's missing]

   **Technical Debt:**
   - [Issue] - [Impact, priority]

   **Missing Elements:**
   - [ ] Tests for [component]
   - [ ] Documentation for [feature]
   - [ ] Error handling in [module]

   ### Code Quality Issues 🔍
   **Critical:**
   - [Issue] - [Location: file:line]

   **Warnings:**
   - [Issue] - [Location: file:line]

   **Suggestions:**
   - [Improvement] - [Rationale]

   ### Recommendations 💡
   **Priority 1 (Immediate):**
   1. [Action item] - [Reason]

   **Priority 2 (Short-term):**
   1. [Action item] - [Reason]

   **Priority 3 (Long-term):**
   1. [Action item] - [Reason]

   ### Next Steps 🚀
   1. [Specific actionable step]
   2. [Specific actionable step]
   3. [Specific actionable step]

6. **Ask Follow-up Questions**
   - What should we prioritize?
   - Are there specific areas of concern?
   - What's the timeline for completion?

## Search Strategy

When reviewing code:
1. **Start broad**: Search for main files and entry points
2. **Go deep**: Read implementation details
3. **Check connections**: Look for imports, dependencies
4. **Verify tests**: Find and review test files
5. **Read docs**: Check README, comments, documentation files

## Important Guidelines

- **Be comprehensive**: Don't skip files
- **Use evidence**: Reference specific files and line numbers
- **Be objective**: Point out both strengths and weaknesses
- **Be practical**: Recommendations should be actionable
- **Be clear**: Use examples and specific locations

## Tools to Use

- `Grep`: Search for patterns, TODOs, FIXMEs
- `Read`: Read complete files for understanding
- `Glob`: Find related files by pattern
- `Bash`: Check git history, run analysis commands
- `Task`: Use specialized agents for deep analysis

## Example Searches

- TODOs: `grep -i "TODO\|FIXME\|XXX\|HACK" --output=content`
- Tests: `glob "**/*test*"`
- Recent changes: `git log --oneline -20`
- Security issues: Search for common vulnerabilities
- Error handling: Look for try/catch, error checks

---

**After presenting the review, ask the user which area they'd like to focus on or what they'd like to tackle first.**
