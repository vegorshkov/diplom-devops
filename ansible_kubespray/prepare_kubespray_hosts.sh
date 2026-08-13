#!/usr/bin/env bash
set -Eeuo pipefail

umask 077
export LC_ALL=C

KUBESPRAY_DIR="${KUBESPRAY_DIR:-/home/vgorshkov/STUDENT1/PROJECT/diplom-devops/ansible_kubespray/kubespray}"
INVENTORY_FILE="${INVENTORY_FILE:-/home/vgorshkov/STUDENT1/PROJECT/diplom-devops/ansible_kubespray/inventory/hosts.yaml}"
EXPECTED_KUBESPRAY_VERSION="2.31.0"

PLAYBOOK_FILE=""

cleanup()
{
    if [[ -n "${PLAYBOOK_FILE}" ]] &&
       [[ -f "${PLAYBOOK_FILE}" ]]
    then
        rm -f -- "${PLAYBOOK_FILE}"
    fi
}

error_handler()
{
    local exit_code="$?"

    printf '\nHOST_PREPARATION_RESULT=FAILED\n' >&2
    printf 'FAILED_COMMAND=%s\n' "${BASH_COMMAND}" >&2
    printf 'EXIT_CODE=%s\n' "${exit_code}" >&2

    exit "${exit_code}"
}

trap cleanup EXIT
trap error_handler ERR

for required_command in \
    ansible-inventory \
    ansible-playbook \
    mktemp \
    python3 \
    sed
do
    if ! command -v "${required_command}" >/dev/null 2>&1
    then
        printf 'ERROR: команда %s не найдена\n' \
            "${required_command}" >&2
        exit 1
    fi
done

if [[ ! -d "${KUBESPRAY_DIR}" ]]
then
    printf 'ERROR: каталог Kubespray не найден\n' >&2
    printf 'KUBESPRAY_DIR=%s\n' "${KUBESPRAY_DIR}" >&2
    exit 1
fi

REQUIRED_KUBESPRAY_PATHS=(
    ansible.cfg
    cluster.yml
    galaxy.yml
    requirements.txt
    inventory/sample
    roles/kubespray-defaults
    roles/kubernetes/preinstall
)

MISSING_KUBESPRAY_PATHS=()

for required_path in "${REQUIRED_KUBESPRAY_PATHS[@]}"
do
    if [[ ! -e "${KUBESPRAY_DIR}/${required_path}" ]]
    then
        MISSING_KUBESPRAY_PATHS+=("${required_path}")
    fi
done

