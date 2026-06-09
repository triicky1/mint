#!/usr/bin/env zsh
# extract_courses.zsh

# INFO: You need to structure your Chalmers OneDrive directory as follows:
# ~/OneDrive ❯ ls
# Permissions Name
# drwxr-xr-x    TKAUT-1
# drwxr-xr-x    TKAUT-2
# drwxr-xr-x    TKAUT-3
# ~OneDrive/TKAUT-2 ❯ ls
# Permissions Name
# drwxr-xr-x    DAT525-Data-structures-and-algorithms
# drwxr-xr-x    EDA488-Maskinorienterad-programmering
# drwxr-xr-x    IMS085-Simulering-och-optimering-av-hållbara-produktionssystem
# drwxr-xr-x    MVE091-Mathematical-statistics
# drwxr-xr-x    SSY044-Signals-and-systems
# drwxr-xr-x    SSY052-Reglerteknik
# drwxr-xr-x    TEK815-Economy-and-organistaion

# Usage:

# Usage: calc_academic_year <start_year> [repeated_years]
# Returns: current_year - start_year - repeated_years
calc_academic_year() {
    local start_year=${1:?did you forget to specify your starting year?}
    local repeated_years=${2:-0} # optional
    local this_year=$(date +%Y)

    local month=$(date +%m)

    if [ "$month" -gt 8 ]; then
        echo $(( this_year - start_year - repeated_years + 1))
    else
        echo $(( this_year - start_year - repeated_years ))
    fi

}

# Function to automatically create navigation aliases for courses
create_course_aliases() {
    # Variables
    local current_year=$(calc_academic_year 2024)
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
