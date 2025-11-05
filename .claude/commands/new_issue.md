# Create New GitHub Issue with Analysis

You are creating a new GitHub issue for a problem that needs tracking and review.

## Your Task

1. **Analyze the Problem**
   - Read relevant code files to understand the issue
   - Search for related code patterns and configurations
   - Identify root causes through systematic investigation
   - Check logs, error messages, or stack traces if provided

2. **Research Solutions**
   - Review similar issues in the codebase
   - Check documentation and best practices
   - Identify 2-3 potential solution approaches
   - Evaluate pros/cons of each approach
   - Recommend the best solution with justification

3. **Create Comprehensive Documentation**
   - Write a detailed analysis document in `docs/` directory
   - Use format: `docs/[COMPONENT]-[ISSUE-TYPE]-ANALYSIS.md`
   - Include:
     - Executive Summary
     - Problem Statement with evidence
     - Root Cause Analysis
     - Proposed Solutions (Options A, B, C)
     - Recommended Implementation
     - Testing Strategy
     - Implementation Checklist

4. **Create GitHub Issue**
   - Use `gh issue create` command
   - Title: Clear, actionable description (e.g., "Fix X failing with error Y")
   - Body: Link to analysis document with summary
   - Labels: bug, enhancement, or appropriate category
   - Format:
     ```markdown
     ## Problem
     [Brief description]

     ## Root Cause
     [Summary of analysis]

     ## Proposed Solution
     [Recommended approach]

     ## Documentation
     - Analysis: @docs/[FILENAME].md

     ## Acceptance Criteria
     - [ ] [Testable outcome 1]
     - [ ] [Testable outcome 2]
     ```

5. **Present to User**
   - Show the issue URL
   - Summarize key findings
   - Explain recommended solution
   - Ask if user wants to proceed with implementation

## Important Guidelines

- **Be thorough**: Read code, don't guess
- **Use evidence**: Include error messages, line numbers, file paths
- **Multiple solutions**: Always present alternatives
- **Clear recommendation**: Pick the best approach with reasoning
- **Actionable**: Make it easy to implement
- **Track everything**: Document all findings

## Example Usage

User provides: "The deployment fails with timeout error"

You should:
1. Search logs for timeout errors
2. Read deployment scripts and configurations
3. Check resource limits, network settings
4. Identify root cause (e.g., insufficient timeout value)
5. Create analysis document
6. Create GitHub issue with link to analysis
7. Present findings to user

---

**After creating the issue, ask the user if they want to proceed with implementing the fix.**
