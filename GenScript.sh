#!/bin/bash
# ============================================
# 🚀 Gen Script AI Terminal Assistance
# Author: Rudra Prasad Baral
# Description: AI-powered terminal assistant using Google Gemini API
# ============================================

# --------------------------------------------
# Load environment variables from .env file
# --------------------------------------------
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "⚠️  .env file not found! Please create one with GEMINI_API_KEY and GEMINI_API_URL."
    exit 1
fi

# --------------------------------------------
# Validate Environment Variables
# --------------------------------------------
if [[ -z "$GEMINI_API_KEY" || -z "$GEMINI_API_URL" ]]; then
    echo "❌ Missing GEMINI_API_KEY or GEMINI_API_URL in .env file."
    exit 1
fi

# --------------------------------------------
# Database File Paths
# --------------------------------------------
HISTORY_FILE="./history.db"
BOOKMARK_FILE="./bookmarks.db"

# Ensure history and bookmark files exist
touch "$HISTORY_FILE"
touch "$BOOKMARK_FILE"

# --------------------------------------------
# Function: Call Gemini API to get shell command
# --------------------------------------------
ask_gemini() {
    local input="$1"
    local response=$(curl -s -X POST "${GEMINI_API_URL}?key=${GEMINI_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{
            \"contents\": [
                {
                    \"role\": \"user\",
                    \"parts\": [{\"text\": \"${input}. Give only the shell command without explanation.\"}]
                }
            ]
        }"
    )

    # Check for API errors
    if [[ -z "$response" ]]; then
        echo "⚠️ Error: Empty response from Gemini API"
        return 1
    fi

    # Extract the command text using jq
    local command=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text' 2>/dev/null)

    if [[ -z "$command" || "$command" == "null" ]]; then
        echo "⚠️ Error: Invalid response or command not found in API output."
        return 1
    fi

    echo "$command"
}

# --------------------------------------------
# Function: Save command to history
# --------------------------------------------
save_to_history() {
    echo "$1" >> "$HISTORY_FILE"
}

# --------------------------------------------
# Function: Save command to bookmarks
# --------------------------------------------
save_to_bookmarks() {
    echo "$1" >> "$BOOKMARK_FILE"
    echo "✅ Command bookmarked!"
}

# --------------------------------------------
# Function: Show bookmarked commands
# --------------------------------------------
show_bookmarks() {
    echo "📚 Bookmarked Commands:"
    cat "$BOOKMARK_FILE"
}

# --------------------------------------------
# Function: Suggest similar commands from history
# --------------------------------------------
suggest_from_history() {
    local keyword="$1"
    echo "🕵️ Similar commands found:"
    grep -i "$keyword" "$HISTORY_FILE" || echo "No similar commands found."
}

# --------------------------------------------
# Function: Confirm and execute a command
# --------------------------------------------
confirm_and_execute() {
    local command="$1"
    echo "Run this command? [y/N]: $command"
    read -r confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        eval "$command"
    else
        echo "❌ Skipped."
    fi
}

# --------------------------------------------
# Main Interactive Loop
# --------------------------------------------
echo "🤖 Welcome to Gen Script AI Terminal Assistance"
echo "Type 'exit' to quit, 'bookmarks' to view saved commands."

while true; do
    echo -n "🤖 AI-Terminal$ "
    read -r user_input

    # Exit condition
    if [[ "$user_input" == "exit" ]]; then
        echo "👋 Goodbye!"
        break
    fi

    # Show bookmarks
    if [[ "$user_input" == "bookmarks" ]]; then
        show_bookmarks
        continue
    fi

    # Bookmark a command manually
    if [[ "$user_input" == bookmark* ]]; then
        cmd="${user_input#bookmark }"
        save_to_bookmarks "$cmd"
        continue
    fi

    # Get command from Gemini API
    ai_command=$(ask_gemini "$user_input")

    if [[ $? -ne 0 ]]; then
        echo "⚠️ Failed to get a valid response from Gemini API."
        continue
    fi

    echo "⚙️ Suggested: $ai_command"

    # Suggest similar commands
    suggest_from_history "$(echo "$ai_command" | awk '{print $1}')"

    # Confirm and execute
    confirm_and_execute "$ai_command"

    # Save to history
    save_to_history "$ai_command"
done
