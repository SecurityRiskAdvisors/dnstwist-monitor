SHELL=/bin/bash
CURRENT_DIR = $(shell pwd)
BUILD_DIR = build
PACKAGE=$(BUILD_DIR)/deployment_package.zip
LAMBDA_FUNC_NAME = dnstwist-monitor
SRC_PATH = src
.DEFAULT_GOAL := build

mvirtual:
	pwd
	virtualenv venv
	. venv/bin/activate; pip3 install -r requirements.txt; pip3 install -r $(SRC_PATH)/dnstwist/requirements.txt; deactivate;

create-build-dir:
	mkdir -p build/

package:
	(cd venv/lib/python3.*/site-packages/ ; pwd ; zip -r9 ../../../../$(PACKAGE) .;)

zip:
	cd $(SRC_PATH); zip -ur ../$(PACKAGE) ./*; cd ../;

build: clean mvirtual create-build-dir package zip

clean:
	rm -f $(PACKAGE)
	rm -rf $(BUILD_DIR)
	rm -rf venv

publish:
	aws lambda update-function-code --function-name $(LAMBDA_FUNC_NAME) --zip-file fileb://$(PACKAGE)

install: publish

run-local:
	cd src; python3 lambda_function.py; cd ../;

tf-init:
	cd tf; terraform init; cd ../;

tf-apply:
	cd tf; terraform apply; cd ../;

tf-destroy:
	cd tf; terraform destroy; cd ../;