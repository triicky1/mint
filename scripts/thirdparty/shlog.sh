#!/usr/bin/env sh
#
# shlog - A POSIX-compliant logging tool
#
# Copyright (c) 2026 realgeorge
# Based on 'slog' by Fred Palmer (2009-2011) and Joe Cooper (2017)
# https://github.com/swelljoe/slog
#
# This source code is licensed under the MIT license
set -euo pipefail

[ "${SHLOG_LOADED:-}" = "1" ] && return 0
SHLOG_LOADED=1

# Configuration Defaults
# Source the configuration and argument parsing script after setting
# default values. This allows user-defined settings from config files or
# command-line arguments to override the defaults initialized below.

# ==============================================================================
# GLOBALS
# ==============================================================================
SCRIPT_NAME="${0##*/}"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

SHLOG_FLUSH_CACHE=1   # Clears cache when script is sourced
SHLOG_PERSIST_CACHE=1 # Enables persisting cache
SHLOG_CAPTURE_CTX=1   # Enables context capture (%lineno etc)

# Determines if we print colors or not
if tty -s; then
    readonly INTERACTIVE_MODE="on"
else
    readonly INTERACTIVE_MODE="off"
fi

# === BEGIN INCLUDES ===
# ==============================================================================
# INTERNALS
# ==============================================================================
SHLOG_UNTANGLED_FORMAT=
SHLOG_NORMALIZED_IDENTIFIER=
SHLOG_ESCAPED_STRING=
SHLOG_CORE_RULES=
SHLOG_CUSTOM_RULES=
SHLOG_RULES=

SHLOG_ESC="$(printf '\033')"
SHLOG_SGR0="$(printf '\033[0m')"
# ==============================================================================
# BENCHMARKING & DEBUGGING
# ==============================================================================

# Usage: timestamp "label" function_name arg1 arg2
timestamp() {
    _func_count=
    is_uint "$1" && _func_count="$1" && shift
    _start="${EPOCHREALTIME%.*}${EPOCHREALTIME#*.}"
    "$@"
    _end="${EPOCHREALTIME%.*}${EPOCHREALTIME#*.}"

    _diff=$((_end - _start))
    _ms=$((_diff / 1000))
    _us=$((_diff % 1000))

    printf 'Execution of %s took %d.%d ms\n' "$*" "$_ms" "$_us"
    if [ -n "$_func_count" ]; then
        _avg=$((_diff / _func_count))
        _avg_ms=$((_avg / 1000))
        _avg_us=$((_avg % 1000))
        printf 'Average time: %d.%03d ms\n' "$_avg_ms" "$_avg_us" >&2
    fi
}

die() {
    # Usage: __shlog_err <error_code> [error arguments]
    rc="$1"
    is_int "$rc" && shift || rc=1
    printf '%s(%d): %s\n' "${fntrace:-fntrace_not_set}" "${rc}" "$@" >&2
    exit $rc
}

debug() { for _var in "$@"; do eval "_val=\"\${$_var}\"" && printf '%s=%s\n' "$_var" "$_val"; done; }

# ==============================================================================
# VALIDATION CHECKS
# ==============================================================================

is_alnum() { case "$1" in '' | *[![:alnum:]_]*) return 1 ;; esac }
is_alpha() { case "$1" in '' | *[![:alpha:]]*) return 1 ;; esac }
is_int() { case "${1#-}" in '' | *[!0-9]*) return 1 ;; esac }
is_int8() { is_int "$1" && test "$1" -lt 256; }
is_uint() { case "$1" in '' | *[!0-9]*) return 1 ;; esac }
is_uint8() { is_uint "$1" && test "$1" -lt 256; }
is_color_str() { case "$1" in SHLOG_DEBUG_COLOR | SHLOG_INFO_COLOR | SHLOG_SUCCESS_COLOR | SHLOG_WARNING_COLOR | SHLOG_ERROR_COLOR | SHLOG_TRACE_COLOR | SHLOG_CUSTOM_COLOR) return 0 ;; *) return 1 ;; esac }
is_color() { is_uint8 "$1" || is_color_str "$1"; }

# ==============================================================================
# STRING MANIPULATION & FORMATTING
# ==============================================================================

strip_ansi() { sed "s/${SHLOG_ESC}\[[0-9;]*m//g"; }

__shlog_escape() {
    # Usage: __shlog_escape "$string" '<pattern>'
    # Removes all occurences of <pattern> from $string
    # Stores escaped string in $SHLOG_ESCAPED_STRING
    case "$1" in
    *$2*) __shlog_escape "${1%%$2*}${1#*$2}" $2 ;;
    *) SHLOG_ESCAPED_STRING="$1" ;;
    esac
}

__shlog_normalize_identifier() {
    # Usage: __shlog_normalize_identifer "$var"
    # Normalizes string to an uppercase C-style identifier by replacing
    # non-alphanumeric characters with underscores.
    # Result is stored in $SHLOG_NORMALIZED_IDENTIFIER
    _s="$1"
    SHLOG_NORMALIZED_IDENTIFIER=
    while [ -n "$_s" ]; do
        _c="${_s%"${_s#?}"}"
        case "$_c" in
        a) _c=A ;; b) _c=B ;; c) _c=C ;; d) _c=D ;;
        e) _c=E ;; f) _c=F ;; g) _c=G ;; h) _c=H ;;
        i) _c=I ;; j) _c=J ;; k) _c=K ;; l) _c=L ;;
        m) _c=M ;; n) _c=N ;; o) _c=O ;; p) _c=P ;;
        q) _c=Q ;; r) _c=R ;; s) _c=S ;; t) _c=T ;;
        u) _c=U ;; v) _c=V ;; w) _c=W ;; x) _c=X ;;
        y) _c=Y ;; z) _c=Z ;; [![:alnum:]]*) _c="_" ;;
        esac
        SHLOG_NORMALIZED_IDENTIFIER="${SHLOG_NORMALIZED_IDENTIFIER}${_c}"
        _s="${_s#?}"
    done
}

# ==============================================================================
# INTERNAL LOGIC & UTILITIES
# ==============================================================================

