# !/bin/bash

source $GDBROOT/network/global-env-vars.sh
source $GDBROOT/network/utils/utils.sh

DOCKER_FILE=$1

if [ -z "$DOCKER_FILE" ]; then
  checkMandatoryEnvironmentVariable "LOCAL_TESTNET_DIR"
  echo "Using default testnet .yaml"
  export COMPOSE_PROJECT_NAME=geodb
  DOCKER_FILE=$LOCAL_TESTNET_DIR/docker-compose.yaml
else
  # Assign the directory name of the docker file as the project name for compose
  dirname="${DOCKER_FILE%"${DOCKER_FILE##*[!/]}"}"
  dirname="${result##*/}"
  export COMPOSE_PROJECT_NAME=$dirname
fi

# Bring up the network
docker-compose -f $DOCKER_FILE up -d
