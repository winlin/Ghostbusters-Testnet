#!/bin/bash

##########################################
## Created by 				            ##
## Bohdan Kossak, CryptoLions.io 	    ##
## 					                    ##
## Edited for Ghostbusters Testnet by 	##
## Igor Lins e Silva, EOS Rio 		    ##
## Jae Chung, HKEOS  			        ##
##########################################

GLOBAL_PATH=$(pwd)
source "$(dirname $0)/params.sh"
NODE_HTTP_SRV_ADDR="$NODE_NET_ADDR:$NODE_API_PORT"
NODE_P2P_LST_ENDP="$NODE_NET_ADDR:$NODE_P2P_PORT"
NODE_P2P_SRV_ADDR="$NODE_HOST:$NODE_P2P_PORT"
NODE_HTTPS_SERVER_ADDR="$NODE_HOST:$NODE_SSL_PORT"
if [[ $ISBP == true ]]; then
	TESTNET="$TESTNET-$PRODUCER_NAME"
else
	TESTNET="$TESTNET-node"
fi

echo "Work directory: $TESTNET";

######################################################################################################################################################
echo -n $'\E[0;32m'
cat << "EOF"
EOF
######################################################################################################################################################
echo -n $'\E[0;37m'

# Validations

if [[ $ISBP == true ]]; then
	if [[ $PRODUCER_NAME == "<producer-name>" || $PRODUCER_NAME == "" ]]; then
		echo "Please define a producer name!";
		exit 1;
	fi
	if [[ ${#PRODUCER_NAME} != 12 ]]; then
		echo "Producer name must be exactly 12 characters long!";
		exit 1;
	fi	
	if [[ $AGENT_NAME == "<producer-name>" || $AGENT_NAME == "" ]]; then
		echo "Please define an agent name!";
		exit 1;
	fi
	if [[ $PRODUCER_PUB_KEY == "<pub-key>" || $PRODUCER_PUB_KEY == "" ]]; then
		echo "Please define a producer public key!";
		exit 1;
	fi
fi

if [[ $NODE_SSL_PORT == "" ]]; then
	if [[ $NODE_API_PORT == "<api-port>" || $NODE_API_PORT == "" ]]; then
		echo "Please define a http api port!";
		exit 1;
	fi
fi

PRODUCER_PRIV_KEY_DEF="!! INSERT HERE PRIVATE KEY TO THIS PUBLIC ADDRESS !!";
TESTNET_DIR="$GLOBAL_PATH/$TESTNET";

if [[ $EOS_SOURCE_DIR == "" ]]; then
	EOS_SOURCE_DIR="$GLOBAL_PATH/eos-source"
else
	EOS_GIT_BRANCH=$(git -C $EOS_SOURCE_DIR branch | grep '*' | cut -f 5 -d' ' | cut -f1 -d')');
	echo "Source code at branch $EOS_GIT_BRANCH";
	EOS_VERSION=$("$EOS_SOURCE_DIR/nodeos" --version)
	echo "Current nodeos version: $EOS_VERSION";
	if [[ "$EOS_VERSION" != "$EOS_TARGET_VERSION" ]]; then
		echo "Wrong version, $EOS_TARGET_VERSION required!";
		exit 1
	fi
fi

WALLET_DIR="$GLOBAL_PATH/wallet"

# Download sources

if [[ ! -d $EOS_SOURCE_DIR ]]; then
	echo "..:: Downloading EOS Sources ::..";
	mkdir $EOS_SOURCE_DIR
	cd $EOS_SOURCE_DIR

	git clone https://github.com/eosio/eos --recursive .
	git checkout $TAG
	git submodule update --init --recursive
	cd $GLOBAL_PATH
fi


# Compile Sources
if [[ ! -d $EOS_SOURCE_DIR/build ]]; then
	echo "..:: Compiling EOS Sources ::..";
	cd $EOS_SOURCE_DIR
	git pull
	./eosio_build.sh
	cd $GLOBAL_PATH
fi

# Creating Wallet Folder and files

signature='#!/bin/bash
#######################################################
##                                                   ##
## Script Created by CryptoLions, HKEOS and EOS Rio  ##
## For EOS Ghostbusters Testnet                      ##
##                                                   ##
## https://github.com/CryptoLions                    ##
## https://github.com/eosrio                         ##
## https://github.com/HKEOS/Ghostbusters-Testnet  ##
##                                                   ##
#######################################################\n\n';

if [[ ! -d $WALLET_DIR ]]; then
	echo "..:: Creating Wallet Dir: $WALLET_DIR ::..";
	mkdir $WALLET_DIR

	echo "..:: Creating Wallet start.sh ::..";
    # Creating start.sh for wallet
    echo -ne "$signature" > $WALLET_DIR/start.sh
    echo "DATADIR=$WALLET_DIR" >> $WALLET_DIR/start.sh
    echo "\$DATADIR/stop.sh" >> $WALLET_DIR/start.sh
    echo "$EOS_SOURCE_DIR/keosd --data-dir \$DATADIR --http-server-address $WALLET_HOST:$WALLET_PORT \"\$@\" > $WALLET_DIR/stdout.txt 2> $WALLET_DIR/stderr.txt  & echo \$! > \$DATADIR/wallet.pid" >> $WALLET_DIR/start.sh
    echo "echo \"Wallet started\"" >> $WALLET_DIR/start.sh
    chmod u+x $WALLET_DIR/start.sh


    # Creating stop.sh for wallet
    echo -ne "$signature" > $WALLET_DIR/stop.sh
    echo "DIR=$WALLET_DIR" >> $WALLET_DIR/stop.sh
    echo '
    if [ -f $DIR"/wallet.pid" ]; then
    	pid=$(cat $DIR"/wallet.pid")
    	echo $pid
    	kill $pid
    	rm -r $DIR"/wallet.pid"
    	echo -ne "Stopping Wallet"
    	while true; do
    		[ ! -d "/proc/$pid/fd" ] && break
    		echo -ne "."
    		sleep 1
    	done
    	echo -ne "\rWallet stopped. \n"
    fi
    ' >>  $WALLET_DIR/stop.sh
    chmod u+x $WALLET_DIR/stop.sh

fi

#start Wallet
echo "..:: Starting Wallet ::.."
if [[ ! -f $WALLET_DIR/wallet.pid ]]; then
	$WALLET_DIR/start.sh
fi

#################### TESTNET #################################

# Creating TestNet Folder and files
if [[ ! -d $TESTNET_DIR ]]; then
	echo "..:: Creating Testnet Dir: $TESTNET_DIR ::..";

	mkdir $TESTNET_DIR

    # Creating node start.sh 
    echo "..:: Creating start.sh ::..";
    echo -ne "$signature" > $TESTNET_DIR/start.sh
    echo "NODEOS=$EOS_SOURCE_DIR/nodeos" >> $TESTNET_DIR/start.sh
    echo "DATADIR=$TESTNET_DIR" >> $TESTNET_DIR/start.sh
    echo -ne "\n";
    echo "\$DATADIR/stop.sh" >> $TESTNET_DIR/start.sh
    echo -ne "\n";
    echo "\$NODEOS --data-dir \$DATADIR --config-dir \$DATADIR \"\$@\" > \$DATADIR/stdout.txt 2> \$DATADIR/stderr.txt &  echo \$! > \$DATADIR/nodeos.pid" >> $TESTNET_DIR/start.sh
    chmod u+x $TESTNET_DIR/start.sh


    # Creating node stop.sh 
    echo "..:: Creating stop.sh ::..";
    echo -ne "$signature" > $TESTNET_DIR/stop.sh
    echo "DIR=$TESTNET_DIR" >> $TESTNET_DIR/stop.sh
    echo -ne "\n";
    echo '
    if [ -f $DIR"/nodeos.pid" ]; then
    	pid=$(cat $DIR"/nodeos.pid")
    	echo $pid
    	kill $pid
    	rm -r $DIR"/nodeos.pid"
    	echo -ne "Stopping Nodeos"
    	while true; do
    		[ ! -d "/proc/$pid/fd" ] && break
    		echo -ne "."
    		sleep 1
    	done
    	echo -ne "\rNodeos stopped. \n"
    fi
    ' >>  $TESTNET_DIR/stop.sh
    chmod u+x $TESTNET_DIR/stop.sh


    # Creating cleos.sh 
    echo "..:: Creating cleos.sh ::..";
    echo -ne "$signature" > $TESTNET_DIR/cleos.sh
    echo "CLEOS=$EOS_SOURCE_DIR/cleos" >> $TESTNET_DIR/cleos.sh
    echo -ne "\n"
    if [[ $NODE_SSL_PORT != "" ]]; then
    	echo "\$CLEOS -u https://127.0.0.1:$NODE_SSL_PORT --wallet-url http://127.0.0.1:$WALLET_PORT \"\$@\"" >> $TESTNET_DIR/cleos.sh
    else
    	echo "\$CLEOS -u http://127.0.0.1:$NODE_API_PORT --wallet-url http://127.0.0.1:$WALLET_PORT \"\$@\"" >> $TESTNET_DIR/cleos.sh

    fi
    chmod u+x $TESTNET_DIR/cleos.sh
    
    # schema.json
    echo "..:: Downloading schema.json ::..";
    curl https://raw.githubusercontent.com/eosrio/bp-info-standard/master/schema.json > schema.json

    # bp_info_sample.json
    echo "..:: Downloading bp_info_sample.json ::..";
    curl https://raw.githubusercontent.com/eosrio/bp-info-standard/master/bp_info_sample.json > bp_info_sample.json
    
    # autolaunch.sh
    echo "..:: Downloading autolaunch.sh ::..";
    curl https://raw.githubusercontent.com/HKEOS/Ghostbusters-Testnet/master/autolaunch.sh > $TESTNET_DIR/autolaunch.sh
    chmod u+x $TESTNET_DIR/autolaunch.sh
    
    # setupAutoLaunch.sh
    echo "..:: Downloading setupAutoLaunch.sh ::..";
    curl https://raw.githubusercontent.com/HKEOS/Ghostbusters-Testnet/master/setupAutoLaunch.sh > $TESTNET_DIR/setupAutoLaunch.sh
    chmod u+x $TESTNET_DIR/setupAutoLaunch.sh
    


# config.ini 
echo -ne "\n\n..:: Creating config.ini ::..\n\n";
if [[ $ISBP == true && $PRODUCER_PRIV_KEY == "" ]]; then 
	echo -n $'\E[0;33m'
	echo "!!! PRIV KEY SECTION !!! You can enter your private key here and it will be imported in wallet and inserted in config.ini. I can skip this step (Enter) and do it manually before start"
	echo -ne "PRIV KEY (Enter skip):"
	read PRODUCER_PRIV_KEY
	echo -n $'\E[0;37m'
fi

if [[ $ISBP == true ]]; then
	if [[ $PRODUCER_PRIV_KEY == "" ]]; then 
		PRODUCER_PRIV_KEY=$PRODUCER_PRIV_KEY_DEF
	else 
		if [[ ! -f $WALLET_DIR/default.wallet ]]; then
			WALLET_LOG=$( $TESTNET_DIR/cleos.sh wallet create)
			echo "$WALLET_LOG" > wallet_pass.txt
		fi
	fi
	$TESTNET_DIR/cleos.sh wallet import $PRODUCER_PRIV_KEY	
fi

echo "### EOS Ghostbusters Testnet Config file. Autogenerated by script." > $TESTNET_DIR/config.ini
echo '
get-transactions-time-limit = 3
genesis-json = "'$TESTNET_DIR'/genesis.json"
block-log-dir = "'$TESTNET_DIR'/blocks"
http-server-address = '$NODE_HTTP_SRV_ADDR'
p2p-listen-endpoint = '$NODE_P2P_LST_ENDP'
p2p-server-address = '$NODE_P2P_SRV_ADDR'
access-control-allow-origin = *
' >> $TESTNET_DIR/config.ini

if [[ $NODE_SSL_PORT != "" ]]; then
	echo '
	# SSL
	# Filename with https private key in PEM format. Required for https (eosio::http_plugin)
	https-server-address = '$NODE_HTTPS_SERVER_ADDR'
	# Filename with the certificate chain to present on https connections. PEM format. Required for https. (eosio::http_plugin)
	https-certificate-chain-file = '$SSL_CERT_FILE'
	# Filename with https private key in PEM format. Required for https (eosio::http_plugin)
	https-private-key-file = '$SSL_PRIV_KEY'
	' >> $TESTNET_DIR/config.ini
else
	echo '
	# SSL
	# Filename with https private key in PEM format. Required for https (eosio::http_plugin)
	# https-server-address =
	# Filename with the certificate chain to present on https connections. PEM format. Required for https. (eosio::http_plugin)
	# https-certificate-chain-file =
	# Filename with https private key in PEM format. Required for https (eosio::http_plugin)
	# https-private-key-file =
	' >> $TESTNET_DIR/config.ini
fi


echo '
allowed-connection = specified
log-level-net-plugin = info
max-clients = 120
connection-cleanup-period = 30
network-version-match = 1
sync-fetch-span = 2000
enable-stale-production = false
required-participation = 33
plugin = eosio::chain_plugin
plugin = eosio::chain_api_plugin
plugin = eosio::history_plugin
plugin = eosio::history_api_plugin
#plugin = eosio::net_plugin
#plugin = eosio::net_api_plugin
agent-name = '$AGENT_NAME'
' >> $TESTNET_DIR/config.ini

if [[ $ISBP == true ]]; then
	echo '
	plugin = eosio::producer_plugin
	private-key = ["'$PRODUCER_PUB_KEY'","'$PRODUCER_PRIV_KEY'"]
	producer-name = '$PRODUCER_NAME'
	peer-private-key = ["'$PRODUCER_PUB_KEY'","'$PRODUCER_PRIV_KEY'"]
	
	' >> $TESTNET_DIR/config.ini
else
	echo '
	#plugin = eosio::producer_plugin
	#private-key = ["'$PRODUCER_PUB_KEY'","'$PRODUCER_PRIV_KEY'"]
	#peer-private-key = ["'$PRODUCER_PUB_KEY'","'$PRODUCER_PRIV_KEY'"]
	#producer-name = '$PRODUCER_NAME'
	
	' >> $TESTNET_DIR/config.ini
fi
echo "$PEER_LIST" >> $TESTNET_DIR/config.ini
echo "$PEER_KEYS" >> $TESTNET_DIR/config.ini
fi

###############################
# Register Producer

echo '..:: Creating your registerProducer.sh ::..'

echo -ne "$signature" > $TESTNET_DIR/bp01_registerProducer.sh
echo "./cleos.sh system regproducer $PRODUCER_NAME $PRODUCER_PUB_KEY \"$PRODUCER_URL\" -p $PRODUCER_NAME" >> $TESTNET_DIR/bp01_registerProducer.sh
chmod u+x $TESTNET_DIR/bp01_registerProducer.sh

# UnRegister Producer

echo '..:: Creating your unRegisterProducer.sh ::..'

echo -ne "$signature" > $TESTNET_DIR/bp06_unRegisterProducer.sh
echo "./cleos.sh system unregprod $PRODUCER_NAME -p $PRODUCER_NAME" >> $TESTNET_DIR/bp06_unRegisterProducer.sh
chmod u+x $TESTNET_DIR/bp06_unRegisterProducer.sh


# Stake EOS Tokens
echo '..:: Creating Stake script  stakeTokens.sh ::..'

echo -ne "$signature" > $TESTNET_DIR/bp02_stakeTokens.sh
echo "#./cleos.sh system delegatebw $PRODUCER_NAME $PRODUCER_NAME \"1000.0000 EOS\" \"1000.0000 EOS\" -p $PRODUCER_NAME" >> $TESTNET_DIR/bp02_stakeTokens.sh
echo "./cleos.sh push action eosio delegatebw '{\"from\":\"$PRODUCER_NAME\", \"receiver\":\"$PRODUCER_NAME\", \"stake_net_quantity\": \"1000.0000 EOS\", \"stake_cpu_quantity\": \"1000.0000 EOS\", \"transfer\": true}' -p $PRODUCER_NAME" >> $TESTNET_DIR/bp02_stakeTokens.sh

chmod u+x $TESTNET_DIR/bp02_stakeTokens.sh

# Unstake EOS Tokens
echo '..:: Creating Unstake script  unStakeTokens.sh ::..'

echo -ne "$signature" > $TESTNET_DIR/bp05_unStakeTokens.sh
echo "./cleos.sh system undelegatebw $PRODUCER_NAME $PRODUCER_NAME \"1000.0000 EOS\" \"1000.0000 EOS\" -p $PRODUCER_NAME" >> $TESTNET_DIR/bp05_unStakeTokens.sh
chmod u+x $TESTNET_DIR/bp05_unStakeTokens.sh


# Vote Producer
echo '..:: Creating Vote script  voteProducer.sh ::..'

echo -ne "$signature" > $TESTNET_DIR/bp03_voteProducer.sh
echo "./cleos.sh system voteproducer prods $PRODUCER_NAME $PRODUCER_NAME -p $PRODUCER_NAME" >> $TESTNET_DIR/bp03_voteProducer.sh
echo "#./cleos.sh system voteproducer prods $PRODUCER_NAME $PRODUCER_NAME tiger lion -p $PRODUCER_NAME" >> $TESTNET_DIR/bp03_voteProducer.sh
chmod u+x $TESTNET_DIR/bp03_voteProducer.sh

# Claim rewards
echo '..:: Creating ClaimReward script claimReward.sh ::..'

echo -ne "$signature" > $TESTNET_DIR/bp04_claimReward.sh
echo "./cleos.sh system claimrewards $PRODUCER_NAME -p $PRODUCER_NAME" >> $TESTNET_DIR/bp04_claimReward.sh
chmod u+x $TESTNET_DIR/bp04_claimReward.sh

# FINISH

FINISHTEXT="\n.=================================================================================.\n"
FINISHTEXT+="|=================================================================================|\n"
FINISHTEXT+="|˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙...::: INSTALLATION COMPLETED :::...˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙|\n"
FINISHTEXT+="|˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙|\n"
FINISHTEXT+="|˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙- Ghostbusters Testnet Node Info -˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙|\n"
FINISHTEXT+="| ˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙˙|\n"
FINISHTEXT+="\_-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-_/\n"
FINISHTEXT+="\n"
FINISHTEXT+="\n"
FINISHTEXT+="Your wallet password was stored in the file wallet_pass.txt. Please use it to unlock your wallet:\n"
FINISHTEXT+="./cleos.sh wallet unlock\n"
FINISHTEXT+="\n"
FINISHTEXT+="All scripts to manage your node are located in $TESTNET_DIR folder:\n"
FINISHTEXT+="  start.sh - start your node. If you inserted your private key, then everything is ready. So start and please wait until synced.\n"
FINISHTEXT+="  stop.sh - stop your node\n"
FINISHTEXT+="  bp01_registerProducer.sh - register producer. Use it to register in the system contract.\n"
FINISHTEXT+="  bp02_stakeTokens.sh - stake tokens. Use it to stake tokens before voting.\n"
FINISHTEXT+="  bp03_voteProducer.sh - vote example. This example will vote only in yourself. You can add other producers manually in script.\n"
FINISHTEXT+="  bp04_claimReward.sh - claim producer rewards.\n"
FINISHTEXT+="  bp05_unStakeTokens.sh - unstake tokens.\n"
FINISHTEXT+="  bp06_unRegisterProducer.sh - unregister producer.\n"
FINISHTEXT+="  stderr.txt - node logs file\n"
FINISHTEXT+="\n"
FINISHTEXT+="\n"
FINISHTEXT+="To start/stop wallet use start.sh/stop.sh scripts in wallet folder. This installation script will start wallet by default.\n"
FINISHTEXT+="\n"
FINISHTEXT+="Installation script was disabled. To run again please chmod:\n"
FINISHTEXT+="chmod u+x $0\n"
FINISHTEXT+="\n"
FINISHTEXT+=". - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -\n"

echo -n $'\E[0;32m'
echo -ne $FINISHTEXT
echo -ne $FINISHTEXT > ghostbusters.txt

echo ""
echo "This info was saved to ghostbusters.txt file"
echo ""
read -n 1 -s -r -p "Press any key to continue"
chmod 644 $0