# Used for caching / lookups
: ${_hash_dict:=$(awk 'BEGIN{for(i=32;i<=126;i++) printf "%c", i}')}
__shlog_hash_djb2() {
    _hash_str="$1"

    HASH_KEY=5381

    while [ "$_hash_str" ]; do
        _hash_prefix="${_hash_dict%%"${_hash_str%"${_hash_str#?}"}"*}"
        HASH_KEY=$(((HASH_KEY * 33 + ${#_hash_prefix} + 32) & 2147483647))
        _hash_str="${_hash_str#?}"
    done

    unset _hash_str _hash_prefix
}

# Convert locale timezone to offset in seconds
__shlog_tz_offset() {
    awk -v tz="${SHLOG_TIMEZONE:-UTC}" 'BEGIN {
    split(tz, a, /[:+-]/)
    print tz ~ /^CET/ ? 3600 :
        tz ~ /^CEST/ ? 7200 :
        tz ~ /^EST/ ? -18000 :
        tz ~ /^UTC/ ? (z~/-/?-1:1) * (a[2]*3600+a[3]*60):0
    }'
}

# Basically a slim version of date to avoid external forks
__shlog_date() {
    fntrace="__shlog_date"
    _t="${EPOCHSECONDS:-}"

    # [ -z "${_sh_o:-}" ] && _sh_o=$(__shlog_tz_offset)
    [ -n "${_t:-}" ] || die 3 "\$EPOCHSECONDS is not accessible"
    is_int "$_sh_o" || die 3 "Timezone \`${SHLOG_TIMEZONE:-}\` not implemented yet"

    _t=$((_t + ${_sh_o:-0}))

    # 1. Consolidated Division & Inline Padding
    _s=$((_t % 60 + 100))
    _m=$((_t / 60 % 60 + 100))
    _h=$((_t / 3600 % 24 + 100))
    _days=$((_t / 86400 + 719468))

    # 2. Euclidean Date Logic
    _era=$(((_days >= 0 ? _days : _days - 146096) / 146097))
    _doe=$((_days - _era * 146097))
    _yoe=$(((_doe - _doe / 1460 + _doe / 36524 - _doe / 146096) / 365))
    _Y=$((_yoe + _era * 400))
    _doy=$((_doe - (365 * _yoe + _yoe / 4 - _yoe / 100)))
    _mp=$(((5 * _doy + 2) / 153))

    # 3. Inline Padding for Day and Month
    _D=$((_doy - (153 * _mp + 2) / 5 + 101))
    _M=$((_mp < 10 ? _mp + 3 : _mp - 9))
    [ "$_M" -le 2 ] && _Y=$((_Y + 1))
    _M=$((_M + 100))

    # 4. Direct Target Replacement Loop
    _evt_time="${1:-%Y-%m-%d %H:%M:%S}"
    while :; do
        case "$_evt_time" in
        *"%Y"*) _evt_time="${_evt_time%%"%Y"*}$_Y${_evt_time#*"%Y"}" ;;
        *"%m"*) _evt_time="${_evt_time%%"%m"*}${_M#1}${_evt_time#*"%m"}" ;;
        *"%d"*) _evt_time="${_evt_time%%"%d"*}${_D#1}${_evt_time#*"%d"}" ;;
        *"%H"*) _evt_time="${_evt_time%%"%H"*}${_h#1}${_evt_time#*"%H"}" ;;
        *"%M"*) _evt_time="${_evt_time%%"%M"*}${_m#1}${_evt_time#*"%M"}" ;;
        *"%S"*) _evt_time="${_evt_time%%"%S"*}${_s#1}${_evt_time#*"%S"}" ;;
        *) break ;;
        esac
    done

    unset _t _s _m _h _days _era _doe _yoe _Y _doy _mp _D _M
}

__shlog_decode_colors() {
    [ -z "${1:-}" ] && return 0

    # $1 = format, $2 = color code, $3 = style string
    set -- "${1%:*}" "${1#*:}" ""

    if [ -n "${1:-}" ] && is_alpha "$1"; then
        case "$1" in *b*) set -- "$1" "$2" "${3}1;" ;; esac
        case "$1" in *i*) set -- "$1" "$2" "${3}3;" ;; esac
        case "$1" in *u*) set -- "$1" "$2" "${3}4;" ;; esac
        case "$1" in *[!biu]*) die 1 "bad color format: '$1'" ;; esac
    fi

    is_uint8 "$2" || die 1 "bad color: $2"
    case "$2" in
    [0-7]) _reg_clr="${SHLOG_ESC}[${3}3${2}m" ;;
    [89] | 1[0-5]) _reg_clr="${SHLOG_ESC}[${3}9$(($2 - 8))m" ;;
    *) _reg_clr="${SHLOG_ESC}[${3}38;5;${2}m" ;;
    esac
}

__shlog_untangle_fmt() {
    : "${1:?}" # stdout/log
    SHLOG_UNTANGLED_FORMAT="\${SHLOG_FORMAT_${_reg_lvl}_$1:-\$SHLOG_FORMAT_$1}"

    set -- "$1" "$_reg_evt|"

    until [ -z "$2" ]; do
        if [ "${2%%|*}" != "$_reg_lvl" ]; then
            SHLOG_UNTANGLED_FORMAT="\${SHLOG_FORMAT_${2%%|*}_$1:-$SHLOG_UNTANGLED_FORMAT}"
        fi
        if ! command -v "SHLOG_PRINT_${2%%|*}_${1}" >/dev/null 2>&1; then
            export _evt_id="${2%%|*}" _evt_sym=$_reg_sym _evt_target=$1
            eval "_evt_fmt=$SHLOG_UNTANGLED_FORMAT"
            __shlog_hash_djb2 "${#_evt_sym}${_evt_fmt}"
            __shlog_compile "$1" "$_evt_fmt"
        fi
        set -- "$1" "${2#*|}"
    done

    SHLOG_UNTANGLED_FORMAT=\"$SHLOG_UNTANGLED_FORMAT\"
}

__shlog_add_rules() {
    _reg_rule="
    _int_evt=\"$_reg_int\"; \
    _evt_lvl=\"$_reg_lvl\"; \
    _evt_tag=\"${_reg_tag:-\$_evt_id}\"; \
    _evt_offset=\"${_reg_offset:-}\"; \
    _evt_sym=\"${_reg_sym:-}\"; \
    _evt_fmt=\"${_reg_fmt:-}\"; \
    _evt_color=\"${_reg_clr}\"; \
    _evt_fmt_stdout=$_reg_fmt_stdout; \
    _evt_fmt_log=$_reg_fmt_log;
    "

    case "$1" in
    CORE_RULES)
        SHLOG_CORE_RULES="${SHLOG_CORE_RULES}${_reg_evt}) ${_reg_rule};; "
        ;;
    CUSTOM_RULES)
        SHLOG_CUSTOM_RULES="${SHLOG_CUSTOM_RULES}${_reg_rule}_evt_id=\"CUSTOM\"; ;; "
        ;;
    esac
}

