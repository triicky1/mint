normalize_date() {
  local positional=()
  local flag_eu8=false
  local flag_eu6=false
  local flag_us8=false
  local flag_us6=false
  local flag_int8=false
  local flag_int6=false
  local date_string

  local usage=(
    "normalize_date [-h|--help]"
    "normalize_date [-eu|-us|-int] [-eu6|-us6|-int6] <date_string>"
    ""
    "Output format flags (default: -eu):"
    "  -eu / -eu8        European long: yyyymmdd"
    "  -eu6              European short: yymmdd"
    "  -us / -us8        US long: mmddyyyy"
    "  -us6              US short: mmddyy"
    "  -int / -int8      International long: ddmmyyyy"
    "  -int6             International short: ddmmyy"
    ""
    "Input <date_string> is auto-detected and can be one of:"
    "  yyyymmdd, yymmdd, mmddyyyy, mmddyy, ddmmyyyy, ddmmyy"
    "  or with separators like yyyy-mm-dd, dd/mm/yyyy, etc."
  )

  opterr() { echo >&2 "normalize_date: Unknown option '$1'"; }

  # Parse options
  while (( $# )); do
    case $1 in
      --) shift; positional+=("${@[@]}"); break ;;
      -h|--help) printf "%s\n" "${usage[@]}"; return 0 ;;
      -eu|-swe|--eu|--european|--swedish|--swe|-yyyymmdd|--yyyymmdd) flag_eu8=true ;;
      -eu6|-swe6|--eu6|--european6|--swedish6|--swe6|-yymmdd|--yymmdd) flag_eu6=true ;;
      -us|--us|--united-states|-mmddyyyy|--mmddyyyy) flag_us8=true ;;
      -us6|--us6|--united-states6|-mmddyy|--mmddyy) flag_us6=true ;;
      -int|--int|--international|-ddmmyyyy|--ddmmyyyy) flag_int8=true ;;
      -int6|--int6|--international6|-ddmmyy|--ddmmyy) flag_int6=true ;;
      -*) opterr "$1"; return 2 ;;
      *) positional+=("$1"); shift; break ;;
    esac
    shift
  done

  # Get date string from positional args or $1 fallback
  date_string="${positional[1]:-$1}"

  if [[ -z $date_string ]]; then
    echo "Error: No date string provided" >&2
    printf "%s\n" "${usage[@]}" >&2
    return 1
  fi

  # Split parts by any non-digit separator
  local parts=("${(@s/[^0-9]/)date_string}")
  parts=(${(@)parts:#""})  # remove empty parts
  local part_count=${#parts[@]}

  local yy mm dd yyyy

  # Expand 2-digit year to 4-digit
  expand_year() {
    local y=$1
    local current_year=$(date +%Y)
    local century=${current_year[1,2]}
    if ((10#$y > 50)); then
      echo "$((century - 1))$y"
    else
      echo "${century}$y"
    fi
  }

  # Check if year is leap year
  is_leap_year() {
    local year=$1
    if (( year % 400 == 0 )); then
      return 0
    elif (( year % 100 == 0 )); then
      return 1
    elif (( year % 4 == 0 )); then
      return 0
    else
      return 1
    fi
  }

  # Validate date
  validate_date() {
    local y=$1
    local m=$2
    local d=$3

    # Validate year
    if ! [[ $y =~ ^[0-9]{4}$ ]]; then
      echo "Error: Invalid year '$y'" >&2
      return 1
    fi

    # Validate month
    if ((m < 1 || m > 12)); then
      echo "Error: Invalid month '$m'" >&2
      return 1
    fi

    # Validate day based on month
    if ((d < 1)); then
      echo "Error: Invalid day '$d'" >&2
      return 1
    fi

    local max_day=31
    case $m in
      4|6|9|11) max_day=30 ;;
      2)
        if is_leap_year $y; then
          max_day=29
        else
          max_day=28
        fi
        ;;
    esac

    if (( d > max_day )); then
      echo "Error: Invalid day '$d' for month '$m' in year '$y'" >&2
      return 1
    fi

    return 0
  }

  if (( part_count == 3 )); then
    # Interpret based on parts length and values
    if [[ ${#parts[1]} -eq 4 ]]; then
      yyyy="${parts[1]}"
      mm="${parts[2]}"
      dd="${parts[3]}"
    elif [[ ${#parts[3]} -eq 4 ]]; then
      if (( 10#${parts[1]} > 12 )); then
        dd="${parts[1]}"
        mm="${parts[2]}"
        yyyy="${parts[3]}"
      else
        mm="${parts[1]}"
        dd="${parts[2]}"
        yyyy="${parts[3]}"
      fi
    else
      if (( 10#${parts[2]} > 12 )); then
        yy="${parts[1]}"
        mm="${parts[2]}"
        dd="${parts[3]}"
        yyyy=$(expand_year "$yy")
      elif (( 10#${parts[1]} > 12 )); then
        dd="${parts[1]}"
        mm="${parts[2]}"
        yy="${parts[3]}"
        yyyy=$(expand_year "$yy")
      else
        mm="${parts[1]}"
        dd="${parts[2]}"
        yy="${parts[3]}"
        yyyy=$(expand_year "$yy")
      fi
    fi

  else
    # No separators or unknown format fallback
    local date_in="${date_string//[^0-9]/}"

    if [[ ${#date_in} -ne 6 && ${#date_in} -ne 8 ]]; then
      echo "Error: Date string must be 6 or 8 digits long after removing non-digit chars." >&2
      return 1
    fi

    if (( ${#date_in} == 8 )); then
      if [[ $date_in =~ ^(19|20)[0-9]{6}$ ]]; then
        yyyy="${date_in[1,4]}"
        mm="${date_in[5,6]}"
        dd="${date_in[7,8]}"
      else
        local part1="${date_in[1,2]}"
        local part2="${date_in[3,4]}"
        local part3="${date_in[5,8]}"
        if ((10#$part1 > 12)); then
          dd="$part1"
          mm="$part2"
          yyyy="$part3"
        else
          mm="$part1"
          dd="$part2"
          yyyy="$part3"
        fi
      fi
    else
      local part1="${date_in[1,2]}"
      local part2="${date_in[3,4]}"
      local part3="${date_in[5,6]}"

      if ((10#$part2 <= 12)); then
        yy="$part1"
        mm="$part2"
        dd="$part3"
      else
        if ((10#$part1 <= 31 && 10#$part2 <= 12)); then
          dd="$part1"
          mm="$part2"
          yy="$part3"
        else
          mm="$part1"
          dd="$part2"
          yy="$part3"
        fi
      fi
      yyyy=$(expand_year "$yy")
    fi
  fi

  # Validate extracted date before output
  if ! validate_date "$yyyy" "$((10#$mm))" "$((10#$dd))"; then
    return 1
  fi

  # Output normalized date according to flags, default is EU8 (yyyymmdd)
  if $flag_us8; then
    printf '%02d%02d%s\n' "$((10#$mm))" "$((10#$dd))" "$yyyy"
  elif $flag_us6; then
    printf '%02d%02d%s\n' "$((10#$mm))" "$((10#$dd))" "${yyyy[3,4]}"
  elif $flag_int8; then
    printf '%02d%02d%s\n' "$((10#$dd))" "$((10#$mm))" "$yyyy"
  elif $flag_int6; then
    printf '%02d%02d%s\n' "$((10#$dd))" "$((10#$mm))" "${yyyy[3,4]}"
  elif $flag_eu6; then
    printf '%s%02d%02d\n' "${yyyy[3,4]}" "$((10#$mm))" "$((10#$dd))"
  else
    # Default to eu8
    printf '%s%02d%02d\n' "$yyyy" "$((10#$mm))" "$((10#$dd))"
  fi
}

