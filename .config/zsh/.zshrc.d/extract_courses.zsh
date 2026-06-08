# Function to automatically create navigation aliases for courses
create_course_aliases() {
  
    # Variables
    local current_year=2
    local print_year="TKAUT-$current_year" # Adjust which courses are displayed on startup
    local course_aliases="$ZDOTDIR/.zshrc.d/auto_generated/course_aliases.zsh"  # Alias storage file
    local course_list="$ZDOTDIR/.zshrc.d/auto_generated/course_list.txt" # Aliases text help file
    
    # Ensure paths exist
    mkdir -p "$ZDOTDIR/.zshrc.d/auto_generated"
    [[ ! -e "$course_aliases" ]] && touch "$course_aliases"
    [[ ! -e "$course_list" ]] && touch "$course_list"

    # Helper alias
    alias courses="cat $course_list"

    # Clear alias files before adding new aliases
    echo "# Auto-generated course aliases" > "$course_aliases"
    echo "# Courses:" > "$course_list"
    echo "alias skola='cd \"$HOME/OneDrive/$print_year\"'" >> "$course_aliases"
    
    # Process each year (active + archive)
    for ((year=1; year<=$current_year; year++)); do
        local active_dir="$HOME/OneDrive/TKAUT-$year"
        local archive_dir="$active_dir/.Z${year}archive"

        # Also create aliases for TKAUT 
        echo "alias TKAUT-$year='cd \"$active_dir\"'" >> "$course_aliases"
        echo "\nTKAUT-$year:" >> "$course_list"

        # Ensure directories exist
        for base_dir in "$active_dir" "$archive_dir"; do
            [[ -d "$base_dir" ]] || continue  # Skip if missing
            setopt local_options nullglob     # prevent errors on empty dirs

            for dir in "$base_dir"/*/; do
                [[ -d "$dir" ]] || continue  # Ensure it's a directory

                # Extract course code from 'COURSECODE-Course-Name' format
                local folder_name="${dir%/}"         # Remove trailing slash
                local base_name="${folder_name##*/}" # Extract folder name
                local code="${base_name%%-*}"        # Get text before the first '-'
                local course_title="${base_name#*-}" # Everything after the first '-'

                # Ensure the extracted code is a valid course code (ABC123 format)
                if [[ "$code" =~ ^[A-Z]{3}[0-9]{3}$ ]]; then
                    local alias_name="${code:l}"  # Lowercase (mve601)
                    local display_alias="${(U)code}"  # Uppercase for printing
                    
                    # Create alias
                    alias "$alias_name"="cd \"$dir\""
                    alias "${alias_name:u}"="cd \"$dir\"" # Also allow uppercase input

                    # Write aliases to file
                    echo "alias $alias_name='cd \"$dir\"'" >> "$course_aliases"
                    echo " $display_alias → $course_title" >> "$course_list"

                    # Print only for the configured year
                    if [[ "$active_dir" == *"$print_year" ]]; then
                        echo " $display_alias → $course_title" 
                    fi
                fi
            done
        done
    done

    # Source alias file so aliases are available immediately
    source "$course_aliases"
}

# Run function on shell startup
print -P "%BAliases:%b"
create_course_aliases
print -P "%B%Ucourses%u%b → prints a list of %Ball%b archived courses\n"
