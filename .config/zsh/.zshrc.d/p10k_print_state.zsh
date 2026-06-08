p10k_print_state () {
	typeset -A reply
  p10k display -a '*'
  printf '%-32s = %q\n' ${(@kv)reply} | sort
}