# __shlog_print_rules "[preview text]" | Prints formatted case rules.
__shlog_print_rules() {
    printf 'case "$_evt_id" in\n'
    printf '%s' "$SHLOG_CORE_RULES" |
        sed 's/_evt_color="\([^"]*\)"/_evt_color="\1'"${1:+${1}${SHLOG_SGR0}}"'"/g' |
        sed 's/) /)\n/g; s/; /;\n/g; s/;; /;;\n/g' |
        sed 's/^[[:space:]]*//; /^$/d; s/^/        /; s/^        \([^ ]*)\)/    \1/'
    printf '    *)\n'
    printf '%s\n' "$SHLOG_CUSTOM_RULES" |
        sed 's/_evt_color="\([^"]*\)"/_evt_color="\1'"${1:+${1}${SHLOG_SGR0}}"'"/g' |
        sed 's/) /)\n/g; s/; /;\n/g; s/;; /;;\n/g' |
        sed 's/^[[:space:]]*//; /^$/d; s/^/        /'
    printf 'esac\n'
}

SHLOG_GET_TEMPLATE() {
    case "$1" in
    normal) printf '%s\n' '[%date] [%label?7<-2|sym] %sym %message' ;;
    systemd) printf '%s\n' '<%level_int> %sym %message' ;;
    json) printf '%s\n' '{"ts":"%date","lvl":"%label","msg":"%message"}' ;;
    *) return 1 ;;
    esac
}
# ==============================================================================
# CACHE
# ==============================================================================

case "$(uname -s)" in
Darwin)
    _cache_dir="$HOME/Library/Caches/shlog"
    ;;
*)
    _cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/shlog"
    # _cache_dir="$HOME/Projects/shlog/tmp"
    ;;
esac

SHLOG_CACHE_FILE="$_cache_dir/shlog-cache.sh"

if [ "${SHLOG_PERSIST_CACHE:-0}" = "0" ] || [ "${SHLOG_FLUSH_CACHE:-0}" = "1" ]; then
    if [ -f "$SHLOG_CACHE_FILE" ] && [ -n "$_cache_dir" ]; then
        rm -f "$SHLOG_CACHE_FILE"
    fi
fi

if [ "${SHLOG_PERSIST_CACHE:-0}" = "1" ]; then
    if [ ! -f "$SHLOG_CACHE_FILE" ]; then
        mkdir -p "$_cache_dir" || die 1 "directory creation failed: $_cache_dir"

        # Initialize empty file if directory is writable
        : >"$SHLOG_CACHE_FILE"
    fi

    # Source only if readable to prevent shell execution errors
    [ -r "$SHLOG_CACHE_FILE" ] && . "$SHLOG_CACHE_FILE"
fi

# __shlog_add_cache
# Appends a function string to the persistent cache file.
# $1: The function definition string to store.
__shlog_add_cache() {
    if [ "$SHLOG_PERSIST_CACHE" = "1" ]; then
        printf "%s\n" "$1" >>"$SHLOG_CACHE_FILE"
    fi
}

# __shlog_sort_cache
# Sorts cache file after function strings hash id.
# This function is trapped
__shlog_sort_cache() {
    if [ -f "$SHLOG_CACHE_FILE" ] && [ "$SHLOG_PERSIST_CACHE" = "1" ]; then
        awk '
        NF {
            hash = "0"
            type = 3
            
            if (match($0, /SHLOG_EXEC_[0-9]+/)) {
                hash = substr($0, RSTART + 11, RLENGTH - 11)
            }
            
            if (/^SHLOG_EXEC_/) type = 1
            else if (/_STDOUT\(\)/) type = 2
            
            printf "%s:%d:%s\n", hash, type, $0
        }' "$SHLOG_CACHE_FILE" | sort -t ':' -u -k1,1 -k2,2n -k3,3 | awk '
        {
            current_hash = $0
            sub(/:.*/, "", current_hash)
            
            if (NR > 1 && current_hash != lasthash) print ""
            lasthash = current_hash
            
            sub(/^[^:]*:[^:]*:/, "")
            print $0
        }' >"${SHLOG_CACHE_FILE}.tmp" && mv "${SHLOG_CACHE_FILE}.tmp" "$SHLOG_CACHE_FILE"
    fi
}
# ==============================================================================
# LOG ROTATION
# ==============================================================================

