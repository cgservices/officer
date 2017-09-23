#!/usr/bin/env bash
docker build --force-rm --no-cache --pull -t creativegroup/officer:latest .
docker push creativegroup/officer:latest