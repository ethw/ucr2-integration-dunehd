#!/bin/bash
# Fork: merges the original project's main into this fork's main, automatically, when it is safe.
#
# Run by .gitea/workflows/upstream-sync.yml (weekly, or by hand). Steps:
#   1. fetch the original's main; stop if `upstream` already has it
#   2. refuse if the original rewrote history (`upstream` is not an ancestor of it)
#   3. merge it into a copy of main; a conflict fails the run
#   4. run CHECK_CMD (tests and the device build) on the merge
#   5. green: push the original to `upstream` and the merge to `main` (a fast-forward), both or
#      neither. With SYNC_PUSH=0 the push is left to the caller: what to push is written
#      to $SYNC_STATE (UPSTREAM_SHA=..., MERGE_TREE=...), so the workflow can set up its deploy
#      key only after the checks, which run upstream's code.
# Any failure leaves main alone; the workflow then opens an issue.
#
# Environment: UPSTREAM_URL, UPSTREAM_BRANCH (default main), CHECK_CMD, GIT_NAME, GIT_EMAIL,
# COMMIT_TRAILER (optional, appended to the merge message), SYNC_TAGS (0/1), SYNC_PUSH (default 1),
# SYNC_STATE (file, with SYNC_PUSH=0). origin must be pushable when SYNC_PUSH=1.
set -euo pipefail

: "${UPSTREAM_URL:?}" "${CHECK_CMD:?}" "${GIT_NAME:?}" "${GIT_EMAIL:?}"
UPSTREAM_BRANCH=${UPSTREAM_BRANCH:-main}

git config user.name "$GIT_NAME"
git config user.email "$GIT_EMAIL"

git remote remove original 2>/dev/null || true
git remote add original "$UPSTREAM_URL"
git fetch --quiet --no-tags original "$UPSTREAM_BRANCH"
git fetch --quiet origin main upstream
# SYNC_TAGS=1: also take the original's version tags, so `git describe` sees its releases.
# Only for forks whose own tags can't collide with the original's (a -fork suffix).
if [ "${SYNC_TAGS:-0}" = 1 ]; then
  git fetch --quiet original 'refs/tags/v*:refs/tags/v*'
fi

new=$(git rev-parse "original/$UPSTREAM_BRANCH")
old=$(git rev-parse origin/upstream)

if [ "$new" = "$old" ]; then
  echo "upstream unchanged at $old"
  exit 0
fi
if ! git merge-base --is-ancestor "$old" "$new"; then
  echo "::error::the original's $UPSTREAM_BRANCH no longer contains upstream ($old): history was rewritten"
  exit 1
fi

echo "upstream moved: $old..$new"
git log --oneline "$old..$new"

git checkout --quiet -B upstream-sync origin/main
msg="Merge upstream $(git rev-parse --short "$new") into main

Automatic upstream sync: $(git rev-list --count "$old..$new") new commit(s) from $UPSTREAM_URL"
if [ -n "${COMMIT_TRAILER:-}" ]; then
  msg="$msg

$COMMIT_TRAILER"
fi
if ! git merge --no-ff --no-edit -m "$msg" "$new"; then
  git merge --abort || true
  echo "::error::merge conflict between main and upstream"
  exit 1
fi

echo "running checks: $CHECK_CMD"
bash -c "$CHECK_CMD"

if [ "${SYNC_PUSH:-1}" = 0 ]; then
  printf 'UPSTREAM_SHA=%s\nMERGE_TREE=%s\n' "$new" "$(git rev-parse "HEAD^{tree}")" > "${SYNC_STATE:?}"
  echo "checks passed; push left to the caller"
  exit 0
fi
# both or neither: an `upstream` that moved without main would make every later run report
# "unchanged" and never retry the merge
git push --atomic origin "$new:refs/heads/upstream" upstream-sync:refs/heads/main
if [ "${SYNC_TAGS:-0}" = 1 ]; then
  git push --quiet origin 'refs/tags/v*:refs/tags/v*'
fi
echo "main updated to $(git rev-parse --short HEAD)"