# __shlog_rotate <log_file_path>
# Attempts to rotate every 100th log call.
__shlog_rotate() {
    fntrace="__shlog_rotate"

    # Prevent uneccessary rotations
    [ "${SHLOG_ROTATION:-0}" = "1" ] || return 0

    _sh_rotate_counter=$((_sh_rotate_counter + 1))
    [ $((_sh_rotate_counter % 100)) -eq 0 ] || return 0

    # Security and Path Validation
    case $SHLOG_PATH in *..*) die 1 "Illegal traversal: $SHLOG_PATH" && return 1 ;; esac
    case $SHLOG_PATH in */*) mkdir -p "${SHLOG_PATH%/*}" || return 1 ;; esac

    [ -L "$SHLOG_PATH" ] && die 1 "Symlink detected: $SHLOG_PATH"

    # Ensure file exists and is writable
    [ -f "$SHLOG_PATH" ] || : >"$SHLOG_PATH"
    [ -w "$SHLOG_PATH" ] || die 1 "Permission denied: $SHLOG_PATH"

    # Constraint validation
    is_uint "$SHLOG_MAX_SIZE" && [ $SHLOG_MAX_SIZE -ne 0 ] || return 1
    is_uint "$SHLOG_MAX_FILES" && [ $SHLOG_MAX_SIZE -ne 0 ] || return 1

    _sh_size=$(wc -c <"$SHLOG_PATH" 2>/dev/null)
    [ "${_sh_size:-0}" -lt "$SHLOG_MAX_SIZE" ] && return 0

    # Rotation Logic
    _sh_n=$SHLOG_MAX_FILES
    while [ "$_sh_n" -gt 1 ]; do
        _sh_s="${SHLOG_PATH}.$((_sh_n - 1))"
        _sh_t="${SHLOG_PATH}.$_sh_n"
        [ -f "$_sh_s" ] && [ ! -L "$_sh_s" ] && mv -f "$_sh_s" "$_sh_t"
        _sh_n=$((_sh_n - 1))
    done

    # Move active log and truncate original to preserve file descriptors
    if [ "$SHLOG_MAX_FILES" -gt 0 ]; then
        mv -f "$SHLOG_PATH" "${SHLOG_PATH}.1" && : >"$SHLOG_PATH"
    fi
}
# ==============================================================================
# COMPILE
# ==============================================================================

#__shlog_generate_printf
# Executes the awk script to parse the formatting string and options into
# a POSIX printf format and argument list.
__shlog_generate_printf() {
    export _evt_sym
    awk '
    # ---------------- INITIALIZATION ----------------
    BEGIN {
        fmt = ENVIRON["_evt_fmt"]
        evt = ENVIRON["_evt_id"]
        lbl = ENVIRON["_evt_tag"]
        lvl = ENVIRON["_evt_lvl"]
        tgt = ENVIRON["_evt_target"]
        sym = ENVIRON["_evt_sym"]
        reset = ENVIRON["SHLOG_DEFAULT_COLOR"]
        
        if (!reset) {
            cmd = "tput sgr0"
            cmd | getline reset
            close(cmd)
        }

        # OPTIONS
        # opt["date"]="$(date \"+${SHLOG_DATE_FORMAT:?}\")"
        opt["date"]="${_evt_time}"
        opt["event"]="${_evt_id}"
        opt["label"]="${_evt_tag}"
        opt["level"]="${_evt_lvl}"
        opt["message"]="${_evt_msg}"
        opt["hostname"]="${HOSTNAME:"
        opt["scriptname"]="${SCRIPT_NAME:-$0}"
        opt["lineno"]="${_caller_lineno}"
        opt["lvlint"]="${_evt_int}"
        opt["sym"]=(sym ? "${_evt_sym}" : "")
        opt["logpath"]="${SHLOG_PATH}"

        # print(opt["sym"])
        # exit 1

        # COLORS
        color["none"]="tput sgr0"
        color["black"]="tput setaf 0"
        color["red"]="tput setaf 1"
        color["green"]="tput setaf 2"
        color["yellow"]="tput setaf 3"
        color["blue"]="tput setaf 4"
        color["purple"]="tput setaf 5"
        color["cyan"]="tput setaf 6"
        color["white"]="tput setaf 7"
        color["grey"]="tput setaf 8"
        color["gray"]="tput setaf 8"

        mod["offset"]="@(-?[0-9]+)"
        mod["width"]="\\?([0-9]+)"
        mod["logic"]="<(\\*)?[\\+-][0-9]+\\|!?" optpat

        grouppat="\\(.*\\)"

        # Extract option config settings and create a option regex pattern
        for (o in opt) {
            max_width[o] = get_env("SHLOG_FMT_MAX_WIDTH_" toupper(o), evt, tgt)
            offset[o] = get_env("SHLOG_FMT_OFFSET_" toupper(o), evt, tgt)
            optpat = (optpat ? substr(optpat, 1, length(optpat) - 1) "|" : "(") o ")"
        }

        # Create a color regex pattern
        for (c in color) {
            colorpat = (colorpat ? substr(colorpat, 1, length(colorpat) - 1) "|" : "(") c ")"
        }

        # Create a mod regex pattern
        for (m in mod) {
            modpat = (modpat ? substr(modpat, 1, length(modpat) - 1) "|" : "(") mod[m] ")"
        }
    }

    # ---------------- HELPERS ----------------
    function isalnum(str)      { return (str ~ /^[[:alnum:]_]+$/            )}
    function isopt(str)        { return (str ~ "^(%)?" optpat               )}
    function isgroup(str)      { return (str ~ "^%" grouppat                )}
    function iscolor(str)      { return (str ~ "^(%)?" colorpat             )}
    function iscoloropt(str)   { return (str ~ "^(%)?" colorpat ":" optpat )}
    function iscolorgroup(str) { return (str ~ "^%" colorpat ":" grouppat  )}
    function hasmod(str)       { return (str ~ "^"  modpat                  )}

    function get_env(var, evt, tgt) {
        if (var "_" evt "_" tgt in ENVIRON) return ENVIRON[var "_" evt "_" tgt]
        else if (var "_" evt in ENVIRON)    return ENVIRON[var "_" evt]
        else if (var in ENVIRON)            return ENVIRON[var] 
        return ""
    }

    function load_chars() { 
        c=substr(fmt,i,1) 
        nc=substr(fmt,i+1,1) 
        rem=substr(fmt,i)
    }

    function extract_offset(o) {
        n += max_width[o]

        if (o == "sym" ) 
            m += (offset["lbl"]?offset["lbl"]:offset["evt"])
        else if (o == "level")
            m += offset["lvl"]
        else
            m += offset[o]
    }

    function extract_mod(   type, oper, cond, key) {
        type = c
        i++
        if (type == "@") {
            if (match(substr(fmt, i), /^-?[0-9]+/)) {
                m += substr(fmt, i, RLENGTH)
                i += RLENGTH
            }
        } 
        if (type == "?") {
            if (match(substr(fmt, i), /^[0-9]+/)) {
                n += substr(fmt, i, RLENGTH)
                i += RLENGTH
            }
        }
        if (c == "<") {
            if (match(substr(fmt, i), /^(\*)?([\+-])([0-9]+)\|/)) {
                oper = substr(fmt, i, RLENGTH - 1)
                i += RLENGTH
                if (match(substr(fmt, i), "^!?" optpat)) {
                    cond = substr(fmt, i, RLENGTH)
                    key = cond; sub(/^!/, "", key)
                    i += RLENGTH
                    if ((opt[key] != "") != (substr(cond,1,1) == "!"))
                        m = (oper ~ /^\*/) ? m * substr(oper, 2) : m + oper
                }
            }
        }
        
        load_chars()
        if (rem ~ "^" mod["logic"])
            extract_mod()
    }

    function extract_opt(   esc) {
        if (iscoloropt(rem))
            esc = extract_color("opt")
        load_chars()
        match(rem, "^"optpat)
        o = substr(rem,1,RLENGTH)
        i += (RLENGTH > 0 ? RLENGTH : 1)
        load_chars()
        return esc opt[o] (esc?reset:"")
    }

    function extract_color(type) {
        load_chars()
        match(rem, "^"colorpat)
        cc = substr(rem, 1, RLENGTH)
        cmd = color[cc]
        cmd | getline seq 
        close(cmd)
        i += (RLENGTH > 0 ? RLENGTH : 1) + (type == "opt" ? 1 : 0)
        load_chars()
        return (tgt == "STDOUT" ? seq : "")
    }

    # ---------------- CHAIN ----------------
    function begin_chain(){
        chain_data=literal
        w=length(chain_data) # max width
        n=m=0
    }

    function end_chain(){
        if (length(chain_data) > 0)
            emit_chain(chain_data)
    }

    function emit_chain(code){
        N = ((m||n) ? -(w+m+n) : "")
        printf_str = printf_str "%"N"s"
        args[++argc] = code
    }

    # ---------------- GROUP ----------------
    function begin_group(){
        group_data=literal
        depth=1
        group_color=(iscolorgroup(rem) ? extract_color("opt") : "")
        printf_str=printf_str literal
        i++
        w=n=m=0
    }

    function end_group(){
        if (length(group_data) > 0)
            emit_group(group_data)
    }

    function emit_group(code){
        N = ((m||n) ? -(w+m+n) : "")
        if (!N && rem ~ /^(-?[0-9]+)s[[:space:]]*/)
            printf_str = printf_str "%"
        else
            printf_str = printf_str "%"N"s"
        args[++argc] = group_color code (group_color?reset:"")
    }

    # ---------------- MAIN ----------------
    BEGIN {
        len=length(fmt)
        i=1
        state="TEXT"
        printf_str=""
        printf_args=""
        argc=0

        while (i<=len)
        {
            load_chars()

            # ---------------- TEXT ----------------
            if (state=="TEXT")
            {
                if (isgroup(rem) || iscolorgroup(rem))
                {
                    i++
                    state="GROUP"
                    begin_group()
                    literal=""
                    continue
                } 

                if (isopt(rem) || iscolor(rem))
                {
                    state="CHAIN"
                    begin_chain()
                    literal=""
                    continue
                }

                if (c ~ /[[:space:]]/) 
                {
                    i++
                    printf_str = printf_str literal c
                    literal=""
                    continue
                }
                
                literal = literal c
                i++
                continue
            }

            # ---------------- CHAIN ----------------
            if (state == "CHAIN")
            {
                if (c ~ /[[:space:]]/) 
                {
                    end_chain()
                    state="TEXT"
                    continue
                }

                if (c == "\\")
                {
                    chain_data = chain_data nc
                    i+=2
                    continue
                }

                if (isopt(rem) || iscoloropt(rem))
                {
                    i++
                    chain_data = chain_data extract_opt()
                    extract_offset(o)

                    if (o == "sym" && sym == "" && c ~ /[[:space:]]/) i++

                    if (hasmod(rem)) 
                        extract_mod()
                    continue
                }

                if (iscolor(rem))
                {
                    i++
                    chain_data = chain_data extract_color(rem)
                    continue
                }

                chain_data = chain_data c
                w++ i++
                continue
            }

            # ---------------- GROUP ----------------
            if (state=="GROUP")
            {
                depth += (c == "(") - (c == ")")

                if (depth == 0) 
                {
                    i++
                    load_chars()
                    state="TEXT"
                    if (hasmod(rem)) 
                        extract_mod()
                    end_group()
                    continue
                }

                if (isopt(rem) || iscoloropt(rem))
                {
                    group_data = group_data extract_opt()
                    continue
                }

                group_data = group_data c
                w++ i++
                continue
            }
        }

        if (state=="CHAIN") end_chain()
        if (state=="GROUP") end_group()
        if (state=="TEXT")  printf_str = printf_str literal 

        for (k = 1; k <= argc; k++) {
            printf_args = printf_args (k>1?" ":"") "\"" args[k] "\""
        }

        out = "\x27" printf_str "\\n" "\x27 " printf_args
        print out
        exit
    }' </dev/null
}

