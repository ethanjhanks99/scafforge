#!/bin/bash

usage() {
  echo "Usage: scaffold <action> <entity_type> <name> [options] " >&2
  exit 1
}

if [[ $@ < 4 ]]; then
  echo "Insufficient arguments provided!"
  usage
  exit 1
fi

COMMAND="$1"

if [[ -n "$COMMAND" ]]; then shift; fi

SUBCOMMAND="$1"

if [[ -n "$SUBCOMMAND" ]] then shift; fi 

case "$COMMAND" in 
  -h|--help)
    usage()
    exit 0
    ;;
  workspace|init)
    if [[ "$COMMAND" -eq "init" ]]; then
      NAME="$SUBCOMMAND"
    elif [[ "$SUBCOMMAND" -eq "create" ]]; then
      NAME="$1"
    fi

ENTITY="$1"

if [[ -n "$ENTITY" ]]; then shift; fi 

NAME="$1"

if [[ -n "$NAME" ]]; then shift; fi 


while [[ $# -gt 0 ]]; do
  case "$1" in 

    -t|--type)

done

