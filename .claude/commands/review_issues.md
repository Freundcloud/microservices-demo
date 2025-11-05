# Review Outstanding GitHub Issues

You are conducting a comprehensive review of all open GitHub issues to understand their status and recommend next steps.

## Your Task

1. **Fetch All Open Issues**
   - Use `gh issue list --state open --json number,title,labels,createdAt,updatedAt,url,assignees,milestone`
   - Sort by priority labels or creation date
   - Group by labels (bug, enhancement, documentation, etc.)

2. **Analyze Each Issue**

   For each open issue, investigate:

   **Status Assessment:**
   - Read the issue description and comments
   - Check for related commits: `git log --all --grep="#ISSUE_NUMBER"`
   - Look for related PRs: `gh pr list --search "ISSUE_NUMBER"`
   - Search codebase for TODOs referencing the issue
   - Determine current state: Not Started / In Progress / Blocked / Needs Review

   **Work Completed:**
   - Identify commits addressing the issue
   - Check if code changes exist
   - Verify if tests were added
   - Check if documentation was updated

   **Blockers & Dependencies:**
   - Check issue comments for blocking issues
   - Identify technical dependencies
   - Note if waiting for external input
   - Check if related to other open issues

3. **Create Comprehensive Report**

   Present findings in this structure:

   ## 📊 Issue Review Summary

   **Total Open Issues**: [COUNT]
   **By Status**:
   - 🔴 Blocked: [COUNT]
   - 🟡 In Progress: [COUNT]
   - 🟢 Ready to Start: [COUNT]
   - 🔵 Needs Review: [COUNT]

   **By Priority**:
   - Critical: [COUNT]
   - High: [COUNT]
   - Medium: [COUNT]
   - Low: [COUNT]

   ---

   ## 🔴 Critical Issues (Priority 1)

   ### Issue #[NUM]: [TITLE]
   **Labels**: [LABELS]
   **Created**: [DATE] | **Updated**: [DATE]
   **Assignee**: [ASSIGNEE] or Unassigned

   **Status**: [Not Started / In Progress / Blocked / Needs Review]

   **Work Completed**:
   - ✅ [Completed item] - [Commit SHA]
   - ✅ [Completed item] - [Commit SHA]
   - ⏳ [In progress item]
   - ❌ [Not started item]

   **Blockers**:
   - [Blocker description] - [Related issue #]

   **Next Steps**:
   1. [Specific action item]
   2. [Specific action item]
   3. [Specific action item]

   **Recommendation**: [Immediate action to take]

   **Estimated Effort**: [XS/S/M/L/XL]

   ---

   ## 🟡 In Progress Issues

   [Same format as above for each issue]

   ---

   ## 🟢 Ready to Start Issues

   [Same format as above for each issue]

   ---

   ## 🔵 Needs Review / Verification

   [Issues where work is done but needs testing/review]

   ---

   ## 💡 Recommendations

   ### Immediate Actions (This Week)
   1. **Issue #[NUM]** - [Why priority, what to do]
   2. **Issue #[NUM]** - [Why priority, what to do]
   3. **Issue #[NUM]** - [Why priority, what to do]

   ### Short-term (Next 2 Weeks)
   1. **Issue #[NUM]** - [Rationale]
   2. **Issue #[NUM]** - [Rationale]

   ### Long-term (Backlog)
   1. **Issue #[NUM]** - [Can be deferred because...]

   ### Issues to Close
   - **Issue #[NUM]** - [Reason: work completed, duplicate, wontfix]

   ### Issues Needing Clarification
   - **Issue #[NUM]** - [What information is missing]

   ---

   ## 📈 Metrics

   **Issue Velocity**:
   - Issues closed last 7 days: [COUNT]
   - Issues opened last 7 days: [COUNT]
   - Net change: [+/- COUNT]

   **Age Analysis**:
   - Issues > 30 days old: [COUNT]
   - Issues > 90 days old: [COUNT]
   - Oldest issue: #[NUM] ([AGE] days)

   **Response Time**:
   - Average time to first response: [DAYS]
   - Issues without response: [COUNT]

   ---

   ## 🎯 Suggested Work Plan

   **This Week:**
   ```
   Monday: Issue #[NUM] - [Brief task]
   Tuesday: Issue #[NUM] - [Brief task]
   Wednesday: Issue #[NUM] - [Brief task]
   ...
   ```

   **Next Sprint:**
   - Focus area: [Theme - e.g., "ServiceNow Integration Stability"]
   - Target issues: #[NUM], #[NUM], #[NUM]
   - Success criteria: [Measurable goal]

4. **Search for Issue References**

   Use these searches to find issue-related work:

   ```bash
   # Find commits mentioning issue
   git log --all --oneline --grep="#NUM"

   # Search code for TODO comments
   grep -r "TODO.*#NUM" --include="*.{js,py,go,yaml}"

   # Check PRs
   gh pr list --search "NUM in:title,body"

   # Find related issues
   gh issue list --search "NUM in:body"
   ```

5. **Assess Dependencies**

   Check for:
   - Issues blocking other issues
   - Issues blocked by external dependencies
   - Issues that should be grouped together
   - Issues that conflict with each other

6. **Quality Checks**

   For each issue, verify:
   - Clear description and acceptance criteria
   - Appropriate labels (bug, enhancement, etc.)
   - Assigned to someone if in progress
   - Linked to milestone if applicable
   - Has recent activity or needs attention

7. **Ask Strategic Questions**

   After presenting the review, ask:
   - "Which critical issue should we tackle first?"
   - "Are there any issues we should close or defer?"
   - "Do you want me to start working on any specific issue?"
   - "Should I create a detailed implementation plan for any issue?"

## Search Strategy

**Phase 1 - Issue Discovery:**
1. Fetch all open issues with metadata
2. Group by labels and priority
3. Identify stale issues (no activity > 30 days)

**Phase 2 - Deep Analysis:**
1. For critical/high priority issues:
   - Read issue thread completely
   - Check git history
   - Search codebase for related changes
   - Review any linked PRs

**Phase 3 - Status Assessment:**
1. Determine actual state vs reported state
2. Identify blockers and dependencies
3. Estimate remaining effort

**Phase 4 - Prioritization:**
1. Consider business impact
2. Consider technical dependencies
3. Consider effort vs value
4. Create recommended work plan

## Important Guidelines

- **Be thorough**: Check ALL open issues
- **Be accurate**: Verify status by checking code/commits, not just issue comments
- **Be practical**: Recommendations should be actionable
- **Be honest**: Flag issues that should be closed or deferred
- **Be strategic**: Group related issues, identify quick wins
- **Provide evidence**: Link to commits, PRs, files as proof

## Tools to Use

- `gh issue list`: Get all issues with metadata
- `gh issue view [NUM]`: Read specific issue details
- `gh pr list`: Find related pull requests
- `git log --grep`: Find commits mentioning issues
- `Grep`: Search for TODOs and code references
- `Read`: Read issue-related code files
- `Bash`: Run git commands for history analysis

## Output Format

Use clear emoji indicators:
- 🔴 Critical/Blocked
- 🟡 In Progress
- 🟢 Ready to Start
- 🔵 Needs Review
- ✅ Completed work
- ❌ Not started work
- ⏳ In progress work
- ⚠️ Blocker/Warning
- 💡 Recommendation
- 🎯 Next action

## Example Issue Analysis

```markdown
### Issue #42: Fix database connection timeout

**Labels**: bug, critical, backend
**Created**: 2025-10-15 | **Updated**: 2025-11-03
**Assignee**: @developer

**Status**: 🟡 In Progress

**Work Completed**:
- ✅ Identified root cause - connection pool size too small (commit a1b2c3d)
- ✅ Added connection pool monitoring (commit e4f5g6h)
- ⏳ Testing new pool configuration in dev environment
- ❌ Production deployment not yet scheduled

**Blockers**:
- None currently

**Next Steps**:
1. Complete testing in dev environment (2 days)
2. Schedule production deployment window
3. Update monitoring dashboards
4. Document new pool settings

**Recommendation**: Priority for this week. Testing is nearly complete.

**Estimated Effort**: S (2-3 days remaining)
```

---

**After presenting the review, ask which issues the user wants to prioritize and if they'd like you to create implementation plans for any specific issues.**
