# dnstwist-monitor

dnstwist-monitor is a Lambda-ification of [elceef/dnstwist](https://github.com/elceef/dnstwist).

*Tested on Ubuntu 18.04.3*

## Setup

This project uses dnstwist as a submodule. 
```bash
git submodule add https://github.com/elceef/dnstwist src/dnstwist
```

Be sure to install the following for the dnstwist requirements to be bundled into the deployment package for AWS.

```bash
sudo apt install python3-dnspython python3-geoip python3-whois \
    python3-requests python3-ssdeep libfuzzy-dev libgeoip-dev
    
```

Terraform will handle the creation of the Lambda function resource, a DynamoDB table, and Systems Manager parameters in the AWS console as well as the associated IAM policies needed. 

**Please see [`tf/README.md`](tf/README.md) for important information on preparing the Terraform configuration for deployment.**

Note: Longer domains may need more than 15 minutes, which is the maximum time allowed for Lambda execution. 

## Usage

```bash
# clean, initialize terraform, build, and apply terraform conf to AWS
make clean tf-init build tf-apply
```

## Extra configuration

To enable debug logs for the Lambda function, add an environment variable in the Lambda console called "dnstwistlogginglevel" and set to "INFO"

To make a Lambda function use a "generic" version of the SSM path (without client code; if all discoveries are being logged to the same Jira instance), add an environment variable in the Lambda console called "genericssm" and set to "true"

## License
[GNU AGPLv3](LICENSE)