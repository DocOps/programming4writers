#!/bin/bash

# Global settings (based on environment variables)
TARGET_PATH="${UNMO_PATH:-.}"
EXT="${UNMO_EXT:-md}"
DAYS="${UNMO_DAYS:-365}"
SHOW_UNTRACKED="${SHOW_UNTRACKED:-false}"
SKIP_GIT_CHECK="${SKIP_GIT_CHECK:-false}"
QUIET="${UNMO_QUIET:-false}"
VERBOSE="${UNMO_VERBOSE:-false}"
DEBUG="${UNMO_DEBUG:-false}"

# also capture if --debug is passed anywhere in the args
if [[ "$DEBUG" = "true" || "$*" == *--debug* ]]; then
  echo "Debugging output enabled."
  set -x
fi

# Functions
show_help() {
  cat <<EOF
  
  Usage: ./check_unmodified.sh [OPTIONS] [DIRECTORY]

  Directory defaults to the current directory if not specified.

  Options:
    --help            Display this help and exit
    --ext EXT         Specify file extension (default: md)
    --days DAYS       Specify the timespan to check (default: 365)
    --untracked       Show files not tracked by Git
    --skip-git-check  Skip the Git check

EOF
}

message() {
  # $1: level (info, warn, error, debug)
  # if $1 is not exactly one of these, treat $1 as the content for info message
  # $2: content
  local level="$1"
  local string
  if [[ "$level" == "info" || "$level" == "warn" || "$level" == "error" || "$level" == "debug" ]]; then
    string="$2"
    shift
  else
    level="info"
    string="$1"
  fi
  case "$level" in
    "info")
      if [[ "$QUIET" = "false" ]]; then
        echo "INFO: $string"
      fi
      ;;
    "warn")
      if [[ "$QUIET" = "false" ]]; then
        echo "WARNING: $string" >&2
      fi
      ;;
    "error")
      echo "ERROR: $string" >&2
      ;;
    "debug")
      if [[ "$DEBUG" = "true" || "$VERBOSE" = "true" ]]; then
        echo "DEBUG: $string"
      fi
      ;;
    *)
      echo "$2"
      ;;
  esac
}

check_for_git() {
  if ! command -v git &>/dev/null; then
    echo "Error: Git is not installed." >&2
    echo "Disable Git check with --skip-git-check"
    exit 1
  fi
  # check for .git repository
  if [[ ! -d .git ]]; then
    echo "Error: Not a Git repository."
    exit 1
  fi
}

last_commit_date() {
  local file="$1"
  git log -1 --format="%ai" -- "$(realpath --relative-to="$(git rev-parse --show-toplevel)" "$file")" 2>/dev/null | cut -d ' ' -f 1
}

# Function to establish a local scope for main processing
main() {
  local target_path="$TARGET_PATH"
  local ext="$EXT"
  local days="$DAYS"
  local show_untracked="$SHOW_UNTRACKED"
  local skip_git_check="$SKIP_GIT_CHECK"
  local cutoff_date

  # Parse arguments
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --help)
        show_help
        exit 0
        ;;
      --ext)
        ext="$2"
        shift 2
        ;;
      --days)
        days="$2"
        shift 2
        ;;
      --untracked)
        show_untracked="true"
        shift
        ;;
      --skip-git-check)
        skip_git_check="true"
        shift
        ;;
      --quiet)
        QUIET="true"
        shift
        ;;
      --verbose)
        VERBOSE="true"
        shift
        ;;
      --debug)
        DEBUG="true"
        shift
        ;;
      *)
        if [[ "$1" == -* ]]; then
          echo "Error: Unknown option: $1" >&2
          exit 1
        fi      
        target_path="$1"
        break
        ;;
    esac
  done

  if [[ ! "$skip_git_check" = "true" ]]; then
    check_for_git
  fi

  # Ensure the directory exists
  if [[ ! -d "$target_path" ]]; then
    message "error" "Directory '$target_path' does not exist."
    exit 1
  fi

  # If $target_path is outside the current path, we need to navigate to it for the duration of the script
  if [[ "$target_path" != "." && "$target_path" != "$(pwd)" ]]; then
    cd "$target_path" || exit 1
  fi

  # Calculate the cutoff date in YYYY-MM-DD format
  cutoff_date=$(date -d "$days days ago" +%Y-%m-%d)

  # Determine the list of files to process
  local files
  if [[ "$show_untracked" = "true" ]]; then
    mssg="Searching for *.$ext files in $target_path, including untracked files,"
    files=$(find "$target_path" -type f -name "*.$ext")
  else
    mssg="Searching for *.$ext files in $target_path tracked by Git"
    files=$(git ls-files -- "$target_path" | grep -E "\.${ext}$")
  fi

  message "debug" "$mssg last committed before $cutoff_date..."

  # Check if no files are found
  if [[ -z "$files" || $(echo "$files" | wc -l) -eq 0 ]]; then
    message "info" "No files found."
    exit 0
  fi

  # Process the files
  while IFS= read -r file; do
    local last_commit_date_value
    last_commit_date_value=$(last_commit_date "$file")

    if [[ -z "$last_commit_date_value" && "$show_untracked" = "true" ]]; then
      echo "Untracked: $file"
    elif [[ "$last_commit_date_value" < "$cutoff_date" ]]; then
      echo "$file (Last committed: $last_commit_date_value)"
    fi
  done <<< "$files"
}

# Call the main function
main "$@"
