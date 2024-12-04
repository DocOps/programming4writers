#!/bin/bash

TARGET_PATH="."
EXT="md"
DAYS="365"
SHOW_UNTRACKED="false"

show_help() {
  cat <<EOF
  
  Usage: ./check_unmodified.sh [OPTIONS] [DIRECTORY]

  Directory defaults to the current directory if not specified.

  Options:
    --help          Display this help and exit
    --ext EXT       Specify the file extension to search for (default: $EXT)
    --days DAYS     Specify the number of days to check for (default: $DAYS)
    --untracked     Hide files not tracked by Git

EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --help)
      show_help
      exit 0
      ;;
    --ext)
      EXT="$2"
      shift 2
      ;;
    --days)
      DAYS="$2"
      shift 2
      ;;
    --untracked)
      SHOW_UNTRACKED="true"
      shift
      ;;
    *)
      if [[ "$1" == -* ]]; then
        echo "Error: Unknown option: $1" >&2
        exit 1
      fi      
      TARGET_PATH="$1"
      shift
      ;;
  esac
done

# Ensure the directory exists
if [[ ! -d "$TARGET_PATH" ]]; then
  echo "Error: Directory '$TARGET_PATH' does not exist."
  exit 1
fi

# Calculate the cutoff date in YYYY-MM-DD format
CUTOFF_DATE=$(date -d "$DAYS days ago" +%Y-%m-%d)

# Function to get the last commit date of a file
last_commit_date() {
  local file="$1"
  git log -1 --format="%ai" -- "$(realpath --relative-to="$(git rev-parse --show-toplevel)" "$file")" 2>/dev/null | cut -d ' ' -f 1
}

# Find files with the specified extension and check Git history
echo "Searching for *.$EXT files in $TARGET_PATH last committed before $CUTOFF_DATE..."
# use only Git-tracked paths
find "$TARGET_PATH" -type f -name "*.$EXT" -exec git ls-files {} \; | while read -r file; do
# find "$TARGET_PATH" -type f -name "*.$EXT" | while read -r file; do
  last_commit_date=$(last_commit_date "$file")
  
  # Skip files not tracked by Git
  if [[ -z "$last_commit_date" && "$SHOW_UNTRACKED" = "true" ]]; then
    echo "Not tracked by Git: $file"
    continue
  fi

  # Compare dates
  if [[ "$last_commit_date" < "$CUTOFF_DATE" ]]; then
    echo "Last modified before $CUTOFF_DATE: $file (Last committed: $last_commit_date)"
  fi
done
