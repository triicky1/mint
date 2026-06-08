pdf() {
 # emulate -L zsh
 # setopt extended_glob

  local query=""
  local flag_verbose=0 flag_debug=0 flag_query=0 flag_list=0
  local max_results=2
  local chrome_bin="/opt/google/chrome/google-chrome"
  local cache_file="$HOME/.cache/pdf_opened.log"
  local -A grouped
  local -a results positional
  local COLOR_GREEN="\033[1;32m" 
  local COLOR_RESET="\033[0m"

  local usage=(
	""
	" Usage: pdf [options] <command> [args...]"
    " Options:"
    " -h, --help         Show this help"
    " -v, --verbose      Display extra info"
    " -q, --query        Search query (format: YYYYMM or YYMM)"
    " -d, --debug        Debug mode (show internals, disable limit)"
    " -r, --recents      List recent files (TODO)"
    " Commands:"
    " pdf <filename.pdf>"
    " pdf -q <search>"
    " pdf open <index> (TODO)"
	""
  )

  opterr() { echo >&2 " Unknown option '$1'" }

  # Parse args
  while (( $# )); do
    case "$1" in
      --)           shift; positional+=("${@[@]}"); break   ;;
      -h|--help)    printf "%s\n" "${usage[@]}" && return   ;;
      -v|--verbose) flag_verbose=1                          ;;
      -d|--debug)   flag_debug=1; max_results=20            ;;
      -q|--query)   flag_query=1; shift; query="$1"         ;;
      -l|--list)    flag_list=1; max_results=10             ;;
      -*)           opterr "$1" && return 2                 ;;
      *)            positional+=("$1"); break               ;;
    esac
    shift
  done

  # Step 1: Group PDFs by normalized date
  for f in **/*.pdf(.N); do
	local base="${f:t:r}"   # Extract filename without directory and extension
	if [[ $base =~ ([0-9]{8}|[0-9]{6}) ]]; then
	  local base_date="${match[1]}"
	else
	  continue
	fi
	norm_date="$(normalize_date -eu6 "$base_date" 2>/dev/null)"
	[[ -n $norm_date ]] && grouped[$norm_date]+="$f::"
  done
  if (( ${#grouped[@]} == 0 )); then
    echo " No PDF files with recognizable dates found."
    return 1
  fi

  # Step 2: If no flags, open single PDF
  if (( ! flag_query && ! flag_debug && ! flag_list )) && [[ -n $positional ]]; then
    local file="${positional[1]}"
    if [[ -f "$file" ]] && [[ "$file" == *.pdf ]]; then
      results+=("$file")
    else
	  query="$file"
      flag_query=1
    fi
  fi

  # Step 3: Handle -q (query) mode
  if (( flag_query )); then
	  if [[ $query =~ ([0-9]{8}|[0-9]{6}) ]]; then
		  local date="${match[1]}"
		  query="$(normalize_date -eu6 "$date" 2>/dev/null)"
	  fi

	  local filtered_dates=()
	  for date in ${(k)grouped}; do
		  [[ "$date" == ${query}* ]] && filtered_dates+=("$date")
	  done

	  if (( ${#filtered_dates[@]} == 0 )); then
		  echo " No matches for query \"$query\""
		  return 1
	  fi

	  for date in "${filtered_dates[@]}"; do
		  local files=("${(s/::/)grouped[$date]}")
		  (( flag_verbose )) && {
			  echo -e "\nDate: $COLOR_GREEN$date$COLOR_RESET"
			  for f in $files; do echo " - $f"; done
		  }
	  results+=("${files[@]:0:$max_results}")
  done
  fi


  # Step 5: Open files
  if pgrep -x "chrome" >/dev/null; then
    echo " Opening in existing Chrome session..."
  else
    echo " Opening in new Chrome session..."
  fi

  for file in "${results[@]}"; do
    setsid "$chrome_bin" "$file" >/dev/null 2>&1
    echo "$file" >> "$cache_file"
  done

  sleep 0.250
  (( flag_verbose )) && { echo -e "\n $(activate_window -v "chrome") \n" }
  activate_window "chrome"
}

