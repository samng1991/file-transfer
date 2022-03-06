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
domain=$(_read_input "Please input domain: ")
cert_password=$(_read_password "Please input cert password: ")
echo ""

if [[ -z "${env}" ]]; then
    env="dev"
fi
if [[ -z "${domain}" ]]; then
    domain="hkjc.com"
fi
if [[ -z "${cert_password}" ]]; then
    cert_password="0000abc!"
fi

# shellcheck disable=SC1091
output_dir="$( readlink -m "$(dirname "${BASH_SOURCE[0]}")/output/${env}")"
mkdir -p "${output_dir}"

root_ca_dir="${output_dir}/root-ca"
intermediate_ca_dir="${output_dir}/${domain}/intermediate-ca"
mkdir -p "${root_ca_dir}" "${intermediate_ca_dir}"

function _generate_intermediate_ca() {
    pushd "${intermediate_ca_dir}" || exit 1
    mkdir -p certs crl csr newcerts private
    chmod 700 private
    touch index.txt
    echo 1000 > serial
    popd || exit 1

    cp "${templates_dir}/intermediate-ca.openssl.cnf" "${tmp_dir}/intermediate-ca.openssl.cnf"
    sed -i "s|---CA_DIR---|${intermediate_ca_dir}|g" "${tmp_dir}/intermediate-ca.openssl.cnf"
    sed -i "s/---ENV---/${env}/g" "${tmp_dir}/intermediate-ca.openssl.cnf"
    sed -i "s/---COMMON_NAME---/${domain} Intermediate CA/g" "${tmp_dir}/intermediate-ca.openssl.cnf"

    echo 1000 > "${intermediate_ca_dir}/crlnumber"

    openssl genrsa -aes256 -passout "pass:${cert_password}" -out "${intermediate_ca_dir}/private/ca.pass.key" 4096
    # chmod 400 "${intermediate_ca_dir}/private/ca.pass.key"
    openssl rsa -passin "pass:${cert_password}" -in "${intermediate_ca_dir}/private/ca.pass.key" -out "${intermediate_ca_dir}/private/ca.key"

    openssl req -config "${tmp_dir}/intermediate-ca.openssl.cnf" -new -sha256 \
        -passin "pass:${cert_password}" \
        -key "${intermediate_ca_dir}/private/ca.pass.key" \
        -out "${intermediate_ca_dir}/csr/ca.csr"

    openssl ca -config "${root_ca_dir}/root-ca.openssl.cnf" -extensions v3_intermediate_ca \
        -days 3650 -notext -md sha256 \
        -in "${intermediate_ca_dir}/csr/ca.csr" \
        -out "${intermediate_ca_dir}/certs/ca.crt"
    # chmod 444 "${intermediate_ca_dir}/certs/ca.crt"

    openssl verify -CAfile "${root_ca_dir}/certs/ca.crt" \
        "${intermediate_ca_dir}/certs/ca.crt"

    openssl pkcs8 -topk8 -inform PEM -in "${intermediate_ca_dir}/private/ca.key" -outform pem -nocrypt -out "${output_dir}/${domain}.intermediate-ca.key"
    cp "${intermediate_ca_dir}/certs/ca.crt" "${output_dir}/${domain}.intermediate-ca.crt"
}

function _generate_ca_chain_cert() {
    cat "${intermediate_ca_dir}/certs/ca.crt" \
        "${root_ca_dir}/certs/ca.crt" > "${intermediate_ca_dir}/certs/ca-chain.crt"
    # chmod 444 "${intermediate_ca_dir}/certs/ca-chain.crt"

    cp "${intermediate_ca_dir}/certs/ca-chain.crt" "${output_dir}/${domain}.ca-chain.crt"
}

function _main() {
    _generate_intermediate_ca
    _generate_ca_chain_cert
}

_main