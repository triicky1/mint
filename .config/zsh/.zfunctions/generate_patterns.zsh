generate_patterns() {
  local query="$1"
  local yyyy yy mm
  local -a patterns

  if [[ "$query" =~ ^[0-9]{6}$ ]]; then
    yyyy="${query:0:4}"
    mm="${query:4:2}"
    yy="${query:2:2}"
  elif [[ "$query" =~ ^[0-9]{4}$ ]]; then
    yy="${query:0:2}"
    mm="${query:2:2}"
    yyyy="20$yy"
  else
    print "Invalid date format. Use YYYYMM or YYMM."
    return 1
  fi

  if (( 10#$mm < 1 || 10#$mm > 12 )); then
    print "Invalid month: $mm"
    return 1
  fi
  
	patterns+=(
	  "${yyyy}[-_/ .]?${mm}" "${yy}[-_/ .]?${mm}"
	  "${mm}[-_/ .]?${yyyy}" "${mm}[-_/ .]?${yy}"
	  "${yyyy}${mm}" "${yy}${mm}" "${mm}${yyyy}" "${mm}${yy}"
  )
  
	print -l -- "${patterns[@]}"
}

