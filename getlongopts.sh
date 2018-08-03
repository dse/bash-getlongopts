# -*- mode: sh-mode; sh-shell: bash -*-

# usage:
#     getlongopts <optstring> <name> [<longoptname> <longopttype> ...] -- "$@"
#
# The <optstring> and <name> are the same as in the first two
# arguments of the `getopts` builtin.
#
# Each <longoptname> is a long option name.
#
# Each <longopttype> is one of the following:
#
#     0|no -- option does not take an argument
#
#     1|required|yes -- option takes a required argument; can be
#                       specified via one argument
#                       (`--<name>=<value>`) or two
#                       (`--<name> <value>`)
#
#     2|optional|"?" -- option takes an optional argument; must be
#                       specified via `--<name>=<value>`
#
# After a successful invocation of `getlongopts` processes a long
# option, `getlongopts` sets LONGOPTARGS, an array, to the argument(s)
# passed that specified the long option.  If a long option is
# specified with an argument via `--<name> <value>`, then LONGOPTARGS
# contains two elements: `--<name>` and `<value>`; in all other
# situations, LONGOPTARGS contains one element.
#
# If `getlongopts` processes a short option; side effects, return
# value, and other behavior are exactly the same as with the `getopts`
# builtin, and the LONGOPTARGS array is emptied.
#
# If `getlongopts` processes a long option:
#
# - The "--" argument by itself ends option parsing; OPTARG is unset,
#   LONGOPTARGS is emptied, and `getlongopts` returns a nonzero value.
#   Modulo LONGOPTARGS, this is the same as if `getopts` or
#   `getlongopts` encounters the first non-option argument.
#
# - If an invalid long option is specified; side effects, return
#   value, and other behavior are the same as when `getopts` or
#   `getlongopts` processes an invalid short option.  In addition,
#   LONGOPTARGS contains "--<name>" or "--<name>=<value>" if silent
#   error reporting is in effect, or is emptied otherwise.
#
# - If a long option is missing its required argument; side effects,
#   return value, and other behavior are exactly the same as when
#   `getopts` or `getlongopts` processes a short option missing its
#   required argument.  In addition, LONGOPTARGS contains "--<name>"
#   if silent error reporting is in effect, or is emptied otherwise.
#
# - If a long option that takes no argument is supplied with an
#   argument via "--<name>=<value>", then <name> is set to "?", OPTARG
#   is unset, an error message is issued, and LONGOPTARGS is empted.
#   If silent error reporting is in effect, <name> is set to ":",
#   OPTARG is set to the name of the option, and LONGOPTARGS contains
#   "--<name>".
#
# RESTRICTIONS
#
# `getlongopts`, like `getopts`, requires that all options come before
# non-option arguments.  This includes long options.
#
# `getlongopts`, like `getopts`, does not support short options with
# optional parameters.  It supports long options with optional
# parameters, however.

declare -a LONGOPTARGS
getlongopts () {
    if (( $# < 3 )) ; then
        >&2 echo "getlongopts: usage: getlongopts <optstring> <name> [<longoptname> <longopttype> ...] -- [<arg> ...]"
        return 2
    fi

    local result
    local optstring="$1"; shift
    local name="$1"; shift

    # check for silent error reporting
    local silent=0
    if [[ "$optstring" = ":"* ]] ; then
        silent=1
    fi

    LONGOPTARGS=()

    # collect long options into associative array
    local -A longoptions
    while (( $# >= 3 )) && [[ "$1" != "--" ]] ; do
        case "$2" in
            "0"|"no")
                longoptions["$1"]=0
                ;;
            "1"|"required"|"yes")
                longoptions["$1"]=1
                ;;
            "2"|"optional"|"?")
                longoptions["$1"]=2
                ;;
            *)
                >&2 echo "getlongopts: invalid type: $2"
                return 1
        esac
        shift 2
    done

    # Make sure "--" is used to terminate long option arguments.
    if (( !$# )) && [[ "$1" != "--" ]] ; then
        (( !$silent )) && [[ "${OPTERR}" != "0" ]] && >&2 echo "getlongopts: long options not terminated with \"--\""
        unset OPTARG
        return 2
    fi

    shift

    # positional arguments are now the arguments passed into
    # `getlongopts` after terminating "--" argument.

    # Run `getopts` builtin; check for failure code.
    getopts "${optstring}-:" "${name}"
    result="$?"
    if (( $result )) ; then
        return $result
    fi

    # Check for short option.
    if [[ "${!name}" != "-" ]] ; then
        return 0
    fi

    # Argument "--" found; end of option parsing.  OPTIND should be
    # correct.
    if [[ "${OPTARG}" = "" ]] ; then
        printf -v "${name}" '%s' '?'
        return 1
    fi

    local type                  # 0, 1, or 2
    local longoptname
    local longoptvalue

    LONGOPTARGS=("--${OPTARG}")
    case "${OPTARG}" in
        *=*)
            longoptname="${OPTARG%%=*}"
            longoptvalue="${OPTARG#*=}"
            ;;
        *)
            longoptname="${OPTARG}"
            ;;
    esac

    # Check for invalid option
    if [[ ! -v "longoptions[${longoptname}]" ]] || [[ "${longoptname}" = *"["* ]] || [[ "${longoptname}" = *"]"* ]] ; then
        printf -v "$name" '%s' '?'
        if (( !$silent )) ; then
            [[ "${OPTERR}" != "0" ]] && >&2 echo "$0: invalid option: --${longoptname}"
            unset OPTARG
            LONGOPTARGS=()
        else
            OPTARG="${longoptname}"
        fi
        return 1
    fi

    type="${longoptions[${longoptname}]}"
    case "$type" in
        "2")                    # takes optional argument
            printf -v "$name" '%s' "$longoptname"
            unset OPTARG
            [[ -v "longoptvalue" ]] && OPTARG="${longoptvalue}"
            return 0
            ;;
        "1")                    # takes required argument
            if [[ -v "longoptvalue" ]] ; then
                printf -v "$name" '%s' "$longoptname"
                OPTARG="${longoptvalue}"
                return 0
            elif (( $OPTIND <= $# )) ; then
                eval "longoptvalue=\${$((OPTIND))}"
                LONGOPTARGS+=("${longoptvalue}")
                OPTIND=$((OPTIND + 1))
                printf -v "$name" '%s' "$longoptname"
                OPTARG="${longoptvalue}"
                return 0
            else
                if (( !$silent )) ; then
                    printf -v "$name" '%s' '?'
                    unset OPTARG
                    [[ "${OPTERR}" != "0" ]] && >&2 echo "$0: --${longoptname}: missing argument"
                    LONGOPTARGS=()
                else
                    printf -v "$name" '%s' ':'
                    OPTARG="${!name}"
                fi
                return 1
            fi
            ;;
        "0")                    # takes no argument
            if [[ -v "longoptvalue" ]] ; then
                if (( !$silent )) ; then
                    printf -v "$name" '%s' '?'
                    unset OPTARG
                    [[ "${OPTERR}" != "0" ]] && >&2 echo "$0: --${longoptname} takes no argument."
                    LONGOPTARGS=()
                else
                    printf -v "$name" '%s' ':'
                    OPTARG="${!name}"
                fi
                return 1
            fi
            printf -v "$name" '%s' "$longoptname"
            unset OPTARG
            return 0
            ;;
    esac
}
