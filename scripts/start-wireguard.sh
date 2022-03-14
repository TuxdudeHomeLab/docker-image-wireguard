#!/usr/bin/env bash
set -e -o pipefail

cleanup() {
    echo "Bringing down wireguard client interface ${INTERFACE_NAME:?}"
    echo
    wg-quick down ${WIREGUARD_CONFIG:?}
    # Exit with a non-zero code to allow the docker restart policy to kick in.
    exit 1
}

validate() {
    if [[ -z "${WIREGUARD_CONFIG}" ]]; then
        echo "WIREGUARD_CONFIG env variable is not set"
        exit 1
    fi

    local config_file_name="$(basename ${WIREGUARD_CONFIG:?})"
    if [[ "${config_file_name:?}" != *.conf ]]; then
        echo "WIREGUARD_CONFIG needs to point to a .conf file, but instead points to ${WIREGUARD_CONFIG:?}"
        exit 1
    fi

    if [[ "$(cat /proc/sys/net/ipv4/conf/all/src_valid_mark)" != "1" ]]; then
        echo "Missing sysctl net.ipv4.conf.all.src_valid_mark=1, exiting ..."
        exit 1
    fi

    local default_route=$(ip route show 0.0.0.0/0 | sed -E 's#^default via ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) dev .*$#\1#')
    if [[ -z "$default_route" ]]; then
        echo "Missing default route, exiting ..."
        exit 1
    fi
    echo "Detected default route ${default_route:?}"
    echo
}

invoke_pre_launch_hook() {
    if [[ "${PRE_LAUNCH_HOOK}" != "" ]]; then
        echo
        echo "PRE_LAUNCH_HOOK is non-empty ..."
        echo "PRE_LAUNCH_HOOK=\"${PRE_LAUNCH_HOOK:?}\""
        echo "PRE_LAUNCH_HOOK_ARGS=\"${PRE_LAUNCH_HOOK_ARGS}\""
        echo -e "Invoking Pre-launch hook ...\n\n$(realpath ${PRE_LAUNCH_HOOK:?}) ${PRE_LAUNCH_HOOK_ARGS}\n\n"
        $(realpath ${PRE_LAUNCH_HOOK:?}) ${PRE_LAUNCH_HOOK_ARGS}
    fi
}

invoke_post_launch_hook() {
    if [[ "${POST_LAUNCH_HOOK}" != "" ]]; then
        echo
        echo "POST_LAUNCH_HOOK is non-empty ..."
        echo "POST_LAUNCH_HOOK=\"${POST_LAUNCH_HOOK:?}\""
        echo "POST_LAUNCH_HOOK_ARGS=\"${POST_LAUNCH_HOOK_ARGS}\""
        echo -e "Invoking Post-launch hook ...\n\n$(realpath ${POST_LAUNCH_HOOK:?}) ${POST_LAUNCH_HOOK_ARGS}\n\n"
        $(realpath ${POST_LAUNCH_HOOK:?}) ${POST_LAUNCH_HOOK_ARGS}
    fi
}

start_wireguard() {
    invoke_pre_launch_hook

    echo "Bringing up wireguard client interface ${INTERFACE_NAME:?} with config ${WIREGUARD_CONFIG:?}"
    echo
    wg-quick up ${WIREGUARD_CONFIG:?}

    trap cleanup SIGTERM SIGINT SIGQUIT

    invoke_post_launch_hook

    echo
    echo "Wireguard client interface ${INTERFACE_NAME:?} is up for the VPN tunnel"
    echo

    sleep infinity &
    wait $!
}

interface_name() {
    local config_file_name="$(basename ${WIREGUARD_CONFIG:?})"
    echo "${config_file_name%.conf}"
}

validate
INTERFACE_NAME=$(interface_name)

start_wireguard
