#!/usr/bin/env bash
docker build --force-rm --no-cache --pull --build-arg SSH_KEY="$(< ~/.ssh/id_rsa)" -t creativegroup/officer:latest .
docker push creativegroup/officer:latest