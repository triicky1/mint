pdf_outdated() {
	local query="" verbose=0 debug=0 query_flag=0 list=0 max_results=2
	local chrome_bin="/opt/google/chrome/google-chrome"
	local cache_file="$HOME/.cache/pdf_opened.log"
	local patterns=() results=()
	local COLOR_GREEN="\033[1;32m" COLOR_RESET="\033[0m"

	# Parse arguments
	while [[ "$1" ]]; do
		case "$1" in
			-v|--verbose)	verbose=1 ;;
			-d|--debug) debug=1; max_results=20 ;;
			-q|--query) query_flag=1; shift query="$1" ;;
			-l|--list) list=1; max_results=10;;	
			-h|--help)
				cat <<EOF
Usage: pdf [options] <command> [args...]

Options:
-h, --help         Show this help
-v, --verbose      Display extra info
-q, --query        Search query (format: YYYYMM or YYMM)
-d, --debug        Debug mode (show internals, disable limit)
-r, --recents      List recent files (TODO)

Commands:
pdf <filename.pdf>
pdf -q <query>
pdf open <index> (TODO)
EOF
				return 0 ;;
			-*) echo "Unknown option: $1"; return 1 ;;
			*) query="$1" 
				[[ -z "$query" ]] && { 
				echo "Usage: pdf [options] <command> [args...]"
				return 1 
			} ;; 
		esac
		shift
	done 

	# Single file mode
	if [[ -f "$query" ]]; then
		if [[ "${query##*.}" != "pdf" ]]; then
			echo "Error: File does not have a .pdf extension: \n - \"$query\""
			return 1
		else
		results+=("$query")
		fi
	else
		patterns=($(generate_patterns "$query")) || return 1
  	local combined_patterns=$(IFS='|'; echo "${patterns[*]}")
		# Search for matching querys
		while IFS= read -r file; do
			results+=("$file")
			(( debug )) || (( ${#results[@]} >= max_results )) && break
		done < <(find . -type f -iname "*.pdf" | grep -Ei "$combined_patterns")
		(( ${#results[@]} == 0 )) && { 
			echo "Error: No matching PDF files found for \"$file\""
			return 1
		}
	fi
	
	# Debug output (or print result for --list output)
	if (( debug || list )); then
		(( debug )) && {
			echo -e "\n--- DEBUG ---"
			echo "Query: $query"
			echo "Patterns: ${patterns[*]}" 
			echo "Results:"
		}
		for file in "${results[@]}"; do
			echo " - ${COLOR_GREEN}${file}${COLOR_RESET}"; 
		done
		(( debug )) && {
			echo "Chrome path: $chrome_bin"
			echo "Cache file: $cache_file"
		}
		return 0
	fi

	# Launch message
	if pgrep -x "chrome" >/dev/null; then
		echo "Opening in existing browser session."
	else
		echo "Opening in new browser session."
	fi

	# Open grouped files and cache them
	for file in "${results[@]}"; do
		setsid "$chrome_bin" "$file" >/dev/null 2>&1
		echo "$file" >> "$cache_file"
		if (( verbose )); then
			local window_id=$(kdotool getactivewindow "$file")
			local window_name=$(kdotool getwindowname "$window_id")
			printf "Focusing on: %s\"%s\"%s: window-id: %s%s%s\n" \
				     "$COLOR_GREEN" "$window_name" "$COLOR_RESET" \
			       "$COLOR_GREEN" "$window_id" "$COLOR_RESET"
		fi
	done
	
	sleep .25
	activate_window chrome
}
