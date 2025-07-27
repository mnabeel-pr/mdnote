# mdnote

A minimal CLI tool for capturing daily notes and tasks in Markdown. Designed for developers who live in the terminal and work with Markdown-based note systems like Obsidian, Dendron, or plain Markdown vaults.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Bash](https://img.shields.io/badge/bash-4.0%2B-green.svg)

## Features

- 📝 **Quick Capture**: Add journal entries and tasks from the terminal without opening your editor
- 📅 **Daily Notes**: Automatically creates and organizes daily notes with consistent structure
- ✅ **Task Management**: Add TODOs, mark them complete with timestamps, and list all open tasks
- 🔍 **Interactive Search**: Use `fzf` to quickly find and complete tasks from any day (optional feature)
- ⚙️ **Configurable**: Set your vault path, daily notes location, and preferred editor
- 🚀 **Fast & Minimal**: Pure bash script with minimal dependencies

## Quick Start

```bash
# Install mdnote
git clone https://github.com/mnabeel-pr/mdnote.git
cd mdnote
./install.sh

# Configure your vault path
vim ~/.config/mdnote/config

# Start using mdnote
mdnote "Started working on the new feature"
mdnote -t "Review pull request #123"
mdnote --done  # Mark a task complete
```

## Installation

### Prerequisites

- Bash 4.0 or higher
- Basic Unix tools: `grep`, `awk`, `sed`
- `fzf` (optional - only needed for the `--done` command)

### Install Script

The easiest way to install mdnote:

```bash
git clone https://github.com/mnabeel-pr/mdnote.git
cd mdnote
./install.sh
```

The install script will:
- Copy `mdnote` to `/usr/local/bin`
- Create a config directory at `~/.config/mdnote`
- Copy the example configuration file
- Auto-detect your preferred editor (or default to nano)

### Manual Installation

```bash
# Copy the script
cp mdnote.sh /usr/local/bin/mdnote
chmod +x /usr/local/bin/mdnote

# Create config directory
mkdir -p ~/.config/mdnote

# Copy and edit the config
cp config.example ~/.config/mdnote/config
```

## Configuration

mdnote looks for configuration in these locations (in order):
1. `~/.config/mdnote/config` (recommended)
2. `~/.mdnoterc`
3. `./.mdnoterc` (project-specific)

### Environment Variables

You can also configure mdnote using environment variables:
- `MDNOTE_VAULT_PATH`: Path to your notes vault
- `MDNOTE_DAILY_DIR`: Daily notes directory (relative to vault)
- `MDNOTE_EDITOR`: Your preferred text editor (overrides config file)

### Example Configuration

```bash
# Path to your notes vault (required)
VAULT_PATH="$HOME/notes"

# Daily notes directory relative to vault path
DAILY_DIR_NAME="Journal/Daily"

# Your preferred text editor (required for --edit command)
EDITOR_CMD="nano"
```

## Usage

### Adding Journal Entries

```bash
# Add a quick note to today's journal
mdnote "Had a great meeting with the team"

# Quotes are important for multi-word entries
mdnote "Started working on the API refactor"
```

### Managing Tasks

```bash
# Add a new TODO
mdnote -t "Review pull request #123"
mdnote -t "Update documentation for v2.0"

# Mark a TODO as complete (requires fzf)
mdnote --done
mdnote -d

# List all incomplete TODOs across all daily notes
mdnote --list
mdnote -l
```

### Other Commands

```bash
# Open today's note in your editor
mdnote --edit
mdnote -e

# Show help
mdnote --help
mdnote -h
```

## Daily Note Structure

mdnote creates daily notes with this structure:

```markdown
---
date: 2025-01-15
tags: [daily]
---

# 2025-01-15

## Journal
- [2025-01-15 09:15] Started working on the new feature
- [2025-01-15 14:30] Had a great meeting with the team

## Tasks
- [ ] #TODO Review pull request #123
- [x] #TODO Update documentation  ✅ `10:30` 📅 2025-01-15
```

## Tips & Tricks

### Working Without fzf

If you don't have `fzf` installed, you can still use all mdnote features except `--done`. To mark tasks complete without fzf:
1. Use `mdnote --edit` to open today's note
2. Manually change `- [ ]` to `- [x]` and add completion timestamp
3. Or use `mdnote --list` to see all tasks, then edit the specific daily note

### Integration with Note-Taking Apps

mdnote works great with:
- **Obsidian**: Point `VAULT_PATH` to your Obsidian vault
- **VS Code**: Use with Markdown extensions
- **Plain Markdown**: Works with any Markdown-based system

### Workflow Examples

**Morning Routine:**
```bash
mdnote "Morning standup notes: Team discussed..."
mdnote -t "Code review for Alice's PR"
mdnote -t "Fix bug in authentication flow"
```

**End of Day:**
```bash
mdnote --done  # Complete finished tasks
mdnote "Daily summary: Accomplished X, Y, Z"
mdnote --list  # Review remaining tasks
```

### Development

```bash
# Clone the repo
git clone https://github.com/mnabeel-pr/mdnote.git
cd mdnote

# Make your changes
vim mdnote.sh

# Test locally
./mdnote.sh "Test note"
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

Made with ❤️ for developers who prefer the terminal