# __shlog_compile_format
# Compiles a raw log format string into an executable printf function.
# Prevents multiple compilations of similar events.
__shlog_compile() {

    if ! command -v "SHLOG_EXEC_$HASH_KEY" >/dev/null 2>&1; then

        __shlog_escape "$2" "'"
        export _evt_fmt="$SHLOG_ESCAPED_STRING"

        _printf_fmt="$(__shlog_generate_printf)"
        _fmt_metadata="SHLOG_EXEC_$HASH_KEY() { printf ${_printf_fmt}; }"

        eval "$_fmt_metadata"
        __shlog_add_cache "$_fmt_metadata" "\n%s\n"
    fi

    _func_def="SHLOG_PRINT_${_evt_id}_${1}() { SHLOG_EXEC_$HASH_KEY \"\$@\"; }"

    eval "$_func_def"
    __shlog_add_cache "$_func_def"
}
# ==============================================================================
# GLOBALS & HELPERS
# ==============================================================================
case "${SHLOG_DATE_FORMAT:-default}" in
default) SHLOG_DATE_FORMAT="%Y-%m-%d %H:%M:%S" ;;
systemd) SHLOG_DATE_FORMAT="%m %d %H:%M:%S" ;;
*) ;;
esac

opterr() { printf "%s: %s \n" "$fntrace" "$@" >&2 && exit 42; }

require_arg() {
    [ "$fntrace" = "SHLOG_MAP" ] && return 0

    if [ $# -gt 1 ] && [ -n "${2##-[[:alpha:]]*}" ]; then
        return 0
    elif [ -z "$2" ]; then
        die 2 "$1 missing argument"
    fi

    die 2 "bad option: $2"
}

# Usage: kv_arg "$1"
kv_arg() {
    case "$1" in
    *=*) export ${1%%=*}=${1#*=} ;;
    *) return 1 ;;
    esac
}

# ==============================================================================
# CONFIGURATION & INITIALIZATION
# ==============================================================================