if (( ${#MISSING_KUBESPRAY_PATHS[@]} > 0 ))
then
    printf 'ERROR: структура каталога Kubespray неполна\n' >&2
    printf 'KUBESPRAY_DIR=%s\n' "${KUBESPRAY_DIR}" >&2
    printf 'MISSING_KUBESPRAY_PATHS=%s\n' \
        "${MISSING_KUBESPRAY_PATHS[*]}" >&2
    exit 1
fi

if ! python3 - <<'PYTHON_REQUIREMENTS_EOF'
import jinja2
import netaddr
PYTHON_REQUIREMENTS_EOF
then
    printf 'ERROR: в активном Python-окружении отсутствует jinja2 или netaddr\n' >&2
    exit 1
fi

if [[ ! -r "${INVENTORY_FILE}" ]]
then
    printf 'ERROR: файл inventory не найден или недоступен для чтения\n' >&2
    printf 'INVENTORY_FILE=%s\n' "${INVENTORY_FILE}" >&2
    exit 1
fi

ACTUAL_KUBESPRAY_VERSION="$(
    sed -nE \
        's/^[[:space:]]*version:[[:space:]]*["'"'"']?([^"'"'"'[:space:]#]+).*/\1/p' \
        "${KUBESPRAY_DIR}/galaxy.yml"
)"

ACTUAL_KUBESPRAY_VERSION="${ACTUAL_KUBESPRAY_VERSION%%$'\n'*}"

if [[ -z "${ACTUAL_KUBESPRAY_VERSION}" ]]
then
    printf 'ERROR: версия Kubespray не определена из galaxy.yml\n' >&2
    printf 'KUBESPRAY_VERSION_FILE=%s\n' \
        "${KUBESPRAY_DIR}/galaxy.yml" >&2
    exit 1
fi

if [[ "${ACTUAL_KUBESPRAY_VERSION}" != "${EXPECTED_KUBESPRAY_VERSION}" ]]
then
    printf 'ERROR: версия скопированных исходников Kubespray не соответствует согласованной\n' >&2
    printf 'EXPECTED_KUBESPRAY_VERSION=%s\n' \
        "${EXPECTED_KUBESPRAY_VERSION}" >&2
    printf 'ACTUAL_KUBESPRAY_VERSION=%s\n' \
        "${ACTUAL_KUBESPRAY_VERSION}" >&2
    exit 1
fi

export ANSIBLE_CONFIG="${KUBESPRAY_DIR}/ansible.cfg"

PLAYBOOK_FILE="$(mktemp /tmp/prepare-kubespray-hosts.XXXXXX.yml)"

cat > "${PLAYBOOK_FILE}" << 'ANSIBLE_PLAYBOOK_EOF'
---
- name: Validate the selected Kubespray inventory
  hosts: localhost
  gather_facts: false
  become: false

  vars:
    expected_hosts:
      - k8s-master-ru-central1-a
      - k8s-master-ru-central1-e
      - k8s-master-ru-central1-d
      - k8s-worker-ru-central1-a
      - k8s-worker-ru-central1-e
      - k8s-worker-ru-central1-d

    expected_control_plane_hosts:
      - k8s-master-ru-central1-a
      - k8s-master-ru-central1-e
      - k8s-master-ru-central1-d

    expected_worker_hosts:
      - k8s-worker-ru-central1-a
      - k8s-worker-ru-central1-e
      - k8s-worker-ru-central1-d

  tasks:
    - name: Assert exact inventory membership
      ansible.builtin.assert:
        that:
          - ansible_version.full is version('2.14', '>=')
          - "(groups['all'] | sort | list) == (expected_hosts | sort | list)"
          - "(groups['kube_control_plane'] | default([]) | sort | list) == (expected_control_plane_hosts | sort | list)"
          - "(groups['etcd'] | default([]) | sort | list) == (expected_control_plane_hosts | sort | list)"
          - "(groups['kube_node'] | default([]) | sort | list) == (expected_worker_hosts | sort | list)"
        fail_msg: >-
          Ansible version or inventory membership differs from the approved
          Kubespray requirements and topology. No remote host has been changed.
        success_msg: INVENTORY_TOPOLOGY=VALID

- name: Verify SSH access, privilege escalation and target operating systems
  hosts: all
  gather_facts: true
  any_errors_fatal: true
  become: true

  tasks:
    - name: Verify Ansible connectivity
      ansible.builtin.ping:

    - name: Verify root privilege escalation
      ansible.builtin.command:
        argv:
          - id
          - -u
      register: effective_uid
      changed_when: false

    - name: Assert approved host platform
      ansible.builtin.assert:
        that:
          - effective_uid.stdout == '0'
          - ansible_distribution == 'Ubuntu'
          - ansible_distribution_release == 'jammy'
          - ansible_distribution_version is version('22.04', '>=')
          - ansible_architecture in ['x86_64', 'amd64']
          - ansible_python_version is version('3.8', '>=')
          - ansible_hostname == inventory_hostname
          - >-
            (ansible_memtotal_mb | int) >=
            (1900 if inventory_hostname in groups['kube_control_plane'] else 900)
        fail_msg: >-
          Host platform does not match the approved Ubuntu 22.04 amd64
          topology or the minimum Kubespray memory requirement.
        success_msg: HOST_PLATFORM=VALID

- name: Configure direct APT access on all Kubernetes hosts
  hosts: all
  gather_facts: false
  any_errors_fatal: true
  serial: 1
  become: true

  vars:
    apt_sources_content: |
      deb https://mirror.yandex.ru/ubuntu jammy main restricted universe multiverse
      deb https://mirror.yandex.ru/ubuntu jammy-updates main restricted universe multiverse
      deb https://mirror.yandex.ru/ubuntu jammy-backports main restricted universe multiverse
      deb https://mirror.yandex.ru/ubuntu jammy-security main restricted universe multiverse

    direct_environment:
      http_proxy: ""
      https_proxy: ""
      HTTP_PROXY: ""
      HTTPS_PROXY: ""
      ALL_PROXY: ""
      all_proxy: ""
      no_proxy: "*"
      NO_PROXY: "*"

  tasks:
    - name: Inspect the main APT configuration file
      ansible.builtin.stat:
        path: /etc/apt/apt.conf
      register: apt_main_configuration

    - name: Find APT configuration fragments
      ansible.builtin.find:
        paths:
          - /etc/apt/apt.conf.d
        file_type: file
        hidden: true
        recurse: false
      register: apt_configuration_fragments

    - name: Build the APT configuration file list
      ansible.builtin.set_fact:
        apt_configuration_files: >-
          {{
            (['/etc/apt/apt.conf'] if apt_main_configuration.stat.exists else [])
            +
            (apt_configuration_fragments.files | map(attribute='path') | list)
          }}

    - name: Remove APT HTTP and HTTPS proxy directives
      ansible.builtin.replace:
        path: "{{ item }}"
        regexp: '(?im)^[ \t]*Acquire::(?:http|https)::[Pp]roxy[ \t]+[^;\n]*;[ \t]*(?:\n|$)'
        replace: ''
        backup: false
      loop: "{{ apt_configuration_files }}"
      loop_control:
        label: "{{ item }}"

    - name: Configure the approved Ubuntu mirror
      ansible.builtin.copy:
        dest: /etc/apt/sources.list
        content: "{{ apt_sources_content }}"
        owner: root
        group: root
        mode: '0644'
        backup: false

    - name: Verify that APT proxy configuration is absent
      ansible.builtin.shell: |
        set -Eeuo pipefail

        proxy_configuration="$({
            apt-config dump |
                grep -Ei '^Acquire::(http|https)::[Pp]roxy' ||
                true
        })"

        if [[ -n "${proxy_configuration}" ]]
        then
            printf '%s\n' "${proxy_configuration}" >&2
            exit 20
        fi

        if grep \
            -RIsEq \
            'socks5h?://172\.16\.2\.254:1080' \
            /etc/apt/apt.conf \
            /etc/apt/apt.conf.d \
            2>/dev/null
        then
            printf 'OLD_SOCKS_PROXY_REFERENCE=FOUND\n' >&2
            exit 21
        fi

        printf 'APT_PROXY_STATUS=DISABLED\n'
      args:
        executable: /bin/bash
      environment: "{{ direct_environment }}"
      register: apt_proxy_validation
      changed_when: false

    - name: Display APT proxy validation result
      ansible.builtin.debug:
        var: apt_proxy_validation.stdout_lines

    - name: Update APT package indexes through the direct connection
      ansible.builtin.command:
        argv:
          - apt-get
          - -o
          - Acquire::Retries=2
          - -o
          - Acquire::http::Timeout=30
          - -o
          - Acquire::https::Timeout=30
          - -o
          - DPkg::Lock::Timeout=60
          - update
      environment: "{{ direct_environment }}"
      register: apt_update_result
      changed_when: true
      retries: 3
      delay: 5
      until: apt_update_result.rc == 0

    - name: Report successful APT update
      ansible.builtin.debug:
        msg:
          - "HOST={{ inventory_hostname }}"
          - APT_CONFIGURATION=SUCCESS
          - APT_UPDATE_RESULT=SUCCESS

