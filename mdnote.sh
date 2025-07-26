#!/bin/bash

VAULT_PATH="/Users/mnabeel/notes/second_brain"
DAILY_DIR="$VAULT_PATH/04 - Journal/Daily"
DATE=$(date +%Y-%m-%d)
FILE="$DAILY_DIR/$DATE.md"

mkdir -p "$DAILY_DIR"

# Create daily note if not present
if [ ! -f "$FILE" ]; then
  cat <<EOF >"$FILE"
---
date: $DATE
tags: [daily]
---

# $DATE

## Journal

## Tasks
EOF
fi

ensure_section() {
  local section="$1"
  if ! grep -q "^## $section" "$FILE"; then
    echo -e "\n## $section\n" >>"$FILE"
  fi
}

add_todo() {
  # Check if there are arguments before shifting
  if [ $# -lt 2 ]; then
    echo "⚠️  No task description provided."
    echo "Usage: qn -td \"Describe the task here\""
    exit 1
  fi
  
  shift
  local TASK_TEXT="$*"

  if [ -z "$TASK_TEXT" ]; then
    echo "⚠️  No task description provided."
    echo "Usage: qn -td \"Describe the task here\""
    exit 1
  fi

  ensure_section "Tasks"

  # Append at bottom of Tasks section
  local TEMP_FILE="$FILE.tmp"
  if ! awk -v task="- [ ] #TODO $TASK_TEXT" '
    BEGIN { in_tasks=0; added=0 }
    {
      if ($0 ~ /^## Tasks/) {
        in_tasks=1;
        print $0;
        next;
      }
      
      if (in_tasks && $0 ~ /^## /) {
        # Reached next section after Tasks
        if (!added) {
          print "";
          print task;
          added=1;
        }
        in_tasks=0;
      }
      
      print $0;
    }
    END {
      if (in_tasks && !added) {
        print "";
        print task;
      }
    }
  ' "$FILE" >"$TEMP_FILE"; then
    echo "⚠️ Error: Failed to create temporary file."
    return 1
  fi
  
  # Safely move temp file to original
  if ! mv "$TEMP_FILE" "$FILE"; then
    echo "⚠️ Error: Failed to update $FILE. Your changes were not saved."
    rm -f "$TEMP_FILE" # Clean up
    return 1
  fi

  echo "📝 TODO added under ## Tasks in $FILE"
}

add_journal_note() {
  local NOTE="$1"
  ensure_section "Journal"

  # Append at bottom of Journal section
  local TEMP_FILE="$FILE.tmp"
  if ! awk -v entry="- [$DATE $(date +%H:%M)] $NOTE" '
    BEGIN { in_journal=0; added=0 }
    {
      if ($0 ~ /^## Journal/) {
        in_journal=1;
        print $0;
        next;
      }
      
      if (in_journal && $0 ~ /^## /) {
        # Reached next section after Journal
        if (!added) {
          print "";
          print entry;
          added=1;
        }
        in_journal=0;
      }
      
      print $0;
    }
    END {
      if (in_journal && !added) {
        print "";
        print entry;
      }
    }
  ' "$FILE" >"$TEMP_FILE"; then
    echo "⚠️ Error: Failed to create temporary file."
    return 1
  fi
  
  # Safely move temp file to original
  if ! mv "$TEMP_FILE" "$FILE"; then
    echo "⚠️ Error: Failed to update $FILE. Your changes were not saved."
    rm -f "$TEMP_FILE" # Clean up
    return 1
  fi

  echo "🖋️ Note added under ## Journal in $FILE"
}

mark_task_done_anywhere() {
  # Check if fzf is installed
  if ! command -v fzf &> /dev/null; then
    echo "⚠️ fzf is not installed. Please install it to use this feature."
    echo "Visit https://github.com/junegunn/fzf for installation instructions."
    return 1
  fi
  
  # Find todos
  local todo_list=$(grep -r '^[-*] \[ \] .*#TODO' "$DAILY_DIR"/*.md 2>/dev/null)
  
  if [ -z "$todo_list" ]; then
    echo "❌ No #TODOs found in any daily notes."
    return 1
  fi
  
  # Use fzf for selection
  local selected=$(echo "$todo_list" | fzf --prompt="Mark #TODO as done > " --no-multi)

  if [ -z "$selected" ]; then
    echo "❌ No task selected."
    return 1
  fi
  
  # Extract filepath and line
  local filepath="${selected%%:*}"
  local line_with_prefix="${selected#*:}"
  local taskline="${line_with_prefix# }" # remove leading space if any
  
  # For debugging
  echo "Selected file: $filepath"
  echo "Selected task: $taskline"
  
  # Create the replacement line
  local timestamp="✅ \`$(date +%H:%M)\`"
  local date_stamp="📅 $(date +%Y-%m-%d)"
  local done_line="${taskline/\[ \]/[x]}  $timestamp $date_stamp"
  
  # Create a temporary file
  local TEMP_FILE="$filepath.tmp"
  
  # Process the file line by line for exact matching
  while IFS= read -r line; do
    if [ "$line" = "$taskline" ]; then
      echo "$done_line" >> "$TEMP_FILE"
    else
      echo "$line" >> "$TEMP_FILE"
    fi
  done < "$filepath"
  
  # Check if files differ
  if ! diff -q "$filepath" "$TEMP_FILE" >/dev/null; then
    # Changes were made, apply them
    if mv "$TEMP_FILE" "$filepath"; then
      echo "✅ Task marked as done in $filepath:"
      echo "   $done_line"
    else
      echo "⚠️ Error: Failed to update $filepath."
      rm -f "$TEMP_FILE"
      return 1
    fi
  else
    echo "⚠️ Error: No changes made. Task not found exactly as shown."
    rm -f "$TEMP_FILE"
    return 1
  fi
}

list_all_todos() {
  echo "📝 Incomplete #TODOs across all daily notes:"
  echo "--------------------------------------------"

  grep -r '^[-*] \[ \] .*#TODO' "$DAILY_DIR"/*.md | while IFS=: read -r filepath line; do
    filename=$(basename "$filepath")
    echo "• [$filename] $line"
  done
}

print_help() {
  echo "📒 qn - Daily Note CLI"
  echo ""
  echo "Usage:"
  echo "  qn \"Note content\"        → Append journal note to today's file"
  echo "  qn -td \"Task desc\"        → Add new #TODO under ## Tasks"
  echo "  qn --done or -d           → Mark a #TODO as done (from any day)"
  echo "  qn --list or -l           → List all incomplete #TODOs"
  echo "  qn --edit or -e           → Open today's note in nvim"
  echo "  qn --help or -h           → Show this help message"
}

case "$1" in
-td)
  add_todo "$@"
  ;;
--done | -d)
  mark_task_done_anywhere
  ;;
--list | -l)
  list_all_todos
  ;;
--edit | -e)
  nvim "$FILE"
  ;;
--help | -h)
  print_help
  ;;
*)
  if [[ "$1" == -* ]]; then
    echo "⚠️ Unknown option: $1"
    print_help
  elif [[ "$#" -eq 1 ]]; then
    add_journal_note "$1"
  else
    echo "⚠️ Please quote your note content."
    echo "Example: qn \"Started writing task manager script\""
  fi
  ;;
esac