SHLOG_USAGE() {
    cat <<-EOF
	Usage: . ./shlog.sh
  SHLOG_INIT [options]

	Options:
	-h, --help                Show this help message and exit
	-o, --output              Set the output log file path
  -c, --enable-cache        Enable persisting cache for log functions

  -z, --optimize <kv...>    Use builtin date function instead of /bin/date 
                            tz=UTC[+-]H[:M] (e.g., UTC+2, UTC-05:30) 
                            or named zones: CET, CEST, EST. (Default: UTC)

  -r, --rotation <kv...>    Enable log rotation. Requires specific keys:
                            max_files=UINT (count of logs to keep)
                            max_size=UINT  (KiB limit per log)

	Formatting:               Available: (normal, align, json, systemd)
	-F, --format              Sets the global format
	    --format-log          Sets the log format
	    --format-stdout       Sets the stdout format
	    --date-format         Sets the date string (default: "%Y-%m-%d %H:%M:%S")

	Logging levels:           Available: info, success, warning, error, debug
	-L, --log-level-default   Override global log levels, default is info
	    --log-level-log       Set the minimum log level to log to file 
	    --log-level-stdout    Set the minimum log level to print to stdout 
	EOF
}

# SHLOG_INIT
# $1 (optional) target
SHLOG_INIT() {
    fntrace="SHLOG_INIT"

    while [ $# -gt 0 ]; do
        case "$1" in
        -h | --help)
            SHLOG_USAGE
            exit 0
            ;;
        -o | --output)
            require_arg "$@"
            readonly SHLOG_PATH="$2"
            shift 2
            ;;
        -z | --optimize)
            SHLOG_OPTIMIZE=1
            shift

            while kv_arg "${1:-}"; do shift; done
            SHLOG_TIMEZONE="${tz:-UTC}"
            _sh_o=$(__shlog_tz_offset)
            ;;
        -d | --date-format)
            require_arg "$@"
            SHLOG_DATE_FORMAT="$2"
            shift 2
            ;;
        -c | --enable-cache)
            readonly SHLOG_CACHE_PERSIST=1
            shift
            ;;
        -r | --enable-rotate)
            readonly SHLOG_ROTATION=1
            _sh_rotate_counter=-1
            shift

            while kv_arg "${1:-}"; do shift; done
            [ -z "${max_files:-}" ] && die 2 "max_files missing"
            is_uint "$max_files" || die 2 "bad value: -r max_files=$max_files"

            [ -z "${max_size:-}" ] && die 2 "max_size missing"
            is_uint "$max_size" || die 2 "bad value: -r max_size=$max_size"

            readonly SHLOG_MAX_FILES=$max_files
            readonly SHLOG_MAX_SIZE=$((max_size * 1024))
            ;;

        # --- Formatting (Strings) ---
        -F | --format)
            require_arg "$@"
            SHLOG_FORMAT=$(SHLOG_GET_TEMPLATE "$2") || SHLOG_FORMAT="$2"
            shift 2
            ;;
        --format-log)
            require_arg "$@"
            SHLOG_FORMAT_LOG=$(SHLOG_GET_TEMPLATE "$2") || SHLOG_FORMAT_LOG="$2"
            shift 2
            ;;
        --format-stdout)
            require_arg "$@"
            SHLOG_FORMAT_STDOUT=$(SHLOG_GET_TEMPLATE "$2") || SHLOG_FORMAT_STDOUT="$2"
            shift 2
            ;;

        # --- Levels ---
        -L | --log-level)
            require_arg "$@"
            is_int "$2" || die 2 "bad opt: level is not int"
            SHLOG_LEVEL="$2"
            shift 2
            ;;
        --log-level-log)
            require_arg "$@"
            is_int "$2" || die 2 "bad opt: level-log is not int"
            SHLOG_LEVEL_LOG="$2"
            shift 2
            ;;
        --log-level-stdout)
            require_arg "$@"
            is_int "$2" || die 2 "bad opt: level-stdout is not int"
            SHLOG_LEVEL_STDOUT="$2"
            shift 2
            ;;
        -*)
            die 2 "Option -$1 not implemented yet"
            ;;
        *)
            printf "SHLOG_INIT: Unknown option \`%s\`\n" "$1" >&2
            SHLOG_USAGE
            exit 1
            ;;
        esac
    done
    : ${SHLOG_FORMAT_STDOUT:=$SHLOG_FORMAT}
    : ${SHLOG_FORMAT_LOG:=$SHLOG_FORMAT_STDOUT}
    : ${SHLOG_LEVEL_STDOUT:=$SHLOG_LEVEL}
    : ${SHLOG_LEVEL_LOG:=$SHLOG_LEVEL_STDOUT}
}
# TODO: Test max_size and max_width and others

# ==============================================================================
# REGISTRATION
# ==============================================================================

SHLOG_REGISTER_USAGE() {
    cat <<-EOF
	Usage: source ./shlog.sh [options]

	Options:
	-h, --help               Show this help message and exit
	-l, --lvl, --level       Set the base log level name (automatically uppercased)
	-e, --evt, --event       Set the event identifier (supports pipes: EVENT1|EVENT2)
	-i, --int                Set the integer severity level (defaults to -0)
	-c, --clr, --color       Set the color code and style (e.g., b:1 for bold red)
	-s, --sym, --symbol      Set a single-character visual symbol (e.g., > or ~)
	-t, --tag                Set the string tag for log output (defaults to event ID)

	Formatting:              Fallback: Event Target > Level Target > Global Format
	-f, --fmt, --format      Set the base format string for this event
	    --fmt-log            Set the format string specifically for log file output
	    --fmt-stdout         Set the format string specifically for standard output
	EOF
}

