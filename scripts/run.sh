#!/bin/bash 
set -e
DEBUG="NO"
if [ "${DEBUG}" == "NO" ]; then
  trap "cleanup $? $LINENO" EXIT
fi

# controller temp sshkey
function controller_sshkey {
    ssh-keygen -o -a 100 -t ed25519 -C "ansible" -f "${HOME}/.ssh/id_ansible_ed25519" -q -N "" <<<y >/dev/null
    export ANSIBLE_SSH_PUB_KEY=$(cat ${HOME}/.ssh/id_ansible_ed25519.pub)
    export ANSIBLE_SSH_PRIV_KEY=$(cat ${HOME}/.ssh/id_ansible_ed25519)
    export SSH_KEY_PATH="${HOME}/.ssh/id_ansible_ed25519"
    chmod 700 ${HOME}/.ssh
    chmod 600 ${SSH_KEY_PATH}
    eval $(ssh-agent)
    ssh-add ${SSH_KEY_PATH}
}
# build instance vars before cluster deployment
function build {
  local KAFKA_VERSION="${KAFKA_VERSION}"
  local LINODE_PARAMS=($(curl -sH "Authorization: Bearer ${TOKEN_PASSWORD}" "https://api.linode.com/v4/linode/instances/${LINODE_ID}" | jq -r .label,.type,.region,.image))
  local LINODE_TAGS=$(curl -sH "Authorization: Bearer ${TOKEN_PASSWORD}" "https://api.linode.com/v4/linode/instances/${LINODE_ID}" | jq -r .tags)
  local group_vars="${WORK_DIR}/group_vars/kafka/vars"
  local TEMP_ROOT_PASS=$(openssl rand -base64 32)
controller_sshkey
  cat << EOF >> ${group_vars}
# user vars
sudo_username: ${SUDO_USERNAME}
token: ${TOKEN_PASSWORD}
# deployment vars
uuid: ${UUID}
ssh_keys: ${ANSIBLE_SSH_PUB_KEY}
instance_prefix: ${INSTANCE_PREFIX}
type: ${LINODE_PARAMS[1]}
region: ${LINODE_PARAMS[2]}
image: ${LINODE_PARAMS[3]}
linode_tags: ${LINODE_TAGS}
root_pass: ${TEMP_ROOT_PASS}
kafka_version: ${KAFKA_VERSION}
cluster_size: ${CLUSTER_SIZE}
controller_count: 3
client_count: ${CLIENT_COUNT}
add_ssh_keys: '${ADD_SSH_KEYS}'

# ssl config
country_name: ${COUNTRY_NAME}
state_or_province_name: ${STATE_OR_PROVINCE_NAME}
locality_name: ${LOCALITY_NAME}
organization_name: ${ORGANIZATION_NAME}
email_address: ${EMAIL_ADDRESS}
ca_common_name: ${CA_COMMON_NAME}
EOF
}

function deploy { 
    for playbook in provision.yml site.yml; do ansible-playbook -v -i hosts $playbook; done
}

## cleanup ##
function cleanup {
  if [ "$?" != "0" ] || [ "$SUCCESS" == "true" ]; then
    deactivate
    cd ${HOME}
    if [ -d "/tmp/linode" ]; then
      rm -rf /tmp/linode
    fi
    if [ -f "/usr/local/bin/run" ]; then
      rm /usr/local/bin/run
    fi
  fi
}

# main
case $1 in
    build) "$@"; exit;;
    deploy) "$@"; exit;;
esac
