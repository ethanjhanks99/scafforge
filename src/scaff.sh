#!/bin/bash

usage() {
  echo "Usage: scaffold <action> <entity_type> <name> [options] " >&2
  exit 1
}

workspace() {
  echo "workspace logic"
}

project() {
  echo "project logic"
}

tool() {
  echo "tool logic"
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
      workspace
    elif [[ "$SUBCOMMAND" -eq "create" ]]; then
      NAME="$1"
      shift
      workspace
    fi

  project|new)
    if [[ "$COMMAND" -eq "new" ]]; then
      NAME="$SUBCOMMAND"
      project
    elif [[ "$COMMAND" -eq "create" ]]; then
      NAME="$1"
      shift
      project
    fi
    ;;

  tool|add)
    if [[ "$COMMAND" -eq "add" ]]; then
      NAME="$SUBCOMMAND"
      tool
    elif [[ "$COMMAND" -eq "tool" ]]; then
      NAME="$1"
      shift
      tool
    fi
    ;;

  *)
    usage
    exit 1
ENTITY="$1"

if [[ -n "$ENTITY" ]]; then shift; fi 

NAME="$1"

if [[ -n "$NAME" ]]; then shift; fi 


while [[ $# -gt 0 ]]; do
  case "$1" in 

    -t|--type)

done

