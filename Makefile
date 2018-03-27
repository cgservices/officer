REPOSITORY = creativegroup/officer

DOCKERFILE_INTEGRATION = .docker/integration/Dockerfile

DOCKER_COMPOSE_INTEGRATION = docker-compose -f docker-compose.integration.yml

integration:
	docker build --squash --file $(DOCKERFILE_INTEGRATION) --force-rm --no-cache --pull -t $(REPOSITORY):integration .
	docker push $(REPOSITORY):integration

start-integration:
	$(DOCKER_COMPOSE_INTEGRATION) up -d

stop-integration:
	$(DOCKER_COMPOSE_INTEGRATION) stop
