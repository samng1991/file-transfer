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

function _sign_client_cert() {
    cp "${templates_dir}/intermediate-ca.openssl.cnf" "${tmp_dir}/client-cert.openssl.cnf"
    sed -i "s|---CA_DIR---|${intermediate_ca_dir}|g" "${tmp_dir}/client-cert.openssl.cnf"
    sed -i "s/---ENV---/${env}/g" "${tmp_dir}/client-cert.openssl.cnf"
    sed -i "s/---COMMON_NAME---/client.${domain}/g" "${tmp_dir}/client-cert.openssl.cnf"

    openssl genrsa -aes256 -passout "pass:${cert_password}" -out "${intermediate_ca_dir}/private/client.pass.key" 2048
    # chmod 400 "${intermediate_ca_dir}/private/client.pass.key"
    openssl rsa -passin "pass:${cert_password}" -in "${intermediate_ca_dir}/private/client.pass.key" -out "${intermediate_ca_dir}/private/client.key"

    openssl req -config "${tmp_dir}/client-cert.openssl.cnf" -new -sha256 \
        -passin "pass:${cert_password}" \
        -key "${intermediate_ca_dir}/private/client.pass.key" \
        -out "${intermediate_ca_dir}/csr/client.csr"

    openssl ca -config "${tmp_dir}/client-cert.openssl.cnf" \
        -extensions usr_cert -days 730 -notext -md sha256 \
        -in "${intermediate_ca_dir}/csr/client.csr" \
        -out "${intermediate_ca_dir}/certs/client.crt"
    # chmod 444 "${intermediate_ca_dir}/certs/client.crt"

    openssl x509 -noout -text \
        -in "${intermediate_ca_dir}/certs/client.crt"
    openssl verify -CAfile "${intermediate_ca_dir}/certs/ca-chain.crt" \
        "${intermediate_ca_dir}/certs/client.crt"

    # openssl pkcs8 -topk8 -inform PEM -in "${intermediate_ca_dir}/private/client.key" -outform pem -nocrypt -out "${output_dir}/${domain}.client.key"
    cp "${intermediate_ca_dir}/private/client.key" "${output_dir}/${domain}.client.key"
    
    cat "${intermediate_ca_dir}/certs/client.crt" \
        "${intermediate_ca_dir}/certs/ca.crt" \
        "${root_ca_dir}/certs/ca.crt" > "${output_dir}/${domain}.client-chain.crt"
}

function _main() {
    _sign_client_cert
}

_main