#!/bin/bash
set -e

GREEN="\033[0;32m"
CYAN="\033[0;36m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m"

# BANNER
echo -e "${GREEN}"
cat << 'EOF'
 ______              _         _                                             
|  ___ \            | |       | |                   _                        
| |   | |  ___    _ | |  ____ | | _   _   _  ____  | |_   ____   ____  _____ 
| |   | | / _ \  / || | / _  )| || \ | | | ||  _ \ |  _) / _  ) / ___)(___  )
| |   | || |_| |( (_| |( (/ / | | | || |_| || | | || |__( (/ / | |     / __/ 
|_|   |_| \___/  \____| \____)|_| |_| \____||_| |_| \___)\____)|_|    (_____)
EOF
echo -e "${NC}"

read_secret() {
  prompt="$1"
  secret=""
  charcount=0

  printf "${CYAN}${prompt}${NC} "
  while IFS= read -r -s -n1 char; do
    if [[ $char == $'\0' || $char == $'\n' ]]; then
      break
    fi
    if [[ $char == $'\177' ]]; then
      # handle backspace
      if [ $charcount -gt 0 ]; then
        charcount=$((charcount-1))
        secret="${secret%?}"
        printf '\b \b'
      fi
    else
      secret+="$char"
      charcount=$((charcount+1))
      printf '*'
    fi
  done
  echo
  REPLY="$secret"
}


echo -e "${GREEN}===== Ritual Infernet Node Manager =====${NC}"

echo -e "${CYAN}\nChoose an option:${NC}"
echo -e "${YELLOW}1)${NC} Install Ritual Infernet Node"
echo -e "${YELLOW}2)${NC} Update Contract Address and Call sayGM"
echo -e "${YELLOW}3)${NC} Exit"
read -rp "$(echo -e ${CYAN}Enter your choice [1-3]: ${NC})" CHOICE

if [[ "$CHOICE" == "1" ]]; then
  read_secret "Enter your Alchemy BASE Mainnet RPC URL:"
  RPC_URL="$REPLY"

  read_secret "Enter your PRIVATE KEY (with 0x):"
  WALLET_KEY="$REPLY"

  sudo apt update && sudo apt upgrade -y
  sudo apt -qy install curl git nano jq lz4 build-essential screen ufw apt-transport-https ca-certificates software-properties-common

  # === Step 2: Docker Installation (skip if already installed) ===
if ! command -v docker &> /dev/null; then
  echo -e "${GREEN}[2/12] Installing Docker via CodeDialect script...${NC}"
  curl -sL https://raw.githubusercontent.com/CodeDialect/aztec-squencer/main/docker.sh | bash
else
  echo -e "${YELLOW}[2/12] Docker already installed. Skipping Docker setup.${NC}"
fi


  sudo ufw allow OpenSSH
  for port in 22 3001 4000 6379 8545; do sudo ufw allow $port; done
  sudo ufw allow ssh
  sudo ufw --force enable

  git clone https://github.com/ritual-net/infernet-container-starter
  cd infernet-container-starter
  sed -i 's/3000:3000/3001:3001/g' deploy/docker-compose.yaml
  sed -i 's/8545:3000/8545:3001/g' deploy/docker-compose.yaml
  docker pull ritualnetwork/hello-world-infernet:latest
  project=hello-world docker compose -f deploy/docker-compose.yaml up -d
  
	[ -d deploy/config.json ] && rm -rf deploy/config.json
	[ -d projects/hello-world/container/config.json ] && rm -rf projects/hello-world/container/config.json

  for f in deploy/config.json projects/hello-world/container/config.json; do
    cat > "$f" <<EOF
{
  "log_path": "infernet_node.log",
  "server": { "port": 4000, "rate_limit": { "num_requests": 100, "period": 100 } },
  "chain": {
    "enabled": true,
    "trail_head_blocks": 3,
    "rpc_url": "$RPC_URL",
    "registry_address": "0x3B1554f346DFe5c482Bb4BA31b880c1C18412170",
    "wallet": {
      "max_gas_limit": 4000000,
      "private_key": "$WALLET_KEY",
      "allowed_sim_errors": []
    },
    "snapshot_sync": { "sleep": 3, "batch_size": 500, "starting_sub_id": 240000, "sync_period": 30 }
  },
  "startup_wait": 1.0,
  "redis": { "host": "redis", "port": 6379 },
  "forward_stats": true,
  "containers": [
    {
      "id": "hello-world",
      "image": "ritualnetwork/hello-world-infernet:latest",
      "external": true,
      "port": "3001",
      "allowed_delegate_addresses": [],
      "allowed_addresses": [],
      "allowed_ips": [],
      "command": "--bind=0.0.0.0:3001 --workers=2",
      "env": {}, "volumes": [],
      "accepted_payments": {}, "generates_proofs": false
    }
  ]
}
EOF
  done

  cat > projects/hello-world/contracts/Makefile <<EOF
.PHONY: deploy call-contract

sender := $WALLET_KEY
RPC_URL := $RPC_URL

deploy:
	@PRIVATE_KEY=\$(sender) forge script script/Deploy.s.sol:Deploy --broadcast --rpc-url \$(RPC_URL)

call-contract:
	@PRIVATE_KEY=\$(sender) forge script script/CallContract.s.sol:CallContract --broadcast --rpc-url \$(RPC_URL)
EOF

  cat > projects/hello-world/contracts/script/Deploy.s.sol <<'EOF'
// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.13;
import {Script, console2} from "forge-std/Script.sol";
import {SaysGM} from "../src/SaysGM.sol";

contract Deploy is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address deployerAddress = vm.addr(deployerPrivateKey);
        console2.log("Loaded deployer: ", deployerAddress);
        address registry = 0x3B1554f346DFe5c482Bb4BA31b880c1C18412170;
        SaysGM saysGm = new SaysGM(registry);
        console2.log("Deployed SaysHello: ", address(saysGm));
        vm.stopBroadcast();
        vm.broadcast();
    }
}
EOF

  # === Stop anvil to allow Foundry install ===
  echo -e "${YELLOW}Stopping all docker containers temporarily for Foundry install...${NC}"
 docker compose -f $HOME/infernet-container-starter/deploy/docker-compose.yaml down
  
  echo -e "${GREEN}Installing Foundry...${NC}"
  curl -L https://foundry.paradigm.xyz | bash
  echo 'export PATH="$HOME/.foundry/bin:$PATH"' >> ~/.bashrc
  export PATH="$HOME/.foundry/bin:$PATH"
  "$HOME/.foundry/bin/foundryup"

  cd projects/hello-world/contracts
  rm -rf lib/forge-std lib/infernet-sdk
  forge install foundry-rs/forge-std
  forge install ritual-net/infernet-sdk

  # === Restart anvil container === 
  echo -e "${GREEN}Restarting containers...${NC}"
  docker compose -f $HOME/infernet-container-starter/deploy/docker-compose.yaml up -d


  echo -e "${GREEN}Deploying contract...${NC}"
  cd "$HOME/infernet-container-starter/projects/hello-world/contracts"
	DEPLOY_OUTPUT=$(PRIVATE_KEY="$WALLET_KEY" forge script script/Deploy.s.sol:Deploy --broadcast --rpc-url "$RPC_URL" 2>&1 | tee /tmp/deploy_output.log)
  CONTRACT_ADDRESS=$(grep "Deployed SaysHello" /tmp/deploy_output.log | grep -oE '0x[a-fA-F0-9]{40}' | tail -n1)
  echo -e "${GREEN}Deployed contract address: ${CYAN}${CONTRACT_ADDRESS}${NC}"

  read -rp "$(echo -e ${CYAN}Do you want to update CallContract.s.sol and call it now? [y/N]:${NC} ) " DO_CALL
  if [[ "$DO_CALL" =~ ^[Yy]$ ]]; then
  TARGET_FILE="$HOME/infernet-container-starter/projects/hello-world/contracts/script/CallContract.s.sol"

  if [[ -f "$TARGET_FILE" ]]; then
    sed -i "s|SaysGM saysGm = SaysGM(.*);|SaysGM saysGm = SaysGM(${CONTRACT_ADDRESS});|" "$TARGET_FILE"
    echo -e "${YELLOW}✅ Updated contract address in CallContract.s.sol${NC}"

    echo -e "${GREEN}?? Calling contract...${NC}"
    cd "$HOME/infernet-container-starter"
    project=hello-world make call-contract
  else
    echo -e "${RED}❌ CallContract.s.sol not found at: $TARGET_FILE${NC}"
  fi
fi


elif [[ "$CHOICE" == "2" ]]; then
  read -rp "$(echo -e ${CYAN}Enter your deployed SaysGM contract address:${NC} ) " CONTRACT_ADDRESS
  TARGET_FILE="infernet-container-starter/projects/hello-world/contracts/script/CallContract.s.sol"
  if [[ ! -f "$TARGET_FILE" ]]; then
    echo -e "${RED}File not found: $TARGET_FILE${NC}"
    exit 1
  fi
  sed -i "s|address saysGm = .*|address saysGm = ${CONTRACT_ADDRESS};|" "$TARGET_FILE"
  echo -e "${YELLOW}Updated CallContract.s.sol with contract address.${NC}"
  cd infernet-container-starter
  project=hello-world make call-contract

else
  echo -e "${YELLOW}Exiting.${NC}"
  exit 0
fi