# TODO: Determine base options
# SHLOG_REGISTER [cache(path)|compile(bool)|...] [-options]
SHLOG_REGISTER() {
    fntrace="${fntrace:-SHLOG_REGISTER}"
    EventRegex='^(''|[[:alnum:]_*])+([|][[:alnum:]_*]+)*$'

    # Identifiers and targets
    _reg_map= _reg_lvl= _reg_evt= _reg_tgt=

    # Attributes
    _reg_int= _reg_clr= _reg_sym= _reg_tag=

    # Formatting
    _reg_fmt_stdout= _reg_fmt_log=

    while [ $# -gt 0 ]; do
        case "$1" in
        -h | --help)
            SHLOG_REGISTER_USAGE
            exit 0
            ;;
        -l | --lvl | --level)
            # Validate and normalize LEVEL (capitalize and remove symbols)
            require_arg "$@"
            is_alpha "$2" || die 2 "$1 $2" "invalid character(s)"
            _reg_lvl="$(printf '%s\n' "$2" | tr '[lower]' '[upper]')"
            shift 2
            ;;
        -i | --int)
            # Validate the log level integer.
            # Fallback to -0 provides a visual indicator that a value was omitted/invalid.
            require_arg "$@"
            _reg_int="$2"
            is_int "$_reg_int" || _reg_int=-0
            shift 2
            ;;
        -c | --clr | --color)
            require_arg "$@"
            # Validate and parse color
            __shlog_decode_colors "$2"
            shift 2
            ;;
        -e | --evt | --event)
            require_arg "$@"
            bad=$(printf '%s\n' $2 | grep -qE "$EventRegex") ||
                die 2 "illegal event pattern: '$bad'"
            _reg_evt="$2"
            shift 2
            ;;
        -s | --sym | --symbol)
            require_arg "$@"
            _reg_sym="$2"
            shift 2
            ;;
        -t | --tag)
            require_arg "$@"
            _reg_tag="$2"
            shift 2
            ;;
        -f | --fmt | --format)
            require_arg "$@"
            _reg_fmt="$2"
            shift 2
            ;;
        --fmt-stdout | --format-stdout)
            require_arg "$@"
            _reg_fmt_stdout="$2"
            shift 2
            ;;
        --fmt-log | --format-log)
            require_arg "$@"
            _reg_fmt_log="$2"
            shift 2
            ;;
        # TODO: change notation from to keep single character opts
        -d | --dest | --tgt | --target)
            require_arg "$@"
            _reg_tgt="$2"
            shift 2
            ;;
        -*)
            die 2 "ERROR: Option -$1 not implemented yet"
            ;;
        *)
            printf "Error: Unknown option \`%s\`\n" "$1" >&2
            SHLOG_REGISTER_USAGE
            exit 1
            ;;
        esac
    done

    # for var in $varlist; do debug $var; done

    # Normalize empty variables
    [ -z "$_reg_lvl" ] && die 2 "--level missing"
    [ -z "$_reg_int" ] && _reg_int=-0
    [ -z "$_reg_evt" ] && _reg_evt="$_reg_lvl"
    [ -z "$_reg_tag" ] && _reg_tag="\$_evt_id"
    [ "$INTERACTIVE_MODE" = "on" ] || _reg_clr=""

    # Logic to prevent doublettes of LEVEL=EVENT
    if [ "$_reg_evt" = "$_reg_lvl" ]; then
        case "$SHLOG_CORE_RULES" in
        *"$_reg_lvl|"*)
            __shlog_escape "$SHLOG_CORE_RULES" "$_reg_lvl|*"
            SHLOG_CORE_RULES="$SHLOG_ESCAPED_STRING"
            ;;
        esac
    else
        case "$SHLOG_CORE_RULES" in
        *"$_reg_lvl)"*) ;;
        *) _reg_evt="${_reg_lvl}${_reg_evt:+|${_reg_evt}}" ;;
        esac
    fi

    # Extract format
    # Hierarchy: SHLOG_REGISTER -> SHLOG_FORMAT_EVENT_TARGET -> SHLOG_FORMAT_LEVEL_TARGET -> SHLOG_FORMAT_TARGET
    __shlog_untangle_fmt STDOUT &&
        _reg_fmt_stdout="${_reg_fmt_stdout:-${_reg_fmt:-${SHLOG_UNTANGLED_FORMAT}}}"
    __shlog_untangle_fmt LOG &&
        _reg_fmt_log="${_reg_fmt_log:-${_reg_fmt:-${SHLOG_UNTANGLED_FORMAT}}}"

    if [ "$_reg_lvl" = "CUSTOM" ]; then
        _reg_tag="\$_evt_id"
        __shlog_add_rules CUSTOM_RULES
    else
        __shlog_add_rules CORE_RULES
    fi

    SHLOG_RULES=$(__shlog_print_rules)
}

# ==============================================================================
# MAPPING
# ==============================================================================

SHLOG_MAP() {
    fntrace="SHLOG_MAP"
    MapHeaderRegex='^(LEVEL|INT|COLOR|EVENT|SYM(BOL)?|TAG|FORMAT|TARGET)$'
    argv=

    while read -r line; do
        # 1. Parse Header
        if [ -z "$argv" ]; then
            argv="$(printf '%s\n' "$line")"
            bad=$(printf '%s\n' $argv | grep -Ev "$MapHeaderRegex") &&
                die 2 "invalid option in header: $bad"
            continue
        fi

        case "$line" in
        *\\*) line="$(printf '%s\n' "$line" | tr '\\' '/')" ;;
        esac

        # 2. Parse Data Row
        _assignments=$(
            printf '%s\n' "$line" | xargs printf '%s\n' | {
                for var in $argv; do
                    IFS= read -r value
                    case "$value" in
                    'x') value="" ;;
                    '/x') value="x" ;;
                    esac
                    printf '%s' "$var=\"$value\"; "
                done
            }
        )

        # 3. Execute register
        eval "$_assignments"

        SHLOG_REGISTER \
            --lvl "${LEVEL:-}" \
            --int "${INT:-}" \
            --clr "${COLOR:-}" \
            --evt "${EVENT:-${LEVEL:-}}" \
            --sym "${SYMBOL:-${SYM:-}}" \
            --tag "${TAG:-}" \
            --fmt "${FORMAT:-}" \
            --tgt "${TARGET:-}"

        unset $argv
    done
}
# ==============================================================================
# LOG
# ==============================================================================

