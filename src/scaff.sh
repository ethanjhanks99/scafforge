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

add_tool() {
  echo "add tool logic"
}

rm_tool() {
  echo "remove tool logic"
}

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
    if [[ "$COMMAND" == "init" ]]; then
      NAME="$SUBCOMMAND"
      workspace
    elif [[ "$SUBCOMMAND" == "create" ]]; then
      NAME="$1"
      shift
      workspace
    fi
    ;;

  project|new)
    if [[ "$COMMAND" == "new" ]]; then
      NAME="$SUBCOMMAND"
      project
    elif [[ "$SUBCOMMAND" == "create" ]]; then
      NAME="$1"
      shift
      project
    fi
    ;;

  tool|add)
    if [[ "$COMMAND" == "add" ]]; then
      NAME="$SUBCOMMAND"
      add_tool
    elif [[ "$COMMAND" == "tool" ]]; then
      if [[ "$SUBCOMMAND" == "add" ]]; then
        
        NAME="$1"
        if [[ -n "$NAME" ]]; then 
          shift 
        else
          usage
          exit 1
        fi        

        add_tool
      elif [[ "$SUBCOMMAND" == "rm" ]]; then
        NAME="$1"
        
        if [[ -n "$NAME" ]]; then 
          shift 
        else
          usage
          exit 1
        fi        

        rm_tool
      fi
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

