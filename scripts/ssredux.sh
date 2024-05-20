#!/bin/bash
set -e
DEBUG="NO"
if [ "${DEBUG}" == "NO" ]; then
  trap "cleanup $? $LINENO" EXIT
fi

## deployment variables
# <UDF name="kafka_version" label="Kafka version" default="3.7.0" oneof="3.7.0" />
# <UDF name="token_password" label="Your Linode API token" />
# <UDF name="sudo_username" label="The limited account user" default='admin'>
# <UDF name="client_count" label="Number of clients connecting to Kafka">
# <UDF name="cluster_size" label="Kafka cluster size" oneOf="3,5,7">
# <UDF name="clusterheader" label="Cluster Settings" default="Yes" header="Yes">
# <UDF name="add_ssh_keys" label="Add Account SSH Keys to All Nodes?" oneof="yes,no"  default="yes" />

# ssl variables
# <UDF name="sslheader" label="SSL Information" header="Yes" default="Yes" required="Yes">
# <UDF name="country_name" label="Details for self-signed SSL certificates: Country or Region" oneof="AD,AE,AF,AG,AI,AL,AM,AO,AQ,AR,AS,AT,AU,AW,AX,AZ,BA,BB,BD,BE,BF,BG,BH,BI,BJ,BL,BM,BN,BO,BQ,BR,BS,BT,BV,BW,BY,BZ,CA,CC,CD,CF,CG,CH,CI,CK,CL,CM,CN,CO,CR,CU,CV,CW,CX,CY,CZ,DE,DJ,DK,DM,DO,DZ,EC,EE,EG,EH,ER,ES,ET,FI,FJ,FK,FM,FO,FR,GA,GB,GD,GE,GF,GG,GH,GI,GL,GM,GN,GP,GQ,GR,GS,GT,GU,GW,GY,HK,HM,HN,HR,HT,HU,ID,IE,IL,IM,IN,IO,IQ,IR,IS,IT,JE,JM,JO,JP,KE,KG,KH,KI,KM,KN,KP,KR,KW,KY,KZ,LA,LB,LC,LI,LK,LR,LS,LT,LU,LV,LY,MA,MC,MD,ME,MF,MG,MH,MK,ML,MM,MN,MO,MP,MQ,MR,MS,MT,MU,MV,MW,MX,MY,MZ,NA,NC,NE,NF,NG,NI,NL,NO,NP,NR,NU,NZ,OM,PA,PE,PF,PG,PH,PK,PL,PM,PN,PR,PS,PT,PW,PY,QA,RE,RO,RS,RU,RW,SA,SB,SC,SD,SE,SG,SH,SI,SJ,SK,SL,SM,SN,SO,SR,SS,ST,SV,SX,SY,SZ,TC,TD,TF,TG,TH,TJ,TK,TL,TM,TN,TO,TR,TT,TV,TW,TZ,UA,UG,UM,US,UY,UZ,VA,VC,VE,VG,VI,VN,VU,WF,WS,YE,YT,ZA,ZM,ZW" />
# <UDF name="state_or_province_name" label="State or Province" example="Example: Pennsylvania" />
# <UDF name="locality_name" label="Locality" example="Example: Philadelphia" />
# <UDF name="organization_name" label="Organization" example="Example: Akamai Technologies" />
# <UDF name="email_address" label="Email Address" example="Example: webmaster@example.com" />
# <UDF name="ca_common_name" label="CA Common Name" example="Example: Kafka RootCA" />

# git repo
export GIT_REPO="https://github.com/akamai-compute-marketplace/kafka-occ.git"
export WORK_DIR="/tmp/linode" 
export UUID=$(uuidgen | awk -F - '{print $1}')

# enable logging
exec > >(tee /dev/ttyS0 /var/log/stackscript.log) 2>&1

function cleanup {
  ansible-playbook destroy.yml
  if [ -d "${WORK_DIR}" ]; then
    rm -rf ${WORK_DIR}
  fi
}

