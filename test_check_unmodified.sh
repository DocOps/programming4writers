#!/bin/bash

# Create a temporary directory
TMP_DIR=$(mktemp -d)
echo "Created temporary directory: $TMP_DIR"

# Navigate to the temporary directory
cd "$TMP_DIR" || exit 1

# Initialize a Git repository
git init >/dev/null
echo "Initialized empty Git repository in $TMP_DIR"

# Calculate dynamic dates
DATE_400_DAYS_AGO=$(date -d "400 days ago" +"%Y-%m-%dT12:00:00")
DATE_35_DAYS_AGO=$(date -d "35 days ago" +"%Y-%m-%dT12:00:00")
DATE_3_DAYS_AGO=$(date -d "3 days ago" +"%Y-%m-%dT12:00:00")

# Helper function to create and commit a file
create_and_commit_file() {
  local filepath="$1"
  local content="$2"
  local commit_date="$3"
  mkdir -p "$(dirname "$filepath")"
  echo "$content" > "$filepath"
  if [[ "$commit_date" == "nocommit" ]]; then
    return
  fi
  GIT_AUTHOR_DATE="$commit_date" GIT_COMMITTER_DATE="$commit_date" git add "$filepath"
  GIT_AUTHOR_DATE="$commit_date" GIT_COMMITTER_DATE="$commit_date" git commit -m "Add $filepath" >/dev/null
}

# Create and commit files with dynamic dates
create_and_commit_file "docs/old_file.md" "# Old Markdown File" "$DATE_400_DAYS_AGO"
create_and_commit_file "docs/recent_file.md" "# Recent Markdown File" "$DATE_35_DAYS_AGO"
create_and_commit_file "docs/latest_file.adoc" "= Latest AsciiDoc File" "$DATE_3_DAYS_AGO"
create_and_commit_file "docs/older_file.adoc" "= Older AsciiDoc File" "$DATE_400_DAYS_AGO"
create_and_commit_file "docs/untracked.adoc" "= Uncommitted AsciiDoc File" "nocommit"
create_and_commit_file "docs/untracked.md" "# Uncommitted Markdown File" "nocommit"

# Create a file without committing it (staged but not committed)
echo "Staged but not committed" > "staged.txt"
git add "staged.txt"

# Display the repository structure
echo "Test repository structure:"
tree "$TMP_DIR"

# Return the temporary directory path
echo "Temporary repository ready for testing."

# change back to the original directory
cd - || exit 1

declare -a commands
commands=("./check_unmodified.sh --untracked --skip-git-check $TMP_DIR")
commands+=("./check_unmodified.sh --ext adoc --days 2 --untracked --skip-git-check $TMP_DIR")
commands+=("./check_unmodified.sh --ext adoc --days 30 $TMP_DIR")
commands+=("./check_unmodified.sh --ext md --days 20 $TMP_DIR")
commands+=("./check_unmodified.sh --ext adoc --days 2 --untracked $TMP_DIR")

export UNMO_VERBOSE=true

# loop through commands printing the exact expression then executing it
for command in "${commands[@]}"; do
  echo ""
  echo "EXECUTING: $command"
  eval "$command"
done

# Clean up the temporary directory
rm -rf "$TMP_DIR"
unset UNMO_VERBOSE