# usage: log [-c color] [event] [message]
log() {
    _evt_id= _evt_tag= _evt_lvl= _evt_msg= _evt_color= _int_evt=

    OPTIND=1
    while getopts :c: OPT; do
        case $OPT in
        c) _evt_color="$(tput setaf "$OPTARG")" ;;
        :)
            echo "ERROR: Required parameter for -$OPT missing." >&2
            return 1
            ;;
        \?)
            echo "ERROR: Invalid option -$OPT." >&2
            return 1
            ;;
        esac
    done
    shift $((OPTIND - 1))

    # Extract event identifier and message
    _evt_id="MESSAGE" _evt_msg="$1"
    [ $# -gt 1 ] && {
        _evt_id="$1"
        shift
        _evt_msg="$*"
    }

    __shlog_normalize_identifier "$_evt_id"
    _evt_id="${SHLOG_NORMALIZED_IDENTIFIER:-INFO}"

    # Execute dynamic routing
    eval "$SHLOG_RULES"

    if [ "${SHLOG_OPTIMIZE:-0}" = "1" ]; then
        __shlog_date
    else
        _evt_time="$(date +"$SHLOG_DATE_FORMAT")"
    fi

    # Print to STDOUT
    _evt_stdout="SHLOG_PRINT_${_evt_id}_STDOUT"
    if [ "$_int_evt" -ge "$SHLOG_LEVEL_STDOUT" ]; then
        if ! command -v "$_evt_stdout" >/dev/null 2>&1; then
            __shlog_hash_djb2 "${#_evt_sym}${_evt_fmt_stdout}"
            __shlog_compile STDOUT "$_evt_fmt_stdout"
        fi
        printf '%b' "$_evt_color"
        "$_evt_stdout"
        printf '%b' "$SHLOG_SGR0"
    fi

    # Write to LOG
    [ -n "${SHLOG_PATH:-}" ] || return 0
    _evt_log="SHLOG_PRINT_${_evt_id}_LOG"
    if [ "$_int_evt" -ge "$SHLOG_LEVEL_LOG" ]; then
        if ! command -v "$_evt_log" >/dev/null 2>&1; then
            __shlog_hash_djb2 "${#_evt_sym}${_evt_fmt_log}"
            __shlog_compile LOG "$_evt_fmt_log"
        fi
        # __shlog_rotate
        "$_evt_log" >>"$SHLOG_PATH"
    fi
    return 0
}

# Enable POSIX shell features
log_entry() { log "ENTRY" "$SCRIPT_NAME:$_caller_lineno $*"; }
log_exit() { log "EXIT" "$SCRIPT_NAME:$_caller_lineno $*"; }
log_trace() { log "TRACE" "$SCRIPT_NAME:$_caller_lineno $*"; }
log_trace_in() { log "TRACE_IN" "$SCRIPT_NAME:$_caller_lineno $*"; }
log_trace_out() { log "TRACE_OUT" "$SCRIPT_NAME:$_caller_lineno $*"; }
log_debug() { log "DEBUG" "$@"; }
log_verbose() { log "VERBOSE" "$@"; }
log_info() { log "INFO" "$@"; }
log_success() { log "SUCCESS" "$@"; }
log_error() { log "ERROR" "$@"; }
log_warning() { log "WARNING" "$@"; }
log_fatal() { log "FATAL" "$@"; }

# Detect which shell is running
case "${ZSH_VERSION:+zsh}:${BASH_VERSION:+bash}" in
zsh:*)
    SCRIPT_EXTENSION="zsh"
    _sh_fun='${funcstack[1]:-MAIN}'
    _sh_src='${(%):-%x}'
    ;;
*:bash)
    SCRIPT_EXTENSION="bash"
    shopt -s expand_aliases
    _sh_fun='${FUNCNAME[0]:-MAIN}'
    _sh_src='${BASH_SOURCE[1]:-${BASH_SOURCE[0]:-$0}}'
    ;;
*)
    SCRIPT_EXTENSION="sh"
    _sh_src='$SCRIPT_NAME'
    ;;
esac

# SHLOG_CAPTURE_CTX
if [ "${SHLOG_CAPTURE_CTX:-0}" = "1" ]; then
    if [ "$SCRIPT_EXTENSION" = "bash" ]; then
        # Check expand_aliase state; die if disabled
        shopt -q expand_aliases ||
            die 1 "SHLOG_CAPTURE_CTX requires 'shopt -s expand_aliases'"
    fi

    p1='_caller_rc=$?'
    p2='_caller_pid=$$'
    p3='_caller_cwd="$PWD"'
    p4='_caller_lineno=$LINENO'
    p5='_caller_sec=${SECONDS:-}'
    p6="_caller_fn=\"${_sh_fn:-$SCRIPT_NAME}\""
    p7="_caller_src=\"${_sh_src:-$SCRIPT_NAME}\""
    params="$p1; $p2; $p3; $p4; $p5; $p6; $p7"

    cmds="entry exit trace trace_in trace_out debug verbose info success error warning fatal"

    for cmd in $cmds; do
        alias "log_$cmd=$params; log_$cmd"
    done
fi
# === END INCLUDES ===

SHLOG_INIT --enable-cache \
    --enable-rotate max_size=1000 max_files=5 \
    --format "[%date] [%label?7<-2|sym] %sym %message" \
    --date-format "%Y-%m-%d %H:%M:%S" \
    --optimize tz='UTC+1' \
    --log-level -3

SHLOG_MAP <<EOF
INT  LEVEL    EVENT        TAG      SYM  COLOR
-3   CUSTOM   x            x        x    69
-3   TRACE    ENTRY        x        >    8
-3   TRACE    TRACE_IN     TRACE    >    8
-3   TRACE    TRACE        TRACE    ~    8
-3   TRACE    TRACE_OUT    TRACE    <    8
-3   TRACE    EXIT         x        <    8
-2   DEBUG    x            x        x    4
-1   VERBOSE  x            x        x    6
0    INFO     MSG|MESSAGE  x        x    x
0    SUCCESS  x            x        x    2
1    WARNING  WARN         x        x    3
2    ERROR    x            x        x    1
3    FATAL    x            x        x    b:1
EOF

call_logs() {
    log CUSTOM "custom"
    log_trace "trace"
    log_trace_in "trace_in"
    log_trace_out "trace_out"
    log_entry "entry"
    log_exit "exit"
    log_debug "debug"
    log_verbose "verbose"
    log_info "info"
    log_success "success"
    log_warning "warning"
    log_error "error"
    log_fatal "fatal"
}

# if [ -z "${SHLOG_PATH:-}" ]; then
#     SHLOG_PATH="/var/log/shlog/$SCRIPT_NAME"
# fi
#

# Add this to source shlog from anywhere
# SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# SHLOG_PATH="/var/log/shlog/$(basename -- $0)"
# source "$SCRIPT_DIR/../../thirdparty/shlog.sh"

trap 'tput sgr0; __shlog_sort_cache' EXIT HUP INT TERM
