#!/bin/bash

# mdnote - A minimal CLI tool for capturing daily notes and tasks in Markdown

set -euo pipefail

# Default configuration
DEFAULT_VAULT_PATH="$HOME/notes"
DEFAULT_DAILY_DIR="Journal/Daily"

# Configuration file paths (in order of precedence)
CONFIG_PATHS=(
    "$HOME/.config/mdnote/config"
    "$HOME/.mdnoterc"
    ".mdnoterc"
)

# Load configuration
load_config() {
    # Start with defaults
    VAULT_PATH="${MDNOTE_VAULT_PATH:-$DEFAULT_VAULT_PATH}"
    DAILY_DIR_NAME="${MDNOTE_DAILY_DIR:-$DEFAULT_DAILY_DIR}"
    EDITOR_CMD="${MDNOTE_EDITOR:-}"
    ADD_BLANK_LINES="${MDNOTE_ADD_BLANK_LINES:-true}"
    
    # Try to load from config files
    for config_file in "${CONFIG_PATHS[@]}"; do
        if [ -f "$config_file" ]; then
            # shellcheck source=/dev/null
            source "$config_file"
            break
        fi
    done
    
    # Resolve full paths
    DAILY_DIR="$VAULT_PATH/$DAILY_DIR_NAME"
    
    # Validate configuration
    if [ ! -d "$VAULT_PATH" ]; then
        echo "⚠️  Error: Vault path '$VAULT_PATH' does not exist."
        echo ""
        echo "Please set up mdnote by:"
        echo "  1. Setting MDNOTE_VAULT_PATH environment variable, or"
        echo "  2. Creating a config file at ~/.config/mdnote/config"
        echo ""
        echo "Example config file:"
        echo "  VAULT_PATH=\"$HOME/notes\""
        echo "  DAILY_DIR_NAME=\"Journal/Daily\""
        echo "  EDITOR_CMD=\"nano\""
        exit 1
    fi
    
    # Set default editor if not configured
    if [ -z "$EDITOR_CMD" ]; then
        EDITOR_CMD="not-configured"
    fi
}

# Load configuration at startup
load_config

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
    echo "Usage: mdnote -t \"Describe the task here\""
    exit 1
  fi
  
  shift
  local TASK_TEXT="$*"

  if [ -z "$TASK_TEXT" ]; then
    echo "⚠️  No task description provided."
    echo "Usage: mdnote -t \"Describe the task here\""
    exit 1
  fi

  ensure_section "Tasks"

  # Append at bottom of Tasks section
  local TEMP_FILE="$FILE.tmp"
  if ! awk -v task="- [ ] #TODO $TASK_TEXT" -v add_blank="$ADD_BLANK_LINES" '
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
          if (add_blank == "true") print "";
          print task;
          added=1;
        }
        in_tasks=0;
      }
      
      print $0;
    }
    END {
      if (in_tasks && !added) {
        if (add_blank == "true") print "";
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
  if ! awk -v entry="- ($(date +%H:%M) | $DATE) → $NOTE" -v add_blank="$ADD_BLANK_LINES" '
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
          if (add_blank == "true") print "";
          print entry;
          added=1;
        }
        in_journal=0;
      }
      
      print $0;
    }
    END {
      if (in_journal && !added) {
        if (add_blank == "true") print "";
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
  local done_line="${taskline/\[ \]/[x]} | (Completed at $timestamp $date_stamp)"
  
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
  echo "📒 mdnote - Daily Note CLI"
  echo ""
  echo "Usage:"
  echo "  mdnote \"Note content\"     → Append journal note to today's file"
  echo "  mdnote -t \"Task desc\"    → Add new #TODO under ## Tasks"
  echo "  mdnote --done or -d       → Mark a #TODO as done (from any day)"
  echo "  mdnote --list or -l       → List all incomplete #TODOs"
  echo "  mdnote --edit or -e       → Open today's note in $EDITOR_CMD"
  echo "  mdnote --help or -h       → Show this help message"
  echo ""
  echo "Configuration:"
  echo "  Vault: $VAULT_PATH"
  echo "  Daily notes: $DAILY_DIR"
  if [ "$EDITOR_CMD" = "not-configured" ]; then
    echo "  Editor: ⚠️  Not configured (set EDITOR_CMD in config)"
  else
    echo "  Editor: $EDITOR_CMD"
  fi
  echo "  Blank lines between entries: $ADD_BLANK_LINES"
}

case "$1" in
-t)
  add_todo "$@"
  ;;
--done | -d)
  mark_task_done_anywhere
  ;;
--list | -l)
  list_all_todos
  ;;
--edit | -e)
  if [ "$EDITOR_CMD" = "not-configured" ]; then
    echo "⚠️  Error: No editor configured."
    echo ""
    echo "Please configure an editor in your mdnote config file:"
    echo "  EDITOR_CMD=\"nano\"  # or vim, nvim, code, etc."
    echo ""
    echo "Config file location: ~/.config/mdnote/config"
    exit 1
  fi
  
  if ! command -v "$EDITOR_CMD" &> /dev/null; then
    echo "⚠️  Error: Editor '$EDITOR_CMD' not found."
    echo ""
    echo "Please install $EDITOR_CMD or configure a different editor in:"
    echo "  ~/.config/mdnote/config"
    exit 1
  fi
  
  $EDITOR_CMD "$FILE"
  ;;
--help | -h)
  print_help
  ;;
*)
  if [[ "$1" == -* ]]; then
    echo "⚠️ Unknown option: $1"
    echo ""
    print_help
    exit 1
  elif [[ "$#" -eq 1 ]]; then
    add_journal_note "$1"
  else
    echo "⚠️ Please quote your note content."
    echo "Example: mdnote \"Started writing task manager script\""
    exit 1
  fi
  ;;
esac
