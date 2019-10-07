# !/bin/bash

if [ -z "$GDBROOT" ]; then
  echo "GDBROOT is not set as environment variable. Please set it"
  exit 1
fi

source $GDBROOT/network/global-env-vars.sh
source $GDBROOT/network/utils/utils.sh
checkMandatoryEnvironmentVariable "NETWORK_DIR"
checkMandatoryEnvironmentVariable "LOCAL_TESTNET_DIR"
checkMandatoryEnvironmentVariable "CA_ROOT_DIR"
checkMandatoryEnvironmentVariable "CA_ROOT_COMPOSE_PROJECT_NAME"

source $LOCAL_TESTNET_DIR/local-testnet-env-vars.sh
checkMandatoryEnvironmentVariable "LOCAL_TESTNET_COMPOSE_PROJECT_NAME"


# Remove docker containers created after the testnet and their artifacts
removeNodeArtifacts() {
  printSection "Killing docker containers defined in /node-artifacts/local"

  sleep 2s

  while [ -d "$(find $NETWORK_DIR/node-artifacts/local -maxdepth 1 -mindepth 1 -type d  | head -1)" ]; do

    composeDir="$(find $NETWORK_DIR/node-artifacts/local -maxdepth 1 -mindepth 1 -type d  | head -1)"
    dirname="${DOCKER_FILE%"${DOCKER_FILE##*[!/]}"}"
    dirname="${result##*/}"

    COMPOSE_PROJECT_NAME=$dirname docker-compose -f $composeDir/node-docker-compose.yaml down --remove-orphans \
    && COMPOSE_PROJECT_NAME=$dirname docker-compose -f $composeDir/node-docker-compose.yaml kill


    if [ $? -ne 0 ]; then
      printError "Could not stop containers defined in $composeDir, skipping further deletions"
      return 1
    fi

    rm -rf $composeDir

    if [ $? -ne 0 ]; then
      printError "Could not delete directory $composeDir, skipping further deletions"
      return 1
    fi

  done
}

# Remove the basic (operations.geodb.com) containers that bootstrap the network
removeLocalTestnetBaseContainers() {
  printSection "Killing base docker containers"
  sleep 2s

  COMPOSE_PROJECT_NAME=$LOCAL_TESTNET_COMPOSE_PROJECT_NAME \
    docker-compose -f docker-compose.yaml down --remove-orphans && \
    COMPOSE_PROJECT_NAME=$LOCAL_TESTNET_COMPOSE_PROJECT_NAME \
    docker-compose -f docker-compose.yaml kill

}

regenerateCryptoMaterial() {
  printSection "Restoring Crypto material. Stopping all CAs and cleaning up"
  . $LOCAL_TESTNET_DIR/generate-crypto-materials.sh -d
}

cleanDirectories() {
  printSection "Cleanning directories"

  if [ -d "$NETWORK_DIR/channels" ]; then
    printInfo "Removing $NETWORK_DIR/channels"
    rm -rf rm -rf $NETWORK_DIR/channels
  fi

  if [ -d "$NETWORK_DIR/orderer" ]; then
    printInfo "Removing $NETWORK_DIR/orderer"
    rm -rf rm -rf $NETWORK_DIR/orderer
  fi

  if [ -d "$NETWORK_DIR/configtxlator-artifacts" ]; then
    printInfo "Removing $NETWORK_DIR/configtxlator-artifacts"
    rm -rf rm -rf $NETWORK_DIR/configtxlator-artifacts
  fi
}

restoreCA() {
  printSection "Restoring root CA"

  COMPOSE_PROJECT_NAME=$CA_ROOT_COMPOSE_PROJECT_NAME docker-compose --file $CA_ROOT_DIR/docker-compose.yaml kill && \
  COMPOSE_PROJECT_NAME=$CA_ROOT_COMPOSE_PROJECT_NAME docker-compose --file $CA_ROOT_DIR/docker-compose.yaml down

  if [ -d "$CA_ROOT_DIR/fabric-ca-server" ]; then
    printInfo "Removing $CA_ROOT_DIR/fabric-ca-server"
    rm -rf $CA_ROOT_DIR/fabric-ca-server
  fi
}

removeNodeArtifacts
checkFatalError $?

removeLocalTestnetBaseContainers
checkFatalError $?

regenerateCryptoMaterial
checkFatalError $?

cleanDirectories
checkFatalError $?

restoreCA
checkFatalError $?

printSection "Your system is now prepared for a new network. Good Luck!"
