REPOSITORY = creativegroup/officer

DOCKERFILE_INTEGRATION = .docker/integration/Dockerfile
DOCKER_COMPOSE_INTEGRATION = docker-compose -f docker-compose.integration.yml

DOCKER_ARGS = --force-rm --no-cache
DOCKER_PUSH = yes

integration:
	docker build --squash --file $(DOCKERFILE_INTEGRATION) $(DOCKER_ARGS) --pull -t $(REPOSITORY):integration .
ifeq ($(DOCKER_PUSH),yes)
	$(call docker-push,integration)
endif

start-integration:
	$(DOCKER_COMPOSE_INTEGRATION) up -d

stop-integration:
	$(DOCKER_COMPOSE_INTEGRATION) stop

clean-integration:
	$(DOCKER_COMPOSE_INTEGRATION) down

define docker-push
	docker push $(REPOSITORY):$1
endef
