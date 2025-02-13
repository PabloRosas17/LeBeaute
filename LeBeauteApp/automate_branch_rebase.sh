#!/bin/bash

# Branches to skip
SKIP_BRANCHES=("unique/time-capsule" "gh-pages")

# Function to rebase a branch onto main
rebase_branch() {
  local branch="$1"

  # Skip the branch if it's in the skip list
  if [[ " ${SKIP_BRANCHES[@]} " =~ " ${branch} " ]]; then
    echo "Skipping rebase for branch: $branch"
    return
  fi

  echo "Rebasing $branch onto main..."
  git checkout "$branch" || { echo "Failed to checkout $branch"; exit 1; }

  # Ensure the branch is up to date with the remote
  git fetch origin

  # Check if the branch is up to date with main
  git merge-base --is-ancestor main "$branch" && { echo "$branch is already up to date with main"; return; }

  # Force rebase to ensure it's up to date
  git rebase origin/main || { echo "Rebase failed for $branch"; exit 1; }

  # If no changes after rebase, force it (to avoid errors with an empty merge)
  if git diff --quiet; then
    echo "No changes detected, forcing rebase for $branch..."
    git reset --hard origin/"$branch"
  fi

  # Push the rebased branch
  git push origin "$branch" --force-with-lease || { echo "Failed to push $branch"; exit 1; }

  echo "$branch rebased and pushed successfully!"
}

# Main function to loop through the branches
main() {
  # Get a list of all branches, excluding the ones in the skip list
  for branch in $(git branch --list | sed 's/^[ *]*//'); do
    # Skip branches in the skip list
    if [[ ! " ${SKIP_BRANCHES[@]} " =~ " ${branch} " ]]; then
      rebase_branch "$branch"
    fi
  done
}

# Run the main function
main

