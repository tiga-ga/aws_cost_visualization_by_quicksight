DOCKER_COMPOSE=docker-compose run terraform

init:
	$(DOCKER_COMPOSE) init -reconfigure

plan:
	$(DOCKER_COMPOSE) plan -var-file=/workspace/terraform.tfvars

apply:
	$(DOCKER_COMPOSE) apply -var-file=/workspace/terraform.tfvars

fmt:
	$(DOCKER_COMPOSE) fmt

destroy:
	$(DOCKER_COMPOSE) destroy -var-file=/workspace/terraform.tfvars