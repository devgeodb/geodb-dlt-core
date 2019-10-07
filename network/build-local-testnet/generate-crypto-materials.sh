#!/bin/bash +x

###############################################################################
# Usar este script como sustitución de cryptogen
# en entornos de producción
##############################################################################

function main {

  printSection "Generating crypto material using Fabric CA"
  printInfo "Checking executables ..."
  mydir=`pwd`
  checkExecutables
  checkFatalError $?
  checkRootCA
  checkFatalError $?
  if [ -d $CRYPTO_CONFIG_DIR ]; then
    printInfo "Cleaning up CAs"
    stopAllCAs
    checkFatalError $?
    # rm -rf $CRYPTO_CONFIG_DIR
  fi
  printInfo "Setting up organizations"
  setupOrgs
  checkFatalError $?
  # echo "Finishing ..."
  # stopAllCAs
  # echo "Complete"
}

# Check and build executables as needed
function checkExecutables {
   if [ ! -d $HLF_CA_HOME ]; then
     fatal "Directory does not exist: $HLF_CA_HOME"
   fi

   if [ ! -x $HLF_CA_SERVER ]; then
      pushd $HLF_CA_HOME
      make fabric-ca-server
      if [ $? -ne 0 ]; then
         fatal "Failed to build $HLF_CA_SERVER"
      fi
      popd
   fi

   if [ ! -x $HLF_CA_CLIENT ]; then
      pushd $HLF_CA_HOME
      make fabric-ca-client
      if [ $? -ne 0 ]; then
         fatal "Failed to build $HLF_CA_CLIENT"
      fi
      popd
   fi
}

# Stop all CA servers
function stopAllCAs {
   for pidFile in `find $CRYPTO_CONFIG_DIR -name server.pid`
   do
      if [ ! -f $pidFile ]; then
         fatal "\"$pidFile\" is not a file"
      fi
      pid=`cat $pidFile`
      dir=$(dirname $pidFile)
      printInfo "Stopping CA server in $dir with PID $pid ..."
      if ps -p $pid > /dev/null
      then
         kill -9 $pid
         wait $pid 2>/dev/null
         rm -f $pidFile
         printDebug "Stopped CA server in $dir with PID $pid"
      fi
   done
}

# Setup orderer and peer organizations
function setupOrgs {
   for ORG in $ORGS
   do
      setupOrg $ORG
   done
}

