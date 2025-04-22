import json
import subprocess

# Configuration - adjust the path as needed
repo_name = "LeBeaute"
issues_backup_file = f".ocd/backups/{repo_name}-issues-backup.json"
repo_url = f"git@github.com:PabloRosas17/{repo_name}.git"

# GitHub Authentication Token (can be sourced from secrets file or environment variable)
github_token = "your_github_token_here"  # Update this with the correct token or load from a secrets file

# Function to restore issues
def restore_issues():
    try:
        # Load issues from backup file
        with open(issues_backup_file, 'r') as f:
            issues = json.load(f)

        # Loop through each issue and recreate it
        for issue in issues:
            title = issue.get("title")
            body = issue.get("body")
            issue_number = issue.get("number")
            print(f"Restoring issue #{issue_number}: {title}")

            # Use GitHub API to create the issue
            subprocess.check_call([
                'gh', 'issue', 'create',
                '--repo', f'PabloRosas17/{repo_name}',
                '--title', title,
                '--body', body,
                '--assignee', 'me',  # Optionally assign yourself or specify assignees
                '--label', 'bug',  # You can add labels as needed
                '--token', github_token
            ])
        print(f"Restoration of issues for {repo_name} completed successfully!")

    except Exception as e:
        print(f"Error occurred during issue restoration: {e}")
        return False

    return True

if __name__ == "__main__":
    restore_issues()
