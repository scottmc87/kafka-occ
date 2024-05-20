# Kafka One-Click CLUSTER
![kafka-cluster.png](images/kafka-cluster.png)

Apache Kafka is a robust, scalable, and high-performance system for managing real-time data streams. Its versatile architecture and feature set make it an essential component for modern data infrastructure, supporting a wide range of applications from log aggregation to real-time analytics and more. Whether you are building data pipelines, event-driven architectures, or stream processing applications, Kafka provides a reliable foundation for your data needs.

Our marketplace application allows the deployment of a Kafka cluster using Kafka's native consensus protocol, [KRaft](https://kafka.apache.org/documentation/#kraft). There are a few things to highligh from our deployment:

- While the provisioning, the cluster will be configured with mTLS for authentication. This means that inter-broker communication as well as client authentication is established via certificate identity
- The minimum cluster size is 3. At all times, 3 controllers are configured in the cluster for fault-tolerance.
- Client's that connect to the cluster will need their own valid certificate. All certificates are signed with a self-signed Ccerticate Authority (CA). Client keystores and truststore are found on the first Kafka node in `/etc/kafka/ssl/keystore` and `/etc/kafka/ssl/truststore`
- The CA key and certificate pair are on the first Kafka node in `/etc/kafka/ssl/ca`

## Distributions

- Ubuntu 22.04 LTS

## Sotware Included

| Software  | Version   | Description   |
| :---      | :----     | :---          |
| Apache Kafka    | 3.7.0    | Scalable, high-performance, fault-tolerant streaming processing application  |
| KRaft | | Kafka native consensus protocol |
| UFW      | 0.36.1    | Uncomplicated Firewall |
| Fail2ban   | 0.11.2    | Bruteforce protection utility |

## Use our API

Customers can choose to the deploy the Kafka app through the Linode Marketplace or directly using API. Before using the commands below, you will need to create an API token or configure linode-cli on an environment.

Make sure that the following values are updated at the top of the code block before running the commands:

SHELL:
```
# user defined
export TOKEN="YOUR API TOKEN"
export ROOT_PASS="aComplexP@ssword"
export SUDO_USERNAME='admin'

export CA_COMMON_NAME='Kafka RootCA'
export COUNTRY_NAME='US'
export STATE_OR_PROVINCE_NAME='Pennsylvania'
export LOCALITY_NAME='Philadelphia'
export ORGANIZATION_NAME='My Organization'
export EMAIL_ADDRESS='user@example.com'

export CLIENT_COUNT='1'
export CLUSTER_SIZE='3'


curl -H "Content-Type: application/json" \
-H "Authorization: Bearer $TOKEN" \
-X POST -d '{
    "authorized_users": [
        "myuser"
    ],
    "backups_enabled": true,
    "booted": true,
    "image": "linode/ubuntu24.04",
    "label": "linode123",
    "private_ip": true,
    "region": "us-southeast",
    "root_pass": "${ROOT_PASS}",
    "stackscript_data": {
        "kafka_version": "3.7.0",
        "clusterheader": "Yes",
        "add_ssh_keys": "yes",
        "sslheader": "Yes",
        "ca_common_name": "${CA_COMMON_NAME}",
        "token_password": "${TOKEN}",
        "sudo_username": "${SUDO_USERNAME}",
        "client_count": "${CLIENT_COUNT}",
        "cluster_size": "${CLUSTER_SIZE}",
        "country_name": "${COUNTRY_NAME}",
        "state_or_province_name": "${STATE_OR_PROVINCE_NAME}",
        "locality_name": "${LOCALITY_NAME}",
        "organization_name": "${ORGANIZATION_NAME},
        "email_address": "${EMAIL_ADDRESS}"
    },
    "stackscript_id": 00000000000,
    "tags": [],
    "type": "g6-dedicated-4"
}' https://api.linode.com/v4/linode/instances

```

CLI:
```
linode-cli linodes create \
  --label linode123 \
  --root_pass ${ROOT_PASS} \
  --booted true \
  --stackscript_id 00000000000 \
  --stackscript_data '{ 
        "kafka_version": "3.7.0",
        "clusterheader": "Yes",
        "add_ssh_keys": "yes",
        "sslheader": "Yes",
        "ca_common_name": "${CA_COMMON_NAME}",
        "token_password": "${TOKEN}",
        "sudo_username": "${SUDO_USERNAME}",
        "client_count": "${CLIENT_COUNT}",
        "cluster_size": "${CLUSTER_SIZE}",
        "country_name": "${COUNTRY_NAME}",
        "state_or_province_name": "${STATE_OR_PROVINCE_NAME}",
        "locality_name": "${LOCALITY_NAME}",
        "organization_name": "${ORGANIZATION_NAME},
        "email_address": "${EMAIL_ADDRESS}"
   }' \
  --region us-southeast \
  --type g6-dedicated-4 \
  --authorized_users "myUser"
```

## Resources
- [Create Linode via API](https://www.linode.com/docs/api/linode-instances/#linode-create)
- [Stackscript referece](https://www.linode.com/docs/guides/writing-scripts-for-use-with-linode-stackscripts-a-tutorial/#user-defined-fields-udfs)