#!/bin/bash

# Define Unicode vertical line character
VERTICAL_LINE=$'\u2502'

# ANSI color codes
COLOR_RESET='\033[0m'
COLOR_BLUE='\033[34m'
COLOR_GREEN='\033[32m'
COLOR_RED='\033[31m'
COLOR_YELLOW='\033[33m'
COLOR_CYAN='\033[36m'
COLOR_DEFAULT='\033[39m'

# Check if a file is a text file
is_text_file() {
    local filepath="$1"
    file -b "$filepath" | grep -q "text"
}

# Check if a file is an empty file
is_empty_file() {
    local filepath="$1"
    file -b "$filepath" | grep -q "empty"
}

# Check if a file is an image file
is_image_file() {
    local filepath="$1"
    file -b "$filepath" | grep -qE "image"
}

# Check if a file is a PDF file
is_pdf_file() {
    local filepath="$1"
    file -b "$filepath" | grep -qE "PDF"
}

# Get line count of a file
get_line_count() {
    local filepath="$1"
    if is_text_file "$filepath"; then
        local count=$(wc -l <"$filepath")
        echo "${count:-0}"
    elif is_empty_file "$filepath"; then
        echo "0"
    else
        echo ""
    fi
}

# Display tree structure
display_tree() {
    local dir="$1"
    local indent="$2"
    local is_last="$3"
    local current_depth="$4"
    local max_depth="$5"

    if ! [ -d "$dir" ]; then
        echo "Error: Directory '$dir' not found."
        return 1
    fi

    local items=()
    while IFS= read -r -d '' item; do
        items+=("$item")
    done < <(find "$dir" -maxdepth 1 -mindepth 1 -print0 | sort -z)

    local item_count="${#items[@]}"
    local current_item_index=0
    local line_count_widths=()

    for item in "${items[@]}"; do
        if [ -f "$item" ] && (is_text_file "$item" || is_empty_file "$item"); then
            local line_count=$(get_line_count "$item")
            line_count_widths+=("$line_count")
        fi
    done

    local max_width=0
    for width in "${line_count_widths[@]}"; do
        local current_width=${#width}
        (( current_width > max_width )) && max_width=$current_width
    done

    for item in "${items[@]}"; do
        local name=$(basename "$item")
        local current_indent="$indent"
        local prefix=""
        local is_last_item=$((current_item_index + 1 == item_count))

        [[ "$is_last" == "1" ]] && current_indent="${indent%"${VERTICAL_LINE}  "}   "

        prefix=$([[ "$is_last_item" == "1" ]] && echo "└── " || echo "├── ")

        if [ -d "$item" ]; then
            local padding=$(printf '%*s' "$max_width")
            echo -e "${current_indent}${prefix}${COLOR_BLUE}${name}${COLOR_RESET}"

            if [[ "$max_depth" -eq 0 || "$current_depth" -lt "$max_depth" ]]; then
                display_tree "$item" "$current_indent${VERTICAL_LINE}  " "$is_last_item" $((current_depth + 1)) "$max_depth"
            fi
        elif [ -f "$item" ]; then
            local line_count=$(get_line_count "$item")
            local padding=""
            local display_line_count=""
            local color="${COLOR_RED}"

            if is_text_file "$item" || is_empty_file "$item"; then
                display_line_count="${line_count:-0}"
                local padding_needed=$((max_width - ${#display_line_count}))
                padding=$(printf '%*s' "$padding_needed")
                color="${COLOR_GREEN}"
                echo -e "${current_indent}${prefix}${padding}${color}${display_line_count}${COLOR_RESET} ${name}"
            elif is_image_file "$item"; then
                echo -e "${current_indent}${prefix}${COLOR_CYAN}${name}${COLOR_RESET}"
            elif is_pdf_file "$item"; then
                echo -e "${current_indent}${prefix}${COLOR_YELLOW}${name}${COLOR_RESET}"
            else
                echo -e "${current_indent}${prefix}${COLOR_RED}${name}${COLOR_RESET}"
            fi
        fi
        ((current_item_index++))
    done
    return 0
}

# Parse command-line options
max_depth=0
while getopts "d:" opt; do
    case "$opt" in
        d)
            if [[ "$OPTARG" =~ ^[0-9]+$ ]]; then
                max_depth="$OPTARG"
            else
                echo "Error: Depth (-d) must be a non-negative integer." >&2
                exit 1
            fi
            ;;
        *) ;;
    esac
done

shift $((OPTIND - 1))
start_dir="$1"

[[ -z "$start_dir" ]] && start_dir="."
[[ ! -d "$start_dir" ]] && echo "Error: '$start_dir' is not a valid directory." >&2 && exit 1

# Display root name
root_name=$(basename "$start_dir")
echo -e "${COLOR_BLUE}${root_name}${COLOR_RESET}"

# Display tree
display_tree "$start_dir" "" "0" 1 "$max_depth"

# Count dirs and files based on depth
if [[ "$max_depth" -eq 0 ]]; then
    dir_count=$(find "$start_dir" -type d | wc -l)
    file_count=$(find "$start_dir" -type f | wc -l)
else
    dir_count=$(find "$start_dir" -maxdepth "$max_depth" -type d | wc -l)
    file_count=$(find "$start_dir" -maxdepth "$max_depth" -type f | wc -l)
fi

echo -e "\n${dir_count} directories, ${file_count} files"
exit 0
