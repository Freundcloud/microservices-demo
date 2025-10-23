#!/bin/bash
# Test Change Request JSON generation

ENV="prod"
RUN_URL="https://github.com/Calitii/ARC/actions/runs/12345"
ACTOR="olafkfreund"
BRANCH="main"
COMMIT_SHORT="abc1234"
REPO="Calitii/ARC/microservices-demo"
EVENT="push"
PR_NUMBER=""

# Build description
DETAILED_DESC="Automated deployment to $ENV environment via GitHub Actions"
DETAILED_DESC="${DETAILED_DESC}\n"
DETAILED_DESC="${DETAILED_DESC}\nGitHub Context:"
DETAILED_DESC="${DETAILED_DESC}\n- Actor: $ACTOR"
DETAILED_DESC="${DETAILED_DESC}\n- Branch: $BRANCH"
DETAILED_DESC="${DETAILED_DESC}\n- Commit: $COMMIT_SHORT"
DETAILED_DESC="${DETAILED_DESC}\n- Direct Push"
DETAILED_DESC="${DETAILED_DESC}\n"
DETAILED_DESC="${DETAILED_DESC}\nWorkflow Run: $RUN_URL"
DETAILED_DESC="${DETAILED_DESC}\nRepository: $REPO"
DETAILED_DESC="${DETAILED_DESC}\nEvent: $EVENT"

SHORT_DESC="Deploy to $ENV - $BRANCH by $ACTOR"

# Build JSON
CHANGE_JSON=$(jq -n \
  --arg short_desc "$SHORT_DESC" \
  --arg desc "$DETAILED_DESC" \
  --arg actor "$ACTOR" \
  --arg branch "$BRANCH" \
  --arg pr "$PR_NUMBER" \
  --arg commit "$COMMIT_SHORT" \
  '{
    setCloseCode: "true",
    autoCloseChange: true,
    attributes: {
      short_description: $short_desc,
      description: $desc,
      u_github_actor: $actor,
      u_github_branch: $branch,
      u_github_pr: $pr,
      u_github_commit: $commit
    }
  }')

echo "📋 Generated Change Request JSON:"
echo "================================="
echo ""
echo "$CHANGE_JSON" | jq .
echo ""
echo "✅ JSON is valid!"