# Deployment UDFs
function udf {
  local group_vars="${WORK_DIR}/group_vars/kafka/vars"
  sed 's/  //g' <<EOF > ${group_vars}
  # sudo username
  sudo_username: ${SUDO_USERNAME}
EOF

  # vars
  if [[ -n ${TOKEN_PASSWORD} ]]; then
    echo "token: ${TOKEN_PASSWORD}" >> ${group_vars}
  else 
    echo "No API token entered"
  fi

  # validate client_count. Hard fail if non-numeric value is entered.
  if [[ ${CLIENT_COUNT} =~ ^-?[1-9][0-9]*$ ]]; then
    echo "valid count entered for client count"
  else
    echo "[fatal] invalid entry for client count '${CLIENT_COUNT}'. Rerun deployment using an interger"
    exit 1
  fi
}

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
  local LINODE_PARAMS=($(curl -sH "Authorization: Bearer ${TOKEN_PASSWORD}" "https://api.linode.com/v4/linode/instances/${LINODE_ID}" | jq -r .label,.type,.region,.image,.tags))
  local group_vars="${WORK_DIR}/group_vars/kafka/vars"
  local TEMP_ROOT_PASS=$(openssl rand -base64 32)
  cat << EOF >> ${group_vars}
# deployment vars
uuid: ${UUID}
ssh_keys: ${ANSIBLE_SSH_PUB_KEY}
instance_prefix: ${INSTANCE_PREFIX}
type: ${LINODE_PARAMS[1]}
region: ${LINODE_PARAMS[2]}
image: ${LINODE_PARAMS[3]}
linode_tags: ${LINODE_PARAMS[4]}
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

# cluster functions
function get_privateip {
  curl -s -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${TOKEN_PASSWORD}" \
   https://api.linode.com/v4/linode/instances/${LINODE_ID}/ips | \
   jq -r '.ipv4.private[].address'
}
function configure_privateip {
  LINODE_IP=$(get_privateip)
  if [ ! -z "${LINODE_IP}" ]; then
          echo "[info] Linode private IP present"
  else
          echo "[warn] No private IP found. Adding.."
          add_privateip
          LINODE_IP=$(get_privateip)
          ip addr add ${LINODE_IP}/17 dev eth0 label eth0:1
  fi
}
function rename_provisioner {
  INSTANCE_PREFIX=$(curl -sH "Authorization: Bearer ${TOKEN_PASSWORD}" "https://api.linode.com/v4/linode/instances/${LINODE_ID}" | jq -r .label)
  export INSTANCE_PREFIX=${INSTANCE_PREFIX}
  echo "[info] renaming the provisioner"
  curl -s -H "Content-Type: application/json" \
      -H "Authorization: Bearer ${TOKEN_PASSWORD}" \
      -X PUT -d "{
        \"label\": \"${INSTANCE_PREFIX}1-${UUID}\"
      }" \
      https://api.linode.com/v4/linode/instances/${LINODE_ID}
}

function run {
  # install dependancies
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y git python3 python3-pip python3-venv jq

  # rename provisioner and configure private IP if not present
  rename_provisioner
  configure_privateip 
  if [ "${ADD_SSH_KEYS}" == "yes" ]; then
    if [ ! -d ~/.ssh ] ; then
      mkdir ~/.ssh
    fi
    curl -sH "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN_PASSWORD}" https://api.linode.com/v4/profile/sshkeys | jq -r .data[].ssh_key > /root/.ssh/authorized_keys
  fi  

  # clone repo and set up ansible environment
  git clone ${GIT_REPO} /tmp/linode
  # for a single testing branch
  #git -C /tmp clone -b ${BRANCH} ${GIT_REPO}

  # venv
  cd ${WORK_DIR}
  #pip3 install virtualenv
  python3 -m venv env
  source env/bin/activate
  pip install pip --upgrade
  pip install -r requirements.txt
  ansible-galaxy install -r collections.yml
  
  # populate group_vars
  udf
  # build instance vars
  controller_sshkey
  build

  # run playbooks
  for playbook in provision.yml site.yml; do ansible-playbook -v -i hosts $playbook; done
}

function installation_complete {
  echo "Installation Complete"
}
# main
run && installation_complete
if [ "${DEBUG}" == "NO" ]; then
  cleanup
fi