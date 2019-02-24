# For interactive prompt

SHELL = /bin/bash

# Help

help:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null \
		| awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' \
		| egrep -v -e '^[^[:alnum:]]' -e '^$@$$' | sort -r

# Default settings

DEFAULT_REGION := europe-west1
DEFAULT_DEPLOYMENTS_PATH := ./deployments

gcloud-config-rael-base:
	gcloud config set project rael-base
	gcloud config set compute/region ${DEFAULT_REGION}

# Deployment list

DEPLOYMENTS=$(shell \
	find ${DEFAULT_DEPLOYMENTS_PATH}/* -type f -name '*.yaml' \
	| sed "s:${DEFAULT_DEPLOYMENTS_PATH}/\(.*\).yaml:\1:g" \
)

# Target for getting the deployment variables from the file path/name
# The convention is ${project-id}/${folder}/${deployment-name}.yaml
.PHONY+=$(addprefix .dm-set-,$(DEPLOYMENTS))
$(addprefix .dm-set-,$(DEPLOYMENTS)):.dm-set-%:
	$(eval project_id	:= $(firstword $(subst /, ,$*)))
	$(eval dm_name		:= ${project_id}-$(lastword $(subst /, ,$*)))
	$(eval dm_config	:= ${DEFAULT_DEPLOYMENTS_PATH}/$*.yaml)

# Target for creating the deployment
.PHONY+=$(addprefix dm-create-,$(DEPLOYMENTS))
$(addprefix dm-create-,$(DEPLOYMENTS)):dm-create-%:.dm-set-%
	gcloud deployment-manager deployments \
		create ${dm_name} \
		--config ${dm_config} \
		--project ${project_id}

# Target for updating the deployment after previewing the changes
# Requires a manual user confirmation after the preview
.PHONY+=$(addprefix dm-update-,$(DEPLOYMENTS))
$(addprefix dm-update-,$(DEPLOYMENTS)):dm-update-%:.dm-set-% dm-preview-%
	@echo -n "Ready to update, are you sure? Ctrl+C to cancel " \
		&& read ans
	gcloud deployment-manager deployments \
		update ${dm_name} \
		--project ${project_id}

# Target for previewing the deployment
.PHONY+=$(addprefix dm-preview-,$(DEPLOYMENTS))
$(addprefix dm-preview-,$(DEPLOYMENTS)):dm-preview-%:.dm-set-%
	gcloud deployment-manager deployments \
		update ${dm_name} \
		--config ${dm_config} \
		--project ${project_id} \
		--preview
