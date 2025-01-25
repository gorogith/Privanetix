#!/bin/bash

# Warna untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Fungsi untuk mengecek dan menambahkan user ke grup docker
setup_docker_permissions() {
    if ! groups | grep -q docker; then
        echo -e "\n${YELLOW}Adding user to docker group...${NC}"
        usermod -aG docker $USER
        echo -e "${GREEN}Docker group permissions added.${NC}"
    fi
}

# Logo dan Banner
show_banner() {
    clear
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════╗"
    echo "║         Privasea Node Manager             ║"
    echo "║              Version 1.0.0                ║"
    echo "╚═══════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Fungsi untuk setup lengkap node
setup_node() {
    clear
    echo -e "\n${YELLOW}[Complete Node Setup]${NC}"
    
    # 1. Check System
    echo -e "\n${BLUE}[1/4] Checking System Requirements...${NC}"
    CPU_CORES=$(nproc)
    RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
    STORAGE_GB=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    
    echo -e "System Specifications:"
    echo -e "- CPU Cores: ${GREEN}$CPU_CORES cores${NC}"
    echo -e "- RAM: ${GREEN}$RAM_GB GB${NC}"
    echo -e "- Available Storage: ${GREEN}$STORAGE_GB GB${NC}"
    
    # 2. Install Docker
    echo -e "\n${BLUE}[2/4] Installing Docker...${NC}"
    if ! command -v docker &> /dev/null; then
        {
            sudo apt update
            sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
            sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
            sudo apt update
            sudo apt install -y docker-ce
            sudo systemctl start docker
            sudo systemctl enable docker
            setup_docker_permissions
        } &> /dev/null
        echo -e "${GREEN}Docker installed successfully!${NC}"
    else
        echo -e "${GREEN}Docker already installed!${NC}"
    fi
    
    # 3. Pull Docker Image
    echo -e "\n${BLUE}[3/4] Pulling Privanetix Docker Image...${NC}"
    docker pull privasea/acceleration-node-beta:latest
    
    # 4. Setup Node Configuration
    echo -e "\n${BLUE}[4/4] Setting up Node Configuration...${NC}"
    mkdir -p ~/privasea/config
    
    echo -e "\n${BLUE}Please set a password for your keystore:${NC}"
    read -s -p "Enter password: " KEYSTORE_PASSWORD
    echo
    read -s -p "Confirm password: " KEYSTORE_PASSWORD_CONFIRM
    echo
    
    if [ "$KEYSTORE_PASSWORD" != "$KEYSTORE_PASSWORD_CONFIRM" ]; then
        echo -e "${RED}Passwords do not match!${NC}"
        read -p "Press Enter to return to menu..."
        return 1
    fi
    
    echo "$KEYSTORE_PASSWORD" > ~/privasea/config/.password
    chmod 600 ~/privasea/config/.password
    
    # Buat keystore
    docker run -it -v "$HOME/privasea/config:/app/config" \
    privasea/acceleration-node-beta:latest ./node-calc new_keystore
    
    # Rename keystore file
    echo -e "\n${BLUE}Renaming keystore file...${NC}"
    cd ~/privasea/config
    
    # Ambil file keystore terbaru
    LATEST_KEYSTORE=$(ls -t UTC-* | head -n 1)
    if [ -n "$LATEST_KEYSTORE" ]; then
        # Hapus wallet_keystore lama jika ada
        rm -f wallet_keystore
        
        # Rename file terbaru ke wallet_keystore
        mv "$LATEST_KEYSTORE" wallet_keystore
        echo -e "${GREEN}Latest keystore file renamed to wallet_keystore${NC}"
        
        # Hapus file keystore lama
        echo -e "\n${YELLOW}Cleaning up old keystore files...${NC}"
        ls UTC-* 2>/dev/null | while read -r file; do
            rm -f "$file"
            echo "Removed old keystore: $file"
        done
        
        echo -e "\n${GREEN}Current files in config directory:${NC}"
        ls -l
    else
        echo -e "${RED}No keystore file found!${NC}"
        return 1
    fi
    
    echo -e "\n${GREEN}Node setup completed successfully!${NC}"
    echo -e "${YELLOW}Your node address: ${NC}$(echo $LATEST_KEYSTORE | grep -o '[0-9a-f]\{40\}$')"
    read -p "Press Enter to return to menu..."
}

# Fungsi untuk start node
start_node() {
    clear
    echo -e "\n${YELLOW}[Start Node]${NC}"
    
    if [ ! -f "$HOME/privasea/config/.password" ]; then
        echo -e "${RED}Node not configured! Please run setup first.${NC}"
        read -p "Press Enter to return to menu..."
        return 1
    fi
    
    KEYSTORE_PASSWORD=$(cat ~/privasea/config/.password)
    
    echo -e "\nStarting Privanetix Node..."
    CONTAINER_ID=$(docker run -d -v "$HOME/privasea/config:/app/config" \
    -e KEYSTORE_PASSWORD="$KEYSTORE_PASSWORD" \
    privasea/acceleration-node-beta:latest)
    
    echo -e "${GREEN}Node started with container ID: $CONTAINER_ID${NC}"
    read -p "Press Enter to return to menu..."
}

# Fungsi untuk check status
check_status() {
    clear
    echo -e "\n${YELLOW}[Node Status]${NC}"
    
    # Cek semua container yang terkait dengan image privasea
    echo -e "\n${BLUE}Checking all Privanetix containers...${NC}"
    
    # Tampilkan semua container (running dan stopped)
    echo -e "\n${YELLOW}All Containers:${NC}"
    docker ps -a --filter "ancestor=privasea/acceleration-node-beta:latest"
    
    # Cek container yang sedang running
    CONTAINER_ID=$(docker ps -q --filter "ancestor=privasea/acceleration-node-beta:latest")
    if [ -n "$CONTAINER_ID" ]; then
        echo -e "\n${GREEN}Node is running!${NC}"
        echo -e "Container ID: $CONTAINER_ID"
        
        # Tampilkan detail container
        echo -e "\n${YELLOW}Container Details:${NC}"
        docker inspect "$CONTAINER_ID" | grep -E "Status|StartedAt|Error"
        
        echo -e "\n${YELLOW}Node logs (press Ctrl+C to exit):${NC}"
        docker logs -f "$CONTAINER_ID"
    else
        echo -e "\n${RED}Node is not running!${NC}"
        
        # Cek container yang stopped
        STOPPED_CONTAINER=$(docker ps -aq --filter "ancestor=privasea/acceleration-node-beta:latest" --filter "status=exited")
        if [ -n "$STOPPED_CONTAINER" ]; then
            echo -e "\n${YELLOW}Found stopped container. Last logs:${NC}"
            docker logs "$STOPPED_CONTAINER"
            echo -e "\n${YELLOW}Container exit reason:${NC}"
            docker inspect "$STOPPED_CONTAINER" | grep -E "Status|Error"
        fi
    fi
    
    read -p "Press Enter to return to menu..."
}

# Fungsi untuk stop node
stop_node() {
    clear
    echo -e "\n${YELLOW}[Stop Node]${NC}"
    
    CONTAINER_ID=$(docker ps -q --filter "ancestor=privasea/acceleration-node-beta:latest")
    if [ -n "$CONTAINER_ID" ]; then
        docker stop "$CONTAINER_ID"
        echo -e "${GREEN}Node stopped successfully!${NC}"
    else
        echo -e "${RED}No running node found!${NC}"
    fi
    
    read -p "Press Enter to return to menu..."
}

# Main menu
show_menu() {
    while true; do
        show_banner
        echo -e "${YELLOW}Main Menu:${NC}"
        echo -e "${BLUE}1.${NC} Setup Node (Install & Configure)"
        echo -e "${BLUE}2.${NC} Start Node"
        echo -e "${BLUE}3.${NC} Check Node Status"
        echo -e "${BLUE}4.${NC} Stop Node"
        echo -e "${RED}5.${NC} Exit"
        echo
        read -p "Select an option [1-5]: " choice
        
        case $choice in
            1) setup_node ;;
            2) start_node ;;
            3) check_status ;;
            4) stop_node ;;
            5) clear; exit 0 ;;
            *) echo -e "${RED}Invalid option!${NC}"; sleep 1 ;;
        esac
    done
}

# Start menu
show_menu
