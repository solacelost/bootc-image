#!/bin/bash

set -e

initialize.py &
initialize_pid="$!"

trap 'kill $initialize_pid ||:' EXIT

dotnet bin/Release/net8.0/Sidekick.dll --urls 'http://:::5000' "${@}"
