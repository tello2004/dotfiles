#!/usr/bin/env bash

set -o pipefail

[ ! -f /run/.toolboxenv ] && return

host_env=$(flatpak-spawn --host env | sort -t '=' -k1,1)
container_env=$(env | sort -t '=' -k1,1)

host_path=$(echo "$host_env" | grep '^PATH=' | sed 's/^PATH=//' || true)
if [ -n "$host_path" ]; then
    declare -gx PATH="$host_path"
fi

missing_vars=$(join -t '=' -v 1 \
    <(echo "$host_env" | sort -t '=' -k1,1) \
    <(echo "$container_env" | sort -t '=' -k1,1))

if [ -z "$missing_vars" ]; then
    return 0
fi

while IFS= read -r line; do
    var_name="${line%%=*}"
    var_value="${line#*=}"

    [ -z "$var_name" ] && continue

    declare -gx "$var_name=$var_value"
done <<< "$missing_vars"

return 0
