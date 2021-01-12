#!/bin/sh

EXIT_USAGE=false
[ -z "$1" ] && EXIT_USAGE=true
[ -z "$2" ] && EXIT_USAGE=true
[ -z "$3" ] && EXIT_USAGE=true
[ -z "$4" ] && EXIT_USAGE=true

# $1 should be the name of the deployed chaincode
# $2 should be the path to the Go sources
# $3 should be the version of the chaincode (change for every deployment)
# $4 should be the sequence number for deployment (always exactly one more than the last sequence number)
[ $EXIT_USAGE = true ] && { echo "Usage: ./deployChaincode.sh [chaincode name] [path to chaincode source] [chaincode version] [sequence number]"; exit 1; }

export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=$PWD/../config/

echo "Packaging..."
peer lifecycle chaincode package "$1.tar.gz" --path "$2" --lang golang --label "$1_$3"

export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

echo "Installing on Org1"
peer lifecycle chaincode install "$1.tar.gz"

export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

echo "Installing on Org2"
peer lifecycle chaincode install "$1.tar.gz"

echo "Installing on Org2 and getting package identifier"
SOMENAME="$(peer lifecycle chaincode queryinstalled)"
echo "$SOMENAME"
SOMENAME="$(echo "$SOMENAME" | grep "$1_$3")"
echo "$SOMENAME"
SOMENAME="$(echo "$SOMENAME" | sed 's/Package ID: //' | sed 's/, .*//')"
echo "$SOMENAME"
export CC_PACKAGE_ID="$SOMENAME"
echo "$CC_PACKAGE_ID"

echo "Approving for Org2"
peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --channelID mychannel --name "$1" --version "$3" --package-id "$CC_PACKAGE_ID" --sequence "$4" --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_ADDRESS=localhost:7051

echo "Approving for Org1"
peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --channelID mychannel --name "$1" --version "$3" --package-id "$CC_PACKAGE_ID" --sequence "$4" --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

peer lifecycle chaincode commit -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --channelID mychannel --name "$1" --version "$3" --sequence "$4" --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem --peerAddresses localhost:7051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --peerAddresses localhost:9051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt

peer lifecycle chaincode querycommitted --channelID mychannel --name "$1" --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
