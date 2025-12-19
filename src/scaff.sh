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

action=$1
entity_type=$2
name=$3

echo "action: $action"
echo "entity-type: $entity_type"
echo "name: $name"
