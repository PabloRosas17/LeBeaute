import subprocess

# Configuration - adjust the path as needed
repo_name = "LeBeaute"
backup_file = f".ocd/backups/{repo_name}-branches-backup.txt"
repo_url = f"git@github.com:PabloRosas17/{repo_name}.git"

# Function to restore branches
def restore_branches():
    try:
        # Read branch names from the backup file
        with open(backup_file, 'r') as f:
            branches = f.readlines()

        # Remove newline characters and filter out any empty lines
        branches = [branch.strip() for branch in branches if branch.strip()]

        # Clone the fresh repo
        subprocess.check_call(['git', 'clone', repo_url])
        subprocess.check_call(['git', 'checkout', 'main'])
        
        # Restore each branch
        for branch in branches:
            print(f"Restoring branch: {branch}")
            subprocess.check_call(['git', 'checkout', '-b', branch])
            subprocess.check_call(['git', 'push', 'origin', branch])

    except Exception as e:
        print(f"Error occurred during branch restoration: {e}")
        return False
    return True

if __name__ == "__main__":
    if restore_branches():
        print(f"Branches for {repo_name} restored successfully!")
    else:
        print(f"Failed to restore branches for {repo_name}.")
