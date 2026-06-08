activate_window() {
  local verbose=0
  local application="$1"
  
  # ANSI colors
  local COLOR_GREEN="\033[1;32m"
  local COLOR_RESET="\033[0m"

  if [[ "$1" == "-v" || "$1" == "-V" || "$1" == "--verbose" ]]; then
	  verbose=1
	  application="$2"
  else
	  application="$1"
  fi

  if [[ -z $application ]]; then
    echo "Usage: activate_window [-v] <application>" 
    return 1
  fi

  local window_id
  window_id=$(kdotool search "$application" | head -n1 | tr -d '{}')

  if [[ -z $window_id ]]; then
    echo "No window found for application \`$application\` to activate."
    return 1
  fi

  if (( verbose )); then
		local window_name=$(kdotool getwindowname "{$window_id}")
		echo -e "Focusing on: ${COLOR_GREEN}\"${window_name}\"${COLOR_RESET}: window-id: ${COLOR_GREEN}{${window_id}}${COLOR_RESET}"
  fi

  kdotool windowactivate "{$window_id}"
}
