function cleanpdfs() {
  emulate -L zsh
  setopt extended_glob nocasematch  # nocasematch for case-insensitive matching

  # Create log file
  local LOGFILE=".cleanpdfs_rename.log"
  : > $LOGFILE  # overwrite log file on each run
  
  # Helper function: normalize swedish chars in string (for matching)
  swedish_to_ascii() {
    local str=$1
    # Replace Swedish chars with ASCII equivalents
    str=${str//å/a}
    str=${str//ä/a}
    str=${str//ö/o}
    str=${str//Å/a}
    str=${str//Ä/a}
    str=${str//Ö/o}
    echo "$str"
  }

  # Extract normalized date and type
  get_clean_name() {
    local fname="$1"
    local fname_lc=$(echo "$fname" | tr '[:upper:]' '[:lower:]')
    local fname_norm=$(swedish_to_ascii "$fname_lc")
    local date=""
    local date_norm=""
    local type="tenta"

    # Extract candidate date substrings (6 or 8 digits, optionally with separators)
    # Reject sequences of length 3 (like course numbers)
    if [[ $fname_norm =~ ([0-9]{4}[^0-9]?[0-9]{2}[^0-9]?[0-9]{2}) ]]; then
      date=$match[1]
    elif [[ $fname_norm =~ ([0-9]{6,8}) ]]; then
      # To avoid picking 3-digit sequences, check length explicitly
      local candidate=${match[1]}
      if (( ${#candidate} == 6 || ${#candidate} == 8 )); then
        date=$candidate
      fi
    else
      return 1
    fi

    # Normalize date using normalize_date
    date_norm=$(normalize_date -eu6 "$date")
    # Determine type
    if [[ $fname_norm =~ "(-l|losn|losning|sol)" ]]; then
      type="losn"
    elif [[ $fname_norm =~ "omtenta" ]]; then
      type="tenta"
    elif [[ $fname_norm =~ "tentamen" ]]; then
      type="tenta"
    fi

    echo "${date_norm}_${type}.pdf"
  }

  # Step 1: Remove duplicates
  typeset -A seen
  local trashbin=0
  for f in *.pdf; do
    clean=$(get_clean_name "$f")
    if [[ -z $clean ]]; then
      echo "Skipping (no match): $f"
      continue
    fi

    if [[ -n ${seen[$clean]} ]]; then
	  (( ! trashbin )) && { mkdir -p "./duplicates"; trashbin=1 }
	  echo "Duplicate found, moving to trash: $f -> ./duplicates/$f"
      mv "$f" "./duplicates/$f"
    else
      seen[$clean]="$f"
    fi
  done

  # Step 2: Rename remaining files
  for f in *.pdf; do
    clean=$(get_clean_name "$f")
    if [[ -z $clean ]]; then
      echo "Skipping (no match): $f"
      continue
    fi

    echo "Renaming $f -> $clean" | tee -a "$LOGFILE"
    mv "$f" "$clean"
    echo "${clean}|${f}" >>| "$LOGFILE"
  done

  echo "Rename log saved to $LOGFILE"
	if [[ -d "./duplicates" ]]; then
	  echo "cleanup phase" 
	  (( trashbin )) && { rm -rI "./duplicates" }
	fi
}

