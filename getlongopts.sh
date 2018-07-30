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
#   0|no           -- option does not take an argument
#   1|required|yes -- option takes a required argument
#   2|optional|?   -- option takes an optional argument
#
# After a successful invocation of `getlongopts` processes a long
# option, `getlongopts` sets LONGOPTARGS, an array, to the argument(s)
# passed that specified the long option.

declare -a LONGOPTARGS
getlongopts () {
    if (( $# < 3 )) ; then
        >&2 echo "getlongopts: usage: getlongopts <optstring> <name> [<longoptname> <longopttype> ...] -- [<arg> ...]"
        return 2
    fi

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
    # `getlongopts` after terminating "--" or "" argument.

    # Run `getopts` builtin; check for failure code.
    getopts "${optstring}-:" "${name}"
    if (( $? )) ; then
        return $?
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
        else
            OPTARG="${longoptname}"
        fi
        return 1
    fi

    type="${longoptions[${longoptname}]}"
    case "$type" in
        "2")
            printf -v "$name" '%s' "$longoptname"
            unset OPTARG
            [[ -v "longoptvalue" ]] && OPTARG="${longoptvalue}"
            return 0
            ;;
        "1")
            if [[ -v "longoptvalue" ]] ; then
                printf -v "$name" '%s' "$longoptname"
                OPTARG="${longoptvalue}"
                return 0
            elif (( $OPTIND <= $# )) ; then
                eval "longoptvalue=\${$((OPTIND - 1))}"
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
                else
                    printf -v "$name" '%s' ':'
                    OPTARG="${!name}"
                fi
                return 1
            fi
            ;;
        "0")
            if [[ -v "longoptvalue" ]] ; then
                >&2 echo "$0: --${longoptname} takes no argument."
                return 1
            fi
            printf -v "$name" '%s' "$longoptname"
            unset OPTARG
            return 0
            ;;
    esac
}
