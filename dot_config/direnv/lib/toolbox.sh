# -*- mode: sh -*-
# shellcheck shell=bash

BOX_DIRENV_VERSION=0.2.1

# min required versions
BASH_MIN_VERSION=4.4
DIRENV_MIN_VERSION=2.21.3
TOOLBOX_MIN_VERSION=0.1.0

_box_direnv_warning() {
    if [[ -n $DIRENV_LOG_FORMAT ]]
    then
        local msg=$* color_normal='' color_warning=''
        if [[ -t 2 ]]
        then
            color_normal="\e[m"
            color_warning="\e[33m"
        fi
        # shellcheck disable=SC2059
        printf "${color_warning}${DIRENV_LOG_FORMAT}${color_normal}\n" \
            "${_BOX_DIRENV_LOG_PREFIX}${msg}">&2
    fi
}

_require_version() {
    local cmd=$1 version=$2 required=$3
    if ! printf "%s\n" "$required" "$version" | LC_ALL=C sort -c -V 2>/dev/null
    then
        log_error \
            "minimum required $(basename "$cmd") version is $required (installed: $version)"
        return 1
    fi
}

_require_cmd_version() {
    local cmd=$1 required=$2 version
    if ! has "$cmd"
    then log_error "command not found: $cmd"
        return 1
    fi
    version=$($cmd --version)
    [[ $version =~ ([0-9]+\.[0-9]+\.?[0-9]?) ]]
    _require_version "$cmd" "${BASH_REMATCH[1]}" "$required"
}

box_direnv_version() {
    _require_version box-direnv $BOX_DIRENV_VERSION "$1"
}

_box_direnv_preflight() {
    if [[ -z $direnv ]]
    then
        # shellcheck disable=2016
        log_error '$direnv environment variable was not defined. Was this script run inside direnv?'
        return 1
    fi

    # check command min versions
    if [[ -z ${BOX_DIRENV_SKIP_VERSION_CHECK:-} ]]
    then
        if ! _require_version bash "$BASH_VERSION" "$BASH_MIN_VERSION" ||
            ! _require_cmd_version "$direnv" "$DIRENV_MIN_VERSION"
        then
            return 1
        fi
    fi

    local layout_dir
    layout_dir=$(direnv_layout_dir)

    if [[ ! -d "$layout_dir/bin" ]]
    then
        mkdir -p "$layout_dir/bin"
    fi

    cat >"${layout_dir}/bin/box-direnv-dump-paths" <<-EOF
#!/bin/bash
set -e

source /etc/profile

set -f
IFS=:
for p in \$PATH
do
    set +f
    [ -n "\$p" ] || p=.
    for f in "\$p"/.[!.]* "\$p"/..?* "\$p"/*
    do
        [ -f "\$f" ] && [ -x "\$f" ] && printf '%s\n' "\${f##*/}"
    done
done
EOF

    chmod +x "${layout_dir}/bin/box-direnv-dump-paths"
}

_box_direnv_dump_paths() {
    local box_name=$1 layout_dir
    local -a cmd_list

    layout_dir=$(direnv_layout_dir)

    cmd_list=$(toolbox run -c "$box_name" -- "${layout_dir}/bin/box-direnv-dump-paths" </dev/null)
    if [[ $? != 0 ]]
    then
        log_error "failed to enumerate commands in box '$box_name'"
        exit 1
    fi

    find "${layout_dir}/bin" -type l -delete

    cat>"${layout_dir}/bin/box-direnv-exec" <<-EOF
#!/bin/bash

ldir_path="${layout_dir}/bin"

PATH=:\$PATH:
PATH=\${PATH//:\${ldir_path}:/:}
PATH=\${PATH#:}; PATH=\${PATH%:}

exec toolbox run -c "$box_name" -- bash -c 'exec "\${0##*/}" "\$@"' "\$0" "\$@"
EOF

    chmod +x "${layout_dir}/bin/box-direnv-exec"

    local host_path
    host_path=$(echo "$PATH" | sed -e "s|${layout_dir}/bin||g" -e 's/::/:/g' -e 's/^://' -e 's/:$//')

    local added_count=0
    for cmd in $cmd_list
    do
        if ! PATH="$host_path" command -v "$cmd" >/dev/null 2>&1
        then
            ln -s box-direnv-exec "${layout_dir}/bin/${cmd}" 2>/dev/null
            ((added_count++))
        fi
    done

    log_status "exported $added_count new binaries from toolbox '$box_name'."

    PATH_add "${layout_dir}/bin"
}

# Evalúa argumentos dinámicamente para usar o crear un contenedor de Toolbx
use_toolbox() {
    local init_script=""
    if [ ! -t 0 ] && read -t 0; then
        init_script=$(cat)
    fi

    local box_name=""
    local image_name=""
    local default_box_name=""

    default_box_name="$(basename "$PWD")-toolbox"

    if ! _box_direnv_preflight
    then return 1
    fi

    _require_cmd_version toolbox "$TOOLBOX_MIN_VERSION"

    if [[ $# -eq 0 ]]
    then
        box_name="$default_box_name"

    elif [[ "$1" == *"/"* || "$1" == *":"* ]]
    then
        box_name="$default_box_name"
        image_name="$1"

    else
        if toolbox run -c "$1" true </dev/null 2>/dev/null
        then
            box_name="$1"
        else
            box_name="$1"
            if [[ $# -ge 2 ]]
            then
                image_name="$2"
            else
                log_status "container '$1' not found. Will create it using toolbox default image."
            fi
        fi
    fi

    if ! toolbox run -c "$box_name" true </dev/null 2>/dev/null
    then
        log_status "creating toolbox '$box_name'..."
        if [[ -n "$image_name" ]]; then
            toolbox create -c "$box_name" -i "$image_name" </dev/null 2>/dev/null
        else
            toolbox create -c "$box_name" </dev/null 2>/dev/null
        fi
    fi

    if [[ -n "$init_script" ]]; then
        if ! toolbox run -c "$box_name" test -f /.box-direnv-initialized </dev/null 2>/dev/null
        then
            log_status "initializing toolbox '$box_name' with provided script..."
            if printf "%s\n" "$init_script" | toolbox run -c "$box_name" bash
            then
                log_status "initialization successful. Marking as initialized."
                toolbox run -c "$box_name" sudo touch /.box-direnv-initialized </dev/null
            else
                log_error "initialization failed. Check your commands."
                exit 1
            fi
        fi
    fi

    _box_direnv_dump_paths "$box_name"

    export TOOLBOX_NAME="$box_name"
}

toolbox_export() {
    local layout_dir
    layout_dir=$(direnv_layout_dir)

    if [[ ! -x "${layout_dir}/bin/box-direnv-exec" ]]; then
        log_error "you must call 'use toolbox' before using 'toolbox_export'."
        return 1
    fi

    for cmd in "$@"; do
        ln -sf box-direnv-exec "${layout_dir}/bin/${cmd}"
        log_status "forcefully exported '$cmd' from toolbox."
    done
}
