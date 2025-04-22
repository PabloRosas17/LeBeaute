#!/bin/bash

# ========== Define Absolute Paths ==========
SCRIPT_DIR=$(dirname "$(realpath "$0")")
TOKENS_DIR="$SCRIPT_DIR/../tokens"
TEMPLATE_DIR="$SCRIPT_DIR/../template"
LOGS_DIR="$SCRIPT_DIR/../logs/logged"
BACKUP_DIR="$SCRIPT_DIR/.backup"
BUNDLE_DIR="$BACKUP_DIR/.bundle"
ISSUES_BACKUP_DIR="$BACKUP_DIR/.issues"
BRANCHES_BACKUP_DIR="$BACKUP_DIR/.branches"
PATCH_DIR="$SCRIPT_DIR/.patches"

# ========== Ensure Required Directories Exist ==========
for dir in "$TOKENS_DIR" "$TEMPLATE_DIR" "$LOGS_DIR" "$ISSUES_BACKUP_DIR" "$BRANCHES_BACKUP_DIR" "$BUNDLE_DIR" "$PATCH_DIR"; do
  [ ! -d "$dir" ] && echo "!!! Required directory missing: $dir" && exit 1
done

# ========== Load Repository Configuration ==========
CONFIG_PATH="$TOKENS_DIR/LeBeaute-repository.conf"
[ ! -f "$CONFIG_PATH" ] && echo "!!! Missing configuration file: $CONFIG_PATH" && exit 1

REPO_NAME=$(grep -m 1 '^[^#]*REPO_NAME=' "$CONFIG_PATH" | cut -d'=' -f2 | tr -d '[:space:]' | sed 's/#.*//')
[ -z "$REPO_NAME" ] && echo ">>> REPO_NAME is not set or malformed in: $CONFIG_PATH" && exit 1
echo ">>> REPO_NAME loaded as: $REPO_NAME"

# ========== Load GitHub Token ==========
GH_TOKEN=$(grep -m 1 '^GITHUB_TOKEN=' "$TOKENS_DIR/LeBeaute-secrets.conf" | cut -d'=' -f2 | tr -d '[:space:]' | sed -E 's/#.*//; s/^"(.*)"$/\1/')
[ -z "$GH_TOKEN" ] && echo ">>> GH_TOKEN is not set or malformed!" && exit 1
echo ">>> GH_TOKEN loaded successfully."

# ========== Logging Setup ==========
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
LOGFILE="$LOGS_DIR/${REPO_NAME}-refresh-$TIMESTAMP.log"
mkdir -p "$(dirname "$LOGFILE")"
exec > >(tee "$LOGFILE") 2>&1
echo ">>> Logging initialized to: $LOGFILE"

# ========== Load Full Config and Secrets ==========
REPO_CONFIG="$TOKENS_DIR/${REPO_NAME}-repository.conf"
[ -f "$REPO_CONFIG" ] && source "$REPO_CONFIG" || { echo "!!! Expected repo config not found: $REPO_CONFIG"; exit 1; }

SECRETS_PATH="$TOKENS_DIR/${REPO_NAME}-secrets.conf"
[ -f "$SECRETS_PATH" ] && source "$SECRETS_PATH" || echo ">>> No secrets file found at $SECRETS_PATH — skipping"

# ========== GitHub Auth Check ==========
echo ">>> Checking GitHub authentication..."
if ! gh auth status &>/dev/null; then
  echo ">>> Not authenticated. Skipping token login since you're using stored authentication."
else
  echo ">>> Already authenticated with GitHub."
fi

# ========== Backup: Issues ==========
echo ">>> Backing up issues..."
ISSUES_BACKUP="$ISSUES_BACKUP_DIR/${REPO_NAME}-issues-backup.json"
mkdir -p "$(dirname "$ISSUES_BACKUP")"
gh issue list --repo "$GITHUB_USER/$REPO_NAME" --json title,body,number --limit 1000 > "$ISSUES_BACKUP"

