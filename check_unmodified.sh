main() {
  local target_path="$TARGET_PATH"
  local ext="$EXT"
  local days="$DAYS"
  local show_untracked="$SHOW_UNTRACKED"

  # Parse options
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
      *)
        if [[ "$1" == -* ]]; then
          echo "Error: Unknown option: $1" >&2
          exit 1
        fi      
        target_path="$1"
        shift
        ;;
    esac
  done

  if [[ ! "$skip_git_check" = "true" ]]; then
    check_for_git
  fi

  # Ensure the directory exists
  if [[ ! -d "$target_path" ]]; then
    echo "Error: Directory '$target_path' does not exist."
    exit 1
  fi

  # Calculate the cutoff date in YYYY-MM-DD format
  local cutoff_date
  cutoff_date=$(date -d "$days days ago" +%Y-%m-%d)

  # Determine the list of files to process
  local files
  if [[ "$show_untracked" = "true" ]]; then
    echo "Searching for *.$ext files in $target_path, including untracked files..."
    files=$(find "$target_path" -type f -name "*.$ext")
  else
    echo "Searching for *.$ext files in $target_path tracked by Git last committed before $cutoff_date..."
    files=$(git ls-files -- "$target_path" | grep -E "\.${ext}$")
  fi

  # Process the files
  while IFS= read -r file; do
    local last_commit_date_value
    last_commit_date_value=$(last_commit_date "$file")

    # For untracked files, last_commit_date_value will be empty
    if [[ -z "$last_commit_date_value" && "$show_untracked" = "true" ]]; then
      echo "Not tracked by Git: $file"
    elif [[ "$last_commit_date_value" < "$cutoff_date" ]]; then
      echo "Last modified before $cutoff_date: $file (Last committed: $last_commit_date_value)"
    fi
  done <<< "$files"
}
