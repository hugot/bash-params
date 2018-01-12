#!/bin/bash
##
#
# Author: Hugo Thunnissen <hugo.thunnissen@gmail.com>
# License: see LICENSE file
#
##
# Parse parameters of requested types for funcions in bash.
# usage: [ expected variables ] -- [ values that were passed ]
# Expected variables here are the datatype + the name of the variable.
# The variable needs to be declared before calling this function so 
# that it can be defined by referece.
# Options are:
# -a, --array     [ variable name ]
# -d, --dicionary [ variable name ]
# -s, --string    [ variable name ]
# -i, --int       [ variable name ]
#
# After defining the data types and the variable names, you can start passing the values
# tht should be assigned to them, preceded by their data types. To define the datatypes, 
# you can use options by the same name:
# -a, --array [ array values ]
# -d, --dictionary [ -k, --keys [ keys ] ] [ -v, --values [ values ] ]
# -s, --string     [ value ]
# -i, --int        [ value ]
# 
# Example usahge in a function:
# 
# printArrayAndDictionary() {
#   declare -a array
#   declare -A dictionary
#
#   Params::parse --array array --dictionary dictionary -- "$@"
#
#   echo "Array values: ${array[*]}"
#   echo "Dictionary keys: ${!dictionary[*]}"
#   echo "Dictionary values: ${dictionary[*]}"
# }
#
# Calling the function:
# declare -a array=(item1 item2 item3)
# declare -A dict
# dict[key1]="item1"
# dict[ley2]="item2"
#
# printArrayAndDictionary \
#  --array "${array[@]}" \
#  --dictionary --keys "${!dict[@]}" --values "${dict[@]}"
Params::parse() {
  declare -a expected_types=()
  declare -a variable_names=()
  declare -r UNEXPECTED_TYPE='Params: %s : expected %s for argument %d, got %s\n'

  # First parse the expected types and variable names.
  declare argument="$1"
  while shift && [[ "$argument" != '--' ]]; do
    if [[ "$1" == 'var' ]]; then
      echo 'Due to limitations in passing variables by reference, variables' \
        $'can not be named \'var\' when using Params_parse. Please use a different name.' >&2
      return 1
    elif ! declare -p "$1" &>>/dev/null; then
      echo "Params: $(caller): variable $1 is not defined. Please define it before calling Params_parse." >&2
      return 1
    fi

    case "$argument" in
      -a | --array)
        expected_types[${#expected_types[@]}]="array"
        variable_names[${#variable_names[@]}]="$1"
        shift
        ;;
      -i | --int)
        expected_types[${#expected_types[@]}]="integer"
        variable_names[${#variable_names[@]}]="$1"
        shift
        ;;
      -s | --string)
        expected_types[${#expected_types[@]}]="string"
        variable_names[${#variable_names[@]}]="$1"
        shift
        ;;
      -d | --dictionary)
        expected_types[${#expected_types[@]}]="dictionary"
        variable_names[${#variable_names[@]}]="$1"
        shift
        ;;
      *)
        echo "Unexpected argument: '$argument'" >&2
        return 1
        ;;
    esac
    argument="$1"
  done

  if [[ $# -eq 0 ]]; then
    echo "Params: $(caller): No parameters were passed to parse." >&2
    return 1
  fi

  # Parse the given arguments
  argument="$1"
  declare -i i=-1
  while shift; do
    let i++
    case "$argument" in
      -a | --array)
        if [[ "${expected_types[$i]}" != 'array' ]]; then
          printf "$UNEXPECTED_TYPE" "$(caller)" "${expected_types[$i]}" "$i" "$argument" >&2
          return 1

        fi

        declare -n var="${variable_names[$i]}"
        var=()
        declare item="$1"
        declare -i x=0
        while [[ $item != -* ]] && shift; do
          [[ "$item" == \\-* ]] && item="${item/\\/}"
          var[$x]="$item"
          let x++
          item="$1"
        done
        echo "${var[@]}"
        ;;
      -s | --string)
        if [[ "${expected_types[$i]}" != 'string' ]]; then
          printf "$UNEXPECTED_TYPE" "$(caller)" "${expected_types[$i]}" "$i" "$argument" >&2
          return 1
        fi
        declare -n var="${variable_names[$i]}"
        var="$1"
        shift
        ;;
      -i | --int)
        if [[ "${expected_types[$i]}" != 'integer' ]]; then
          printf "$UNEXPECTED_TYPE" "$(caller)" "${expected_types[$i]}" "$i" "$argument" >&2
          return 1
        elif [[ "$1" != +([0-9]) ]]; then
          echo "Params: $(caller): '$1' is not an integer." >&2
          return 1
        fi
        declare -n var="${variable_names[$i]}"
        var="$1"
        shift
        ;;
      -d | --dictionary)
        if [[ "${expected_types[$i]}" != 'dictionary' ]]; then
          printf "$UNEXPECTED_TYPE" "$(caller)" "${expected_types[$i]}" "$i" "$argument" >&2
          return 1
        elif [ "$1" != '--keys' -a "$1" != '-k' ]; then
          echo 'Params: '"$(caller)"': dictionary expected "keys" flag "-k" or "--keys".' >&2
          return 1
        fi

        declare -a keys=()
        declare key=''
        declare -i x=0
        while shift && [[ "$1" != -* ]]; do
          key="$1"
          [[ "$key" == \\-* ]] && key="${key/\\/}"
          keys[$x]="$1"
          let x++
        done
        if [ "$1" != '--values' -a "$1" != '-v' ]; then
          echo 'Params: '"$(caller)"': dictionary expected values flag "-v" or "--values" after keys flag.' >&2
          return 1
        fi

        declare -a values=()
        declare value=''
        x=0
        while shift && [[ "$1" != -* ]] && [ "$1" != '' ]; do
          value="$1"
          [[ "$value" == \\-* ]] && value="${value/\\/}"
          values[$x]="$value"
          let x++
        done

        if [[ ${#keys[@]} -ne ${#values[@]} ]]; then
          echo "Unbalanced set of keys and values. Got ${#keys[@]} keys and ${#values[@]} values." >&2
          echo "Keys: $(printf '%s, ' "${keys[@]}") values: $(printf '%s, ' "${values[@]}")" >&2
          return 1
        fi

        declare -n var="${variable_names[$i]}"
        var=()
        for ((x = 0; x < ${#keys[@]}; x++)); do
          var["${keys[$x]}"]="${values[$x]}"
        done
        ;;
      *)
        echo "Params: Unexpected argument: $argument" >&2
        return 1
        ;;
    esac
    argument="$1"
  done
  return 0
}