- name: Validate package and operating-system readiness
  hosts: all
  gather_facts: true
  become: true

  vars:
    required_packages:
      - apparmor
      - apt-transport-https
      - bash-completion
      - ca-certificates
      - conntrack
      - curl
      - e2fsprogs
      - ebtables
      - ethtool
      - gnupg
      - iproute2
      - ipset
      - iptables
      - ipvsadm
      - kmod
      - libseccomp2
      - nfs-common
      - openssh-server
      - openssl
      - python3
      - python3-apt
      - rsync
      - socat
      - software-properties-common
      - sudo
      - tar
      - unzip
      - util-linux
      - xfsprogs

    network_endpoints:
      - name: github
        url: https://github.com/
        status_codes:
          - 200
      - name: kubernetes-download
        url: https://dl.k8s.io/
        status_codes:
          - 200
      - name: kubernetes-registry
        url: https://registry.k8s.io/v2/
        status_codes:
          - 200
          - 401
          - 404
      - name: quay-registry
        url: https://quay.io/v2/
        status_codes:
          - 200
          - 401
      - name: docker-registry
        url: https://registry-1.docker.io/v2/
        status_codes:
          - 200
          - 401

    direct_environment:
      http_proxy: ""
      https_proxy: ""
      HTTP_PROXY: ""
      HTTPS_PROXY: ""
      ALL_PROXY: ""
      all_proxy: ""
      no_proxy: "*"
      NO_PROXY: "*"

  tasks:
    - name: Check package candidates and dependency resolution
      ansible.builtin.shell: |
        set -Eeuo pipefail
        export LC_ALL=C
        export DEBIAN_FRONTEND=noninteractive

        packages=(
        {% for package_name in required_packages %}
            {{ package_name | quote }}
        {% endfor %}
        )

        missing_candidates=()
        not_installed=()

        for package_name in "${packages[@]}"
        do
            candidate_version="$(
                apt-cache policy "${package_name}" |
                    sed -n \
                        's/^[[:space:]]*Candidate:[[:space:]]*//p'
            )"

            candidate_version="${candidate_version%%$'\n'*}"

            if [[ -z "${candidate_version}" ]] ||
               [[ "${candidate_version}" == "(none)" ]]
            then
                missing_candidates+=("${package_name}")
            fi

            package_status="$(
                dpkg-query \
                    -W \
                    -f='${db:Status-Abbrev}' \
                    "${package_name}" \
                    2>/dev/null ||
                    true
            )"

            if [[ "${package_status}" != "ii " ]]
            then
                not_installed+=("${package_name}")
            fi
        done

        printf 'TOTAL_REQUIRED_PACKAGES=%s\n' "${#packages[@]}"
        printf 'MISSING_CANDIDATE_COUNT=%s\n' \
            "${#missing_candidates[@]}"

        if (( ${#missing_candidates[@]} > 0 ))
        then
            printf 'MISSING_CANDIDATE_PACKAGES=%s\n' \
                "${missing_candidates[*]}"
            exit 30
        fi

        printf 'MISSING_CANDIDATE_PACKAGES=NONE\n'
        printf 'NOT_INSTALLED_COUNT=%s\n' \
            "${#not_installed[@]}"

        if (( ${#not_installed[@]} > 0 ))
        then
            printf 'NOT_INSTALLED_PACKAGES=%s\n' \
                "${not_installed[*]}"
        else
            printf 'NOT_INSTALLED_PACKAGES=NONE\n'
        fi

        set +e

        simulation_output="$(
            apt-get \
                --simulate \
                install \
                "${packages[@]}" \
                2>&1
        )"

        simulation_return_code="$?"

        set -e

        if [[ "${simulation_return_code}" -ne 0 ]]
        then
            printf '%s\n' "${simulation_output}" >&2
            printf 'APT_INSTALL_SIMULATION_RC=%s\n' \
                "${simulation_return_code}" >&2
            exit 31
        fi

        printf 'APT_INSTALL_SIMULATION_RC=0\n'
        printf 'PACKAGE_CANDIDATES=SUCCESS\n'
        printf 'DEPENDENCY_RESOLUTION=SUCCESS\n'
      args:
        executable: /bin/bash
      environment: "{{ direct_environment }}"
      register: package_validation
      changed_when: false

    - name: Display package validation result
      ansible.builtin.debug:
        var: package_validation.stdout_lines

    - name: Read IPv4 forwarding state
      ansible.builtin.command:
        argv:
          - sysctl
          - -n
          - net.ipv4.ip_forward
      register: ipv4_forwarding
      changed_when: false

    - name: Read active swap devices
      ansible.builtin.command:
        argv:
          - swapon
          - --noheadings
          - --show=NAME
      register: active_swap
      changed_when: false

    - name: Read UFW state
      ansible.builtin.shell: |
        set -Eeuo pipefail

        if command -v ufw >/dev/null 2>&1
        then
            ufw status
        else
            printf 'UFW_NOT_INSTALLED\n'
        fi
      args:
        executable: /bin/bash
      register: ufw_state
      changed_when: false

    - name: Read time synchronization state
      ansible.builtin.command:
        argv:
          - timedatectl
          - show
          - --property=NTPSynchronized
          - --value
      register: time_synchronization
      changed_when: false

    - name: Verify direct access to required download and registry endpoints
      ansible.builtin.uri:
        url: "{{ item.url }}"
        method: GET
        follow_redirects: all
        return_content: false
        status_code: "{{ item.status_codes }}"
        timeout: 30
        validate_certs: true
      environment: "{{ direct_environment }}"
      loop: "{{ network_endpoints }}"
      loop_control:
        label: "{{ item.name }}"
      register: endpoint_validation
      changed_when: false

    - name: Assert operating-system readiness
      ansible.builtin.assert:
        that:
          - ipv4_forwarding.stdout | trim == '1'
          - active_swap.stdout | trim == ''
          - >-
            'UFW_NOT_INSTALLED' in ufw_state.stdout or
            'Status: inactive' in ufw_state.stdout
          - time_synchronization.stdout | trim == 'yes'
        fail_msg: >-
          Host requires correction before Kubespray installation.
          Review IPv4 forwarding, swap, UFW and time synchronization values.
        success_msg: OPERATING_SYSTEM_READINESS=SUCCESS

    - name: Display final host readiness state
      ansible.builtin.debug:
        msg:
          - "HOST={{ inventory_hostname }}"
          - "IPV4_FORWARDING={{ ipv4_forwarding.stdout | trim }}"
          - "SWAP={{ 'DISABLED' if (active_swap.stdout | trim == '') else 'ACTIVE' }}"
          - "UFW={{ ufw_state.stdout | trim }}"
          - "NTP_SYNCHRONIZED={{ time_synchronization.stdout | trim }}"
          - NETWORK_ENDPOINTS=SUCCESS
          - HOST_READINESS=SUCCESS
ANSIBLE_PLAYBOOK_EOF

printf 'HOST_PREPARATION_START=%s\n' \
    "$(date --iso-8601=seconds)"
printf 'KUBESPRAY_DIR=%s\n' "${KUBESPRAY_DIR}"
printf 'KUBESPRAY_SOURCE_LAYOUT=VALID\n'
printf 'KUBESPRAY_SOURCE_TYPE=COPIED_DIRECTORY\n'
printf 'KUBESPRAY_VERSION_SOURCE=galaxy.yml\n'
printf 'KUBESPRAY_VERSION=v%s\n' "${ACTUAL_KUBESPRAY_VERSION}"
printf 'KUBESPRAY_VERSION_VALIDATION=SUCCESS\n'
printf 'INVENTORY_FILE=%s\n' "${INVENTORY_FILE}"

printf '\n===== ANSIBLE_VERSION =====\n'
ansible-playbook --version

printf '\n===== INVENTORY_GRAPH =====\n'
ansible-inventory \
    -i "${INVENTORY_FILE}" \
    --graph

printf '\n===== SYNTAX_CHECK =====\n'
ansible-playbook \
    -i "${INVENTORY_FILE}" \
    "${PLAYBOOK_FILE}" \
    --syntax-check

printf '\n===== TARGET_HOSTS =====\n'
ansible-playbook \
    -i "${INVENTORY_FILE}" \
    "${PLAYBOOK_FILE}" \
    --list-hosts

printf '\n===== GLOBAL_HOST_PREPARATION =====\n'
ansible-playbook \
    -i "${INVENTORY_FILE}" \
    "${PLAYBOOK_FILE}"

printf '\nHOST_PREPARATION_RESULT=SUCCESS\n'
printf 'HOST_PREPARATION_END=%s\n' \
    "$(date --iso-8601=seconds)"
