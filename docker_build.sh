docker-machine start
docker-machine env
eval $(docker-machine env)
docker build -t officer .
