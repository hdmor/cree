#!/bin/bash

# Define Unicode vertical line character
VERTICAL_LINE=$'\u2502'

# ANSI color codes
COLOR_RESET='\e[0m'
COLOR_BLUE='\e[34m'
COLOR_GREEN='\e[32m'
COLOR_RED='\e[31m'
COLOR_YELLOW='\e[33m'
COLOR_CYAN='\e[36m'
COLOR_DEFAULT='\e[39m' # Default terminal color

# Function to check if a file is a text file using 'file' command
is_text_file() {
    local filepath="$1"
    file -b "$filepath" | grep -q "text"
}

# Function to check if a file is an empty file using 'file' command
is_empty_file() {
    local filepath="$1"
    file -b "$filepath" | grep -q "empty"
}

# Function to check if a file is an image file
is_image_file() {
    local filepath="$1"
    file -b "$filepath" | grep -qE "image"
}

# Function to check if a file is a PDF file
is_pdf_file() {
    local filepath="$1"
    file -b "$filepath" | grep -qE "PDF"
}

# Function to get line count of a file
get_line_count() {
    local filepath="$1"
    if is_text_file "$filepath"; then
        local count=$(wc -l <"$filepath")
        if [[ -z "$count" ]]; then
            echo "0"
        else
            echo "$count"
        fi
    else
        echo "" # Return empty if not a text file
    fi
}

# Recursive function to display tree structure
display_tree() {
    local dir="$1"
    local indent="$2"
    local is_last="$3" # Flag if this is the last item in parent dir
    local current_depth="$4" # Current depth of recursion
    local max_depth="$5" # Maximum depth for scanning

    # Check if the directory exists
    if ! [ -d "$dir" ]; then
        echo "Error: Directory '$dir' not found."
        return 1
    fi

    # Get items in directory (files and subdirectories) and sort them alphabetically
    # Fix: Use null delimiter and handle spaces in filenames
    local items=()
    while IFS= read -r -d '' item; do
        items+=("$item")
    done < <(find "$dir" -maxdepth 1 -not -path "$dir" -print0 | sort -z)

    local item_count="${#items[@]}"
    local current_item_index=0
    local line_count_widths=()
    local countable_files_info=() # Store info about text and empty files

    # First pass to calculate max width and store countable files info
    for item in "${items[@]}"; do
        if [ -f "$item" ] && (is_text_file "$item" || is_empty_file "$item"); then
            local line_count=$(get_line_count "$item")
            countable_files_info+=("$item")
            line_count_widths+=("$line_count")
        fi
    done

    local max_width=0
    for width in "${line_count_widths[@]}"; do
        local current_width=${#width}
        if [[ "$current_width" -gt "$max_width" ]]; then
            max_width="$current_width"
        fi
    done

    # Second pass to display items
    current_item_index=0
    for item in "${items[@]}"; do
        local name=$(basename "$item")
        local current_indent="$indent"
        local prefix=""
        local is_last_item=$((current_item_index + 1 == item_count))

        if [[ "$is_last" == "1" ]]; then
            # Replace trailing vertical line + spaces with spaces for last item's indent
            current_indent="${indent%"${VERTICAL_LINE}  "}   " # Using variable for Unicode vertical line
        fi

        if [[ "$is_last_item" == "1" ]]; then
            prefix="└── " # Keep space after └──
        else
            prefix="├── " # Keep space after ├──
        fi

        if [ -d "$item" ]; then
            # Directory - Blue color
            local padding=""
            for ((i = 0; i < max_width; i++)); do
                padding+=" "
            done

            echo -e "${current_indent}${prefix}${COLOR_BLUE}${name}${COLOR_RESET}"
            if [[ "$current_depth" -lt "$max_depth" || "$max_depth" -eq 0 ]]; then
                display_tree "$item" "$current_indent${VERTICAL_LINE}  " "$is_last_item" $((current_depth + 1)) "$max_depth"
            fi
        elif [ -f "$item" ]; then
            # File
            local line_count=$(get_line_count "$item")
            local padding=""
            if is_text_file "$item"; then
                # Text file - Green color for line count, default for name
                local display_line_count="$line_count" # Use this for display
                if [[ "$line_count" == "0" ]]; then
                    display_line_count="0" # Ensure "0" is used for padding calculation
                fi

                local line_count_len=${#display_line_count} # Length of what will be displayed
                local padding_needed=$((max_width - line_count_len))
                for ((i = 0; i < padding_needed; i++)); do
                    padding+=" "
                done

                echo -e "${current_indent}${prefix}${padding}${COLOR_GREEN}${display_line_count}${COLOR_RESET} ${name}"
            elif is_empty_file "$item"; then # Handle empty files here - Default color for "0" and name

                local padding_needed=$((max_width - 1)) # "0" is one char long
                for ((i = 0; i < padding_needed; i++)); do
                    padding+=" "
                done

                echo -e "${current_indent}${prefix}${padding}${COLOR_GREEN}0${COLOR_RESET} ${name}" # Added green color
            elif is_image_file "$item"; then
                # Image file - Cyan color
                echo -e "${current_indent}${prefix}${COLOR_CYAN}${name}${COLOR_RESET}"
            elif is_pdf_file "$item"; then
                # PDF file - Yellow color
                echo -e "${current_indent}${prefix}${COLOR_YELLOW}${name}${COLOR_RESET}"
            else
                # Regular file - Red color
                echo -e "${current_indent}${prefix}${COLOR_RED}${name}${COLOR_RESET}"
            fi
        fi
        ((current_item_index++))
    done

    return 0  # End of recursion for this directory
}

# Parse command-line options
max_depth=0
while getopts "d:" opt; do
  case "$opt" in
    d) max_depth="$OPTARG" ;;
    *) ;;
  esac
done

# Get the starting directory from the command line argument, default to current directory
shift $((OPTIND - 1))
start_dir="$1"

# Check if a directory was provided as an argument
if [[ -z "$start_dir" ]]; then
    start_dir="." # Use current directory if no argument is provided
fi

# Check if the provided path is a valid directory. If not, exit with an error
if ! [ -d "$start_dir" ]; then
    echo "Error: '$start_dir' is not a valid directory." >&2 # Print error to stderr
    exit 1
fi

# Display the root directory name, aligned with guide lines - Blue color
root_name=$(basename "$start_dir")
echo -e "${COLOR_BLUE}${root_name}${COLOR_RESET}"

# Start the recursive display, initial indent with 2 spaces for root alignment
display_tree "$start_dir" "" "0" 1 "$max_depth"

# Display directory and file count
dir_count=$(find "$start_dir" -type d | wc -l)
file_count=$(find "$start_dir" -type f | wc -l)

# Display directory and file count
echo -e "\n${dir_count} directories, ${file_count} files"

exit 0
