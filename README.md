# getlongopts-bash

A bash function for processing long options and short options

## Usage

    getlongopts <optstring> <name> [<longoptname> <longopttype> ...] -- "$@"

## Arguments

- <var>optstring</var> should not contain `-`.  It is otherwise the
  same as in `getopts`.

- <var>name</var> is the same as in `getopts`.

- Each <var>longoptname</var> is a long option name, such as `verbose`
  or `dry-run`.

- Each <var>longopttype</var> is one of the following values:

  - `0` or `no` -- option does not take an argument.

  - `1`, `required`, or `yes` -- option takes a required argument.

    The argument can be specified via the one-argument form,
    `--<name>=<value>`, or the two-argument form, `--<name> <value>`.

  - `2`, `optional`, or `"?"` -- option takes an optional argument.

    The argument must be specified via the one-argument form,
    `--<name>[=<value>]`.

- `--` must be used to terminate the long option names and types.

- Positional parameters (`"$@"`) must be specified, as `getlongopts`
  is not a shell builtin and does not have access to them.

## Description

After a successful invocation of `getlongopts` processes a long
option, `getlongopts` sets `LONGOPTARGS`, an array, to the argument(s)
passed that specified the long option.  If a long option is specified
with an argument via `--<name> <value>`, then `LONGOPTARGS` contains
two elements: `--<name>` and `<value>`; otherwise, LONGOPTARGS
contains one element.

If `getlongopts` processes a short option; side effects, return value,
and other behavior are exactly the same as with the `getopts` builtin,
and the `LONGOPTARGS` array is emptied.

If `getlongopts` processes a long option:

- The `"--"` argument by itself ends option parsing; `OPTARG` is
  unset, `LONGOPTARGS` is emptied, and `getlongopts` returns a nonzero
  value.  Modulo `LONGOPTARGS`, this is the same as if `getopts` or
  `getlongopts` encounters the first non-option argument.

- If an invalid long option is specified; side effects, return value,
  and other behavior are the same as when `getopts` or `getlongopts`
  processes an invalid short option.  In addition, `LONGOPTARGS`
  contains `--<name>` or `--<name>=<value>` if silent error reporting
  is in effect, or is emptied otherwise.

- If a long option is missing its required argument; side effects,
  return value, and other behavior are exactly the same as when
  `getopts` or `getlongopts` processes a short option missing its
  required argument.  In addition, `LONGOPTARGS` contains `--<name>`
  if silent error reporting is in effect, or is emptied otherwise.

- If a long option that takes no argument is supplied with an argument
  via `--<name>=<value>`, then `<name>` is set to `"?"`, `OPTARG` is
  unset, an error message is issued, and `LONGOPTARGS` is empted.  If
  silent error reporting is in effect, `<name>` is set to ":",
  `OPTARG` is set to the name of the option, and `LONGOPTARGS`
  contains `--<name>`.

## Restrictions

`getlongopts`, like `getopts`, requires that all options come before
non-option arguments.  This includes long options.

`getlongopts`, like `getopts`, does not support short options with
optional parameters.  It supports long options with optional
parameters, however.

Multiple aliases to the same option must be specified individually.

`getlongopts` does not process incomplete option names.

## Example

    declare -a patterns

    patterns=()
    dry_run=0
    verbose=0
    color=""

    declare -a longoptions
    longoptions=(
        help    no
        dry-run no
        verbose no
        regexp  yes
        color   optional
        colour  optional
    )

    while getlongopts "hnve" OPTION "${longoptions[@]}" -- "$@" ; do
        case "${OPTION}" in
            h|help)
                usage; exit 0;;
            v|verbose)
                verbose=$((verbose + 1));;
            n|dry-run)
                dry_run=1;;
            e|regexp)
                patterns+=("${OPTARG}");;
            color|colour)
                if [[ -v "OPTARG" ]] ; then
                    color="${OPTARG}"
                else
                    color=default
                fi
            "?")
                exit 1;;
        esac
    done
    shift $((OPTIND - 1))
