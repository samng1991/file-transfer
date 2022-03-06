#!/bin/bash

#########################################################################################################################
# Color Code
#########################################################################################################################
BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
LIGHT_BLUE='\033[1;34m'
NC='\033[0m' # No Color
CLEAR='\r\033[K'
SEPARATOR="-------------------------------------------------------------------"

#########################################################################################################################
# Common Function
#########################################################################################################################
function _log() {
    local level="${1}"
    local message="${*:2}"

    timestamp=$(date +"%T")

    case $level in
    FATAL)
        echo >&2 -e "[${timestamp}][${RED}FATAL${NC}] $message"
        exit 1
        ;;
    ERROR)
        echo >&2 -e "[${timestamp}][${RED}ERROR${NC}] $message"
        ;;
    WARN)
        echo >&2 -e "[${timestamp}][${ORANGE}WARN${NC}] $message"
        ;;
    SUCCESS)
        echo >&1 -e "[${timestamp}][${GREEN}SUCCESS${NC}] $message"
        ;;
    *)
        echo >&1 -e "[${timestamp}][${LIGHT_BLUE}INFO${NC}] $message"
        ;;
    esac
}

function _get_arg_value() {
    local arg="${1}"

    echo "${arg}" | sed -e '0,/^[^=]*=/s///'
}

function _print_step_header() {
    local title="${1}"

    echo >&2 -e "${ORANGE}
#########################################################################################################################
# ${title}
#########################################################################################################################${NC}"
}

function _read_input() {
    local question="${1}"
    read -r -p "$(echo -e "${ORANGE}${question}${NC}")" input
    echo "${input}"
}

function _read_password() {
    local question="${1}"
    read -s -p "$(echo -e "${ORANGE}${question}${NC}")" input
    echo "${input}"
}

# shellcheck disable=SC1091
templates_dir="$(dirname "${BASH_SOURCE[0]}")/templates"
tmp_dir="$(dirname "${BASH_SOURCE[0]}")/tmp"
mkdir -p "${tmp_dir}"

env=$(_read_input "Please input env: ")
cert_password=$(_read_password "Please input cert password: ")
echo ""

if [[ -z "${env}" ]]; then
    env="dev"
fi
if [[ -z "${cert_password}" ]]; then
    cert_password="0000abc!"
fi

# shellcheck disable=SC1091
output_dir="$(readlink -m "$(dirname "${BASH_SOURCE[0]}")/output/${env}")"
echo "$(dirname "${BASH_SOURCE[0]}")/output/${env}"
mkdir -p "${output_dir}"

root_ca_dir="${output_dir}/root-ca"
mkdir -p "${root_ca_dir}"

function _generate_root_ca() {
    pushd "${root_ca_dir}" || exit 1
    mkdir -p certs crl newcerts private
    chmod 700 private
    touch index.txt
    echo 1000 > serial
    popd || exit 1

    cp "${templates_dir}/root-ca.openssl.cnf" "${tmp_dir}/root-ca.openssl.cnf"
    sed -i "s|---CA_DIR---|${root_ca_dir}|g" "${tmp_dir}/root-ca.openssl.cnf"
    sed -i "s/---ENV---/${env}/g" "${tmp_dir}/root-ca.openssl.cnf"
    sed -i "s/---COMMON_NAME---/Platform Ops Root CA/g" "${tmp_dir}/root-ca.openssl.cnf"
    cp "${tmp_dir}/root-ca.openssl.cnf" "${root_ca_dir}/root-ca.openssl.cnf"

    openssl genrsa -aes256 -passout "pass:${cert_password}" -out "${root_ca_dir}/private/ca.pass.key" 2048
    # chmod 400 "${root_ca_dir}/private/ca.pass.key"
    openssl rsa -passin "pass:${cert_password}" -in "${root_ca_dir}/private/ca.pass.key" -out "${root_ca_dir}/private/ca.key"

    openssl req -config "${root_ca_dir}/root-ca.openssl.cnf" \
        -passin "pass:${cert_password}" \
        -key "${root_ca_dir}/private/ca.pass.key" \
        -new -x509 -days 7300 -sha256 -extensions v3_ca \
        -out "${root_ca_dir}/certs/ca.crt"

    openssl x509 -noout -text -in "${root_ca_dir}/certs/ca.crt"

    openssl pkcs8 -topk8 -inform PEM -in "${root_ca_dir}/private/ca.key" -outform pem -nocrypt -out "${output_dir}/platform-ops.root-ca.key"
    cp "${root_ca_dir}/certs/ca.crt" "${output_dir}/platform-ops.root-ca.crt"
}

function _main() {
    _generate_root_ca
}

_main