# Ritual Infernet Node Manager

This is a one-click interactive Bash script to install and manage a Ritual Infernet Node. It supports:

- One-click setup with Docker, Foundry, and dependencies
- Automatic config file generation
- Contract deployment via Forge
- Smart contract address update + sayGM call
- Clean output, robust checks, and full automation

---

## Requirements

- Ubuntu 20.04 / 22.04
- 2+ vCPU & 4GB+ RAM
- Open ports: `3001`, `4000`, `6379`, `8545`
- Alchemy BASE RPC URL
- Wallet private key with ETH on Base Mainnet

---

## Installation & Usage

1. Install Dependencies:
    ```bash
    sudo apt update && sudo apt install git curl -y
    ```

2. Run the script:
    ```bash
    bash <(curl -s https://raw.githubusercontent.com/CodeDialect/ritual-infernet/main/ritual_node_manager.sh)
    ```

---

## Script Options

After launching, you will be prompted to select:

```
1) Install Ritual Infernet Node
2) Update Contract Address and Call sayGM
3) Exit
```

---

### Option 1: Install Node

- Installs dependencies
- Installs Docker (via [CodeDialect's script](https://github.com/CodeDialect/aztec-squencer))
- Clones Ritual's Infernet Starter repo
- Generates `config.json`
- Starts Docker containers
- Installs Foundry
- Deploys your `SaysGM` contract
- Asks if you want to automatically update `CallContract.s.sol` and run `sayGM()`

> The contract address will be displayed after deployment.

---

### Option 2: Update Contract Address + Call sayGM

If you already deployed a contract and just want to run the `sayGM()` call with a new address:

- Prompts for your contract address
- Replaces it in `CallContract.s.sol`
- Calls it via Foundry script

---

## Files & Folders

| Path                                                  | Purpose                             |
|-------------------------------------------------------|-------------------------------------|
| `projects/hello-world/container/config.json`          | Docker container config             |
| `deploy/config.json`                                  | Node config for main container      |
| `projects/hello-world/contracts/script/CallContract.s.sol` | Sends GM call to contract    |
| `projects/hello-world/contracts/script/Deploy.s.sol`  | Deploys new SaysGM contract         |

---

## Docker Cleanup (optional)

If you want to fully reset Docker environment before reinstall:

```bash
docker rm -f $(docker ps -aq)
docker volume rm $(docker volume ls -q)
docker rmi -f $(docker images -q)
docker system prune -af
```

---

## FAQ

**Q: I get `foundryup: Error: 'anvil' is currently running`**

A: The script now stops all containers (`docker-compose down`) before installing Foundry to avoid conflicts.

**Q: It says `make: Nothing to be done for 'deploy'`**

A: We now directly use `forge script` instead of `make` to avoid this cache issue.

**Q: It says `forge: command not found `**

A: write `bash` then try running the command again.
---

## Credits

- [Ritual Infernet GitHub](https://github.com/ritual-net/infernet-container-starter)
- [Foundry (by Paradigm)](https://book.getfoundry.sh/)
- Script maintained by **Codedialect**
