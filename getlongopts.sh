# -*- mode: sh-mode; sh-shell: bash -*-

# option names:
#     f
#     foo
#     f|foo
# suffixes
#     =[<type>]
#     :[<type>]
_getlongoptionadd () {
    local optionname
    local optionrequired
    local -a optionnames
    local i

    optionname="$1"; shift
    optionrequired="$1"; shift

    IFS='|,' read -r -a optionnames <<<"${optionname}"
    for i in "${optionnames[@]}" ; do
        if [[ "${i}" =~ ^.$ ]] ; then # emacs won't indent `case ... in ?)` properly.  sad face.
            case "${optionrequired}" in
                "0"|"no")
                    optstring="${i}${optstring}"
                    ;;
                "1"|"required"|"yes")
                    optstring="${i}:${optstring}"
                    ;;
                "2"|"optional"|"?")
                    # NOTE: short options cannot take optional values.
                    # it'll be required when specifying the short option.
                    optstring="${i}:${optstring}"
                    ;;
            esac
        else
            case "${optionrequired}" in
                "0"|"no")
                    longoptions["${i}"]=0
                    ;;
                "1"|"required"|"yes")
                    longoptions["${i}"]=1
                    ;;
                "2"|"optional"|"?")
                    longoptions["${i}"]=2
                    ;;
            esac
        fi
    done
}

declare -a LONGOPTARGS
getlongopts () {
    local result
    local optstring
    local name
    local silent
    local optprefix
    local -A longoptions
    local longoptstype
    local optionrequired
    local optionname
    local oldOPTIND
    local optnumargs
    local i
    local type                  # 0|no, 1|yes|required, or 2|optional
    local longoptname
    local longoptvalue

    if (( $# < 3 )) ; then
        >&2 echo "getlongopts: usage: getlongopts <optstring> <name> [--type-1] [<longoptname> <longopttype> ...] -- [<arg> ...]"
        return 2
    fi

    optstring="$1"; shift
    name="$1"; shift

    # check for silent error reporting
    silent=0
    optprefix=""
    if [[ "$optstring" = ":"* ]] ; then
        silent=1

        # so we can prepend to optstring; we'll reconstruct later
        optprefix=":"
        optstring="${optstring#:}"
    fi

    LONGOPTARGS=()

    # collect long options into associative array
    longoptstype=1
    if (( $# >= 1 )) ; then
        case "$1" in
            --type-1)
                longoptstype=1
                shift
                ;;
            --type-2)
                longoptstype=2
                shift
                ;;
            -*)
                >&2 echo "getlongopts: invalid longopts type: $1"
                return 1
        esac
    fi

    if (( longoptstype == 1 )) ; then
        while (( $# >= 3 )) && [[ "$1" != "--" ]] ; do
            optionname="$1"
            case "$2" in
                "0"|"no")
                    optionrequired=no
                    ;;
                "1"|"required"|"yes")
                    optionrequired=yes
                    ;;
                "2"|"optional"|"?")
                    optionrequired=optional
                    ;;
                *)
                    >&2 echo "getlongopts: invalid type: $2"
                    return 1
            esac
            _getlongoptionadd "${optionname}" "${optionrequired}"
            shift 2
        done
    elif (( longoptstype == 2 )) ; then
        while (( $# >= 2 )) && [[ "$1" != "--" ]] ; do
            optionname="$1"
            optionrequired="no"
            case "$1" in
                *=*)
                    optionname="${optionname%%=*}"
                    optionrequired=yes
                    ;;
                *:*)
                    optionname="${optionname%%:*}"
                    optionrequired=optional
                    ;;
            esac
            _getlongoptionadd "${optionname}" "${optionrequired}"
            shift
        done
    else
        return 1
    fi

    # Make sure "--" is used to terminate long option arguments.
    if (( !$# )) && [[ "$1" != "--" ]] ; then
        (( !$silent )) && [[ "${OPTERR}" != "0" ]] && >&2 echo "getlongopts: long options not terminated with \"--\""
        unset OPTARG
        return 2
    fi

    shift

    # reconstruct $optstring
    optstring="${optprefix}${optstring}"
    optprefix=""

    # positional arguments are now the arguments passed into
    # `getlongopts` after terminating "--" argument.

    # for checking if short option is one or two arguments
    oldOPTIND="${OPTIND}"
    optnumargs=1

    # Run `getopts` builtin; check for failure code.

    getopts "${optstring}-:" "${name}"
    result="$?"
    if (( $result )) ; then
        return $result
    fi

    # Check for short option.
    if [[ "${!name}" != "-" ]] ; then
        optnumargs=$((OPTIND - oldOPTIND))
        if (( optnumargs == 1 )) ; then
            # -x or -x<value>
            LONGOPTARGS=("-${!name}${OPTARG}")
        elif (( optnumargs == 2 )) ; then
            # -x <value>
            LONGOPTARGS=("-${!name}" "${OPTARG}")
        else
            >&2 echo "getlongopts: UNEXPECTED ERROR 1"
            LONGOPTARGS=()
            return 1
        fi
        return 0
    fi

    # Argument "--" found; end of option parsing.  OPTIND should be
    # correct.
    if [[ "${OPTARG}" = "" ]] ; then
        printf -v "${name}" '%s' '?'
        return 1
    fi

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
        "2"|"optional"|"?")     # takes optional argument
            printf -v "$name" '%s' "$longoptname"
            unset OPTARG
            [[ -v "longoptvalue" ]] && OPTARG="${longoptvalue}"
            return 0
            ;;
        "1"|"required"|"yes")   # takes required argument
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
        "0"|"no")               # takes no argument
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