# ========== Backup: Branches ==========
echo ">>> Backing up all branches (local and remote)..."
BRANCHES_BACKUP="$BRANCHES_BACKUP_DIR/${REPO_NAME}-branches-backup.txt"
mkdir -p "$(dirname "$BRANCHES_BACKUP")"
git branch -r | sed 's/origin\///' > "$BRANCHES_BACKUP"

# ========== Backup: Repository ==========
echo ">>> Backing up entire repo..."
mkdir -p "$BUNDLE_DIR"
BACKUP_BUNDLE="$BUNDLE_DIR/${REPO_NAME}-backup.bundle"
LOCK_FILE="$BACKUP_BUNDLE.lock"

# Clean lock file if it somehow already exists
[ -f "$LOCK_FILE" ] && echo ">>> Removing lock file: $LOCK_FILE" && rm "$LOCK_FILE"

# Convert path to Windows-native to avoid Git lock bug with ~
WIN_BUNDLE_PATH=$(cygpath -w "$BACKUP_BUNDLE")
git bundle create "$WIN_BUNDLE_PATH" --all

echo ">>> Backup complete. Bundle saved to $BACKUP_BUNDLE"

# ========== Step 4: Save Last $NUM_COMMITS ==========
echo ">>> Saving all commits to patches..."
NUM_COMMITS=$(git rev-list --count HEAD)
echo ">>> NUM_COMMITS: $NUM_COMMITS"  # Debugging line

# Check if the temp-save branch exists, create or switch to it
if git show-ref --verify --quiet refs/heads/temp-save; then
  echo ">>> Switching to existing temp-save branch..."
  git checkout temp-save || git switch temp-save
else
  echo ">>> Creating new temp-save branch..."
  git checkout -b temp-save || git switch temp-save
fi

# Check if we are on the correct branch
CURRENT_BRANCH=$(git symbolic-ref --short HEAD)
echo ">>> Current branch: $CURRENT_BRANCH"  # Debugging line

# Save patches only if there are commits
if [ "$NUM_COMMITS" -gt 0 ]; then
  mkdir -p "$PATCH_DIR"
  git format-patch --root -o "$PATCH_DIR"
  echo ">>> Patches saved to $PATCH_DIR"
else
  echo ">>> No commits to create patches from."
fi


# # ========== Step 5: Delete GitHub Repo ==========
# echo ">>> Deleting GitHub repo..."
# gh repo delete "$GITHUB_USER/$REPO_NAME" --yes

# # ========== Step 6: Create Fresh GitHub Repo ==========
# echo ">>> Creating fresh GitHub repo..."
# gh repo create "$GITHUB_USER/$REPO_NAME" --"$VISIBILITY" --confirm

# # ========== Step 7: Clone Fresh Repo ==========
# echo ">>> Cloning fresh repo..."
# cd ..
# rm -rf "$REPO_NAME"
# git clone "git@github.com:$GITHUB_USER/$REPO_NAME.git"
# cd "$REPO_NAME" || exit 1

# # ========== Step 8: Initial Commit (Fresh Start) ==========
# echo "# $REPO_NAME" > README.md
# git add README.md
# git commit -m "Initial commit - fresh start"
# git branch -M main
# git push origin main

# # ========== Step 9: Apply Saved Patches ==========
# echo ">>> Applying patches with date: $COMMIT_DATE"
# for patch in "$PATCH_DIR"/*.patch; do
#   echo "Applying $(basename "$patch")..."
#   GIT_COMMITTER_DATE="$COMMIT_DATE" GIT_AUTHOR_DATE="$COMMIT_DATE" \
#   git am --committer-date-is-author-date "$patch" || {
#     echo "Patch failed: $patch"
#     exit 1
#   }
# done

# git push origin main

# # ========== Step 10: Fetch and Push Legacy Branch ==========
# echo ">>> Fetching and pushing legacy branch..."
# git fetch "$ORIGINAL_DIR/$BACKUP_BUNDLE" legacy:legacy
# git push origin legacy

# # ========== Final Completion ==========
# echo ">>> [$REPO_NAME] refresh complete!"