# Start an organization's root and intermediate CA servers
#   setupOrg <orgName>:<numPeers>:<numOrderers>:<rootCAPort>:rootCAUser:rootCAPass:<intermediateCAPort>
function setupOrg {
   IFSBU=$IFS
   IFS=: args=($1)
   if [ ${#args[@]} -ne 7 ]; then
      fatal "setupOrg: bad org spec: $1"
   fi

   orgName=${args[0]}
   orgDir=$CRYPTO_CONFIG_DIR/$orgName

   if [ -d $orgDir -a "$RECREATE" = false ]; then
      printWarning "$orgName already exists, skipping"
      return 0
   fi


   if [ -d $orgDir -a "$RECREATE" = true ]; then
     printInfo "Removing ${orgName} certificates and recreating"
     rm -rf $orgDir
   fi

   numPeers=${args[1]}
   numOrderers=${args[2]}

   printInfo "Generating organization ${orgName} with ${numPeers} peer(s) and ${numOrderers} orderer(s)"
   orgDir=${CRYPTO_CONFIG_DIR}/${orgName}
   rootCAPort=${args[3]}
   rootCAUser=${args[4]}
   rootCAPass=${args[5]}
   intermediateCAPort=${args[6]}
   usersDir=$orgDir/users

   IFS=$IFSBU

   # # Start the root CA server
   # startCA $orgDir/ca/root $rootCAPort $orgName
   # # Enroll an admin user with the root CA

   # adminHome=$usersDir/rootAdmin
   # enroll $adminHome http://admin:adminpw@localhost:$rootCAPort $orgName

   # Start the intermediate CA server
   # startCA $orgDir/ca/intermediate $intermediateCAPort $orgName http://admin:adminpw@localhost:$rootCAPort

   startCA $orgDir/ca/intermediate $intermediateCAPort $orgName https://${rootCAUser}:${rootCAPass}@ca-root.geodb.com:$rootCAPort

   # Enroll an admin user with the intermediate CA
   adminHome=$usersDir/intermediateAdmin
   intermediateCAURL=https://admin:adminpw@localhost:$intermediateCAPort
   intermediateCATlsCert=$(realpath $orgDir/ca/intermediate/tls-cert.pem)
   enroll $adminHome $intermediateCAURL $orgName $intermediateCATlsCert


   # Register and enroll admin with the intermediate CA
   adminUserHome=$usersDir/Admin@${orgName}
   registerAndEnroll $adminHome $adminUserHome $intermediateCAPort $orgName $intermediateCATlsCert nodeAdmin
   # Register and enroll user1 with the intermediate CA
   user1UserHome=$usersDir/User1@${orgName}
   registerAndEnroll $adminHome $user1UserHome $intermediateCAPort $orgName $intermediateCATlsCert
   # Create peer nodes
   peerCount=0
   while [ $peerCount -lt $numPeers ]; do

      nodeDir=$orgDir/peers/peer${peerCount}.${orgName}

      mkdir -p $nodeDir
      # Get TLS crypto for this node
      tlsEnroll $nodeDir $intermediateCAPort $orgName $intermediateCATlsCert
      # Register and enroll this node's identity
      registerAndEnroll $adminHome $nodeDir $intermediateCAPort $orgName $intermediateCATlsCert
      normalizeMSP $nodeDir $orgName $adminUserHome
      peerCount=$(expr $peerCount + 1)
   done

   # Create orderer nodes
   ordererCount=0
   while [ $ordererCount -lt $numOrderers ]; do

      nodeDir=$orgDir/orderers/orderer${ordererCount}.${orgName}

      mkdir -p $nodeDir
      # Get TLS crypto for this node
      tlsEnroll $nodeDir $intermediateCAPort $orgName $intermediateCATlsCert
      # Register and enroll this node's identity
      registerAndEnroll $adminHome $nodeDir $intermediateCAPort $orgName $intermediateCATlsCert
      normalizeMSP $nodeDir $orgName $adminUserHome
      ordererCount=$(expr $ordererCount + 1)
   done


   # # Get CA certs from intermediate CA
   getcacerts $orgDir $intermediateCAURL $intermediateCATlsCert
   # Rename MSP files to names expected by end-to-end
   normalizeMSP $orgDir $orgName $adminUserHome
   normalizeMSP $adminHome $orgName
   normalizeMSP $adminUserHome $orgName
   normalizeMSP $user1UserHome $orgName

   printDebug "Successfully generated crypto materials for organization $orgName"
}

# Start a root CA server:
#    startCA <homeDirectory> <listeningPort> <orgName>
# Start an intermediate CA server:
#    startCA <homeDirectory> <listeningPort> <orgName> <parentURL>
function startCA {
   homeDir=$1; shift
   port=$1; shift
   orgName=$1; shift
   parentCAurl=$1; shift

   mkdir -p $homeDir
   export FABRIC_CA_SERVER_HOME=$homeDir

   $HLF_CA_SERVER start -d -p $port -b admin:adminpw -u $parentCAurl --tls.enabled --intermediate.tls.certfiles $TLSROOTCERT > $homeDir/server.log 2>&1&

   echo $! > $homeDir/server.pid
   checkFatalError $?

   printInfo "Starting CA server in $homeDir on port $port ..."
   sleep 1
   checkCA $homeDir $port
   # Get the TLS crypto for this CA
   tlsEnroll $homeDir $port $orgName
}

# Make sure a CA server is running
#    checkCA <homeDirectory>
function checkCA {
   pidFile=$1/server.pid
   if [ ! -f $pidFile ]; then
      fatal  "No PID file for CA server at $1"
   fi
   pid=`cat $pidFile`
   if ps -p $pid > /dev/null
   then
      printInfo "CA server is started in $1 and listening on port $2"
   else
      fatal "CA server is not running at $1; see logs at $1/server.log"
   fi
}

# Enroll to get TLS crypto material
#    tlsEnroll <homeDir> <serverPort> <orgName>
function tlsEnroll {
   homeDir=$1; shift
   port=$1; shift
   orgName=$1; shift
   tlsCert=$1; shift;

   host=$(basename $homeDir),$(basename $homeDir | cut -d'.' -f1)
   tlsDir=$homeDir/tls

   if [ "$tlsCert" = "" ]; then
     tlsCert=$(realpath $homeDir/tls-cert.pem)
   fi

   srcMSP=$tlsDir/msp
   dstMSP=$homeDir/msp
   printDebug "enroll $tlsDir https://admin:adminpw@localhost:$port $orgName $tlsCert --csr.hosts $host --enrollment.profile tls"
   enroll $tlsDir https://admin:adminpw@localhost:$port $orgName $tlsCert --csr.hosts $host --enrollment.profile tls
   cp $srcMSP/signcerts/* $tlsDir/server.crt
   cp $srcMSP/keystore/* $tlsDir/server.key
   mkdir -p $dstMSP/keystore

   cp $srcMSP/keystore/* $dstMSP/keystore
   mkdir -p $dstMSP/cacerts
   cp $srcMSP/cacerts/* $dstMSP/cacerts/tlsca.${orgName}-cert.pem
   if [ -d $srcMSP/intermediatecerts ]; then
      cp $srcMSP/intermediatecerts/* $tlsDir/ca.crt
      mkdir -p $dstMSP/intermediatecerts
      cp $srcMSP/intermediatecerts/* $dstMSP/intermediatecerts
   else
      cp $srcMSP/cacerts/* $tlsDir/ca.crt
   fi
   rm -rf $srcMSP $homeDir/enroll.log $homeDir/fabric-ca-client-config.yaml
}

# Register and enroll a new user
#    registerAndEnroll <registrarHomeDir> <registreeHomeDir> <caPort> <orgName> <tlsCert> [<userName>]
function registerAndEnroll {

  registrarHomeDir=$1; shift
  registreeHomeDir=$1; shift
  caPort=$1; shift
  orgName=$1; shift
  tlsCert=$1; shift
  userName=$1; shift

  if [ "$userName" = "" ]; then
    userName=$(basename $registreeHomeDir)
  fi

  register $userName "secret" $registrarHomeDir $tlsCert
  enroll $registreeHomeDir https://${userName}:secret@localhost:$caPort $orgName $tlsCert
}

# Enroll an identity
#    enroll <homeDir> <serverURL> <orgName> <tlsCert> [<args>]
function enroll {
   homeDir=$1; shift
   url=$1; shift
   orgName=$1; shift
   tlsCert=$1; shift
   mkdir -p $homeDir
   export FABRIC_CA_CLIENT_HOME=$homeDir
   logFile=$homeDir/enroll.log

   # Get an enrollment certificate
   $HLF_CA_CLIENT enroll -d -u $url --tls.certfiles $tlsCert > $logFile 2>&1

   if [ $? -ne 0 ]; then
      fatal "Failed to enroll $homeDir with CA at $url; see $logFile"
   fi
   printDebug "Enrolled $homeDir with CA at $url"
}

# Register a new user
#    register <user> <password> <registrarHomeDir> <tlsCert>
function register {

  userName=$1; shift
  password=$1; shift
  homeDir=$1; shift
  tlsCert=$1; shift

  export FABRIC_CA_CLIENT_HOME=$homeDir
  mkdir -p $homeDir
  logFile=$homeDir/register.log

  $HLF_CA_CLIENT register --id.name $userName --id.secret $password --tls.certfiles $tlsCert --id.type user --id.affiliation org1 -d > $logFile 2>&1
  if [ $? -ne 0 ]; then
    fatal "Failed to register $userName with CA as $homeDir; see $logFile"
  fi
  printDebug "Registered user $userName with intermediate CA as $homeDir"
}

# Rename MSP files as is expected by the e2e example
#    normalizeMSP <home> <orgName> <adminHome>
function normalizeMSP {
   userName=$(basename $1)
   mspDir=$1/msp
   orgName=$2
   admincerts=$mspDir/admincerts
   cacerts=$mspDir/cacerts
   intcerts=$mspDir/intermediatecerts
   signcerts=$mspDir/signcerts
   cacertsfname=$cacerts/tlsca.${orgName}-cert.pem
   if [ ! -f $cacertsfname ]; then
      mv $cacerts/* $cacertsfname
   fi
   intcertsfname=$intcerts/ca.${orgName}-cert.pem
   if [ ! -f $intcertsfname ]; then
      if [ -d $intcerts ]; then
         mv $intcerts/* $intcertsfname
      fi
   fi
   signcertsfname=$signcerts/${userName}-cert.pem
   if [ ! -f $signcertsfname ]; then
      fname=`ls $signcerts 2> /dev/null`
      if [ "$fname" = "" ]; then
         mkdir -p $signcerts
         cp $cacertsfname $signcertsfname
      else
         mv $signcerts/* $signcertsfname
      fi
   fi

   # Copy the admin cert, which would need to be done out-of-band in the real world
   mkdir -p $admincerts
   if [ $# -gt 2 ]; then
      src=`ls $3/msp/signcerts/*`
      dst=$admincerts/Admin@${orgName}-cert.pem
   else
      src=`ls $signcerts/*`
      dst=$admincerts
   fi
   if [ ! -f $src ]; then
      fatal "admin certificate file not found at $src"
   fi
   cp $src $dst
}

# Get the CA certificates and place in MSP directory in <dir>
#    getcacerts <dir> <serverURL>
function getcacerts {
  dir=$1; shift
  caUrl=$1; shift
  tlsCert=$1; shift
  mkdir -p $dir
  export FABRIC_CA_CLIENT_HOME=$dir
  logFile=$dir/getcacert.out
  $HLF_CA_CLIENT getcacert -u $caUrl --tls.certfiles $tlsCert > $logFile 2>&1
  if [ $? -ne 0 ]; then
    fatal "Failed to get CA certificates $dir with CA at $caUrl; see $logFile"
  fi
  mkdir $dir/msp/tlscacerts
  cp $dir/msp/cacerts/* $dir/msp/tlscacerts
  printDebug "Loaded CA certificates into $dir from CA at $caUrl"
}

function checkRootCA {
  if [ ! "$(docker ps -q -f name=ca-root.geodb.com)" ]; then
    fatal "Root CA container is not running"
  else
    printDebug "Root CA is running"
  fi

}

function wipeout {
  printSection "Cleaning up"

  if [ -d $CRYPTO_CONFIG_DIR ]; then
    stopAllCAs
    rm -rf $CRYPTO_CONFIG_DIR
  fi
}

###################################
# Environment variables and utils #
###################################

source $GDBROOT/network/utils/utils.sh
source $GDBROOT/network/global-env-vars.sh

checkMandatoryEnvironmentVariable "CRYPTO_CONFIG_DIR"
checkMandatoryEnvironmentVariable "HLF_CA_HOME"
checkMandatoryEnvironmentVariable "HLF_CA_CLIENT"
checkMandatoryEnvironmentVariable "HLF_CA_SERVER"
checkMandatoryEnvironmentVariable "LOCAL_TESTNET_DIR"
source $LOCAL_TESTNET_DIR/local-testnet-env-vars.sh
checkMandatoryEnvironmentVariable "TLSROOTCERT"

##############
# Arg parser #
##############

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -o|--orgs)
    ORGS="$2"
    shift
    shift
    ;;
    -r|--recreate)
    RECREATE="$2"
    shift
    shift
    ;;
    -d|--delete)
    DELETE=true
    shift
    ;;
    *)
    POSITIONAL+=("$1")
    shift
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

if [ -z "$DELETE" ]; then
  DELETE=false
fi

if [ $DELETE == true ]; then
  wipeout
else
  # Organization info where each line is of the form:
  #    <orgName>:<numPeers>:<numOrderers>:<rootCAPort>:rootCAUser:rootCAPass:<intermediateCAPort>
  if [ -z "$ORGS" ]; then
    fatal "--ORGS not found"
  fi

  if [ -z "$RECREATE" ]; then
    # If true, recreate crypto if it already exists
    printDebug "Setting RECREATE=false"
    RECREATE=false
  fi

  # if [ -z "$INTERMEDIATE_CA" ]; then
  #   # If true, uses both a root and intermediate CA
  #   echo "Setting INTERMEDIATE_CA=true"
  #   INTERMEDIATE_CA=true
  # fi

  printInfo "Running script with args:"
  printInfo "ORGS: ${ORGS}"
  printInfo "RECREATE: ${RECREATE}"

  main
fi
