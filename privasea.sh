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
    
    # Setelah setup keystore berhasil
    NODE_ADDRESS=$(docker run --rm -v "$HOME/privasea/config:/app/config" \
        privasea/acceleration-node-beta:latest ./node-calc show_wallet)
    
    echo -e "\n${GREEN}Node setup completed successfully!${NC}"
    echo -e "\n${YELLOW}IMPORTANT: Before starting the node, please:${NC}"
    echo -e "1. Go to ${BLUE}https://deepsea-beta.privasea.ai/privanetixNode${NC}"
    echo -e "2. Register your node with this address:"
    echo -e "${GREEN}$NODE_ADDRESS${NC}"
    echo -e "3. Wait for confirmation before starting the node"
    echo -e "\nPress Enter to return to menu..."
    read
}

# Fungsi untuk start node
start_node() {
    clear
    echo -e "\n${YELLOW}[Start Node]${NC}"
    
    # Tambahkan konfirmasi registrasi
    echo -e "${YELLOW}Have you registered your node at https://deepsea-beta.privasea.ai/privanetixNode?${NC}"
    read -p "Enter [y/n]: " REGISTERED
    if [[ ! "$REGISTERED" =~ ^[Yy]$ ]]; then
        echo -e "\n${RED}Please register your node first!${NC}"
        
        # Get node address from wallet file
        WALLET_FILE="$HOME/privasea/config/wallet_keystore"
        if [ -f "$WALLET_FILE" ]; then
            ADDRESS=$(grep -o '"address":"[0-9a-fA-F]\+"' "$WALLET_FILE" | cut -d'"' -f4)
            if [ -n "$ADDRESS" ]; then
                echo -e "Node Address: ${GREEN}0x$ADDRESS${NC}"
            else
                echo -e "${RED}Could not extract address from wallet file${NC}"
            fi
        fi
        
        echo -e "Register at: ${BLUE}https://deepsea-beta.privasea.ai/privanetixNode${NC}"
        read -p "Press Enter to return to menu..."
        return 1
    fi
    
    # Bersihkan semua container lama
    echo -e "\n${BLUE}Cleaning up old containers...${NC}"
    docker ps -aq --filter "ancestor=privasea/acceleration-node-beta:latest" | xargs -r docker rm -f
    
    # Cek dan setup password jika belum ada
    if [ ! -f "$HOME/privasea/config/.password" ]; then
        echo -e "${YELLOW}Password file not found. Creating new one...${NC}"
        echo -e "\n${BLUE}Please enter your keystore password:${NC}"
        read -s -p "Enter password: " KEYSTORE_PASSWORD
        echo
        echo "$KEYSTORE_PASSWORD" > "$HOME/privasea/config/.password"
        chmod 600 "$HOME/privasea/config/.password"
        echo -e "${GREEN}Password file created.${NC}"
    fi
    
    KEYSTORE_PASSWORD=$(cat ~/privasea/config/.password)
    
    echo -e "\nStarting Privanetix Node..."
    echo -e "${YELLOW}Using configuration:${NC}"
    echo -e "- Keystore: $(ls -l $HOME/privasea/config/wallet_keystore)"
    echo -e "- Password file: $(ls -l $HOME/privasea/config/.password)"
    
    # Jalankan container dengan parameter yang benar
    CONTAINER_ID=$(docker run -d \
        -v "$HOME/privasea/config:/app/config" \
        -e KEYSTORE_PASSWORD="$KEYSTORE_PASSWORD" \
        -e NODE_ENV="production" \
        --name "privanetix-node-$(date +%s)" \
        privasea/acceleration-node-beta:latest)
    
    echo -e "\n${YELLOW}Waiting for node to start...${NC}"
    sleep 5
    
    # Cek status container
    if docker ps | grep -q "$CONTAINER_ID"; then
        echo -e "${GREEN}Node started successfully with container ID: $CONTAINER_ID${NC}"
        echo -e "\n${YELLOW}Initial logs:${NC}"
        docker logs "$CONTAINER_ID"
    else
        echo -e "${RED}Failed to start node. Checking logs:${NC}"
        docker logs "$CONTAINER_ID"
        echo -e "\n${RED}Container exit reason:${NC}"
        docker inspect "$CONTAINER_ID" --format='{{.State.Error}}'
        
        # Tampilkan isi direktori config untuk debugging
        echo -e "\n${YELLOW}Contents of config directory:${NC}"
        ls -la "$HOME/privasea/config/"
    fi
    
    read -p "Press Enter to return to menu..."
}

# Fungsi untuk check status
check_status() {
    clear
    echo -e "\n${YELLOW}[Node Status]${NC}"
    
    # Cek container yang sedang running
    CONTAINER_ID=$(docker ps -q --filter "name=privanetix-node")
    if [ -n "$CONTAINER_ID" ]; then
        echo -e "\n${GREEN}Node is running!${NC}"
        echo -e "Container ID: $CONTAINER_ID"
        
        # Tampilkan detail container
        echo -e "\n${YELLOW}Container Details:${NC}"
        docker inspect "$CONTAINER_ID" --format='Status: {{.State.Status}}
Started: {{.State.StartedAt}}
Error: {{.State.Error}}'
        
        echo -e "\n${YELLOW}Last 50 lines of logs:${NC}"
        docker logs --tail 50 "$CONTAINER_ID"
        
        echo -e "\n${YELLOW}Live logs (press Ctrl+C to exit):${NC}"
        docker logs -f "$CONTAINER_ID"
    else
        echo -e "\n${RED}Node is not running!${NC}"
        
        # Cek file konfigurasi
        echo -e "\n${YELLOW}Checking configuration:${NC}"
        if [ -f "$HOME/privasea/config/wallet_keystore" ]; then
            echo -e "${GREEN}✓ Wallet keystore found${NC}"
        else
            echo -e "${RED}✗ Wallet keystore missing${NC}"
        fi
        
        if [ -f "$HOME/privasea/config/.password" ]; then
            echo -e "${GREEN}✓ Password file found${NC}"
        else
            echo -e "${RED}✗ Password file missing${NC}"
        fi
        
        # Tampilkan logs terakhir jika ada
        LAST_CONTAINER=$(docker ps -a --filter "name=privanetix-node" --format "{{.ID}}" | head -n 1)
        if [ -n "$LAST_CONTAINER" ]; then
            echo -e "\n${YELLOW}Last container logs:${NC}"
            docker logs "$LAST_CONTAINER" 2>&1
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

# Fungsi untuk menampilkan node address
show_node_address() {
    clear
    echo -e "\n${YELLOW}[Node Address]${NC}"
    
    if [ ! -f "$HOME/privasea/config/wallet_keystore" ]; then
        echo -e "${RED}Wallet keystore not found! Please run setup first.${NC}"
        read -p "Press Enter to return to menu..."
        return 1
    fi
    
    echo -e "\n${YELLOW}Retrieving node address...${NC}"
    
    # Ekstrak address dari file wallet_keystore
    WALLET_FILE="$HOME/privasea/config/wallet_keystore"
    if [ -f "$WALLET_FILE" ]; then
        # Gunakan grep untuk mengekstrak address dari file
        ADDRESS=$(grep -o '"address":"[0-9a-fA-F]\+"' "$WALLET_FILE" | cut -d'"' -f4)
        if [ -n "$ADDRESS" ]; then
            echo -e "\nYour Node Address:"
            echo -e "${GREEN}0x$ADDRESS${NC}"
            echo -e "\nRegister at: ${BLUE}https://deepsea-beta.privasea.ai/privanetixNode${NC}"
        else
            echo -e "${RED}Could not extract address from wallet file${NC}"
            echo -e "\n${YELLOW}Wallet file content:${NC}"
            cat "$WALLET_FILE" | grep -o '"address":"[0-9a-fA-F]\+"' || echo "No address found"
        fi
    else
        echo -e "${RED}Wallet keystore file not found!${NC}"
    fi
    
    read -p "Press Enter to return to menu..."
}

# Main menu
show_menu() {
    while true; do
        show_banner
        echo -e "${YELLOW}Main Menu:${NC}"
        echo -e "${BLUE}1.${NC} Setup Node (Install & Configure)"
        echo -e "${BLUE}2.${NC} Show Node Address"
        echo -e "${BLUE}3.${NC} Start Node"
        echo -e "${BLUE}4.${NC} Check Node Status"
        echo -e "${BLUE}5.${NC} Stop Node"
        echo -e "${RED}6.${NC} Exit"
        echo
        read -p "Select an option [1-6]: " choice
        
        case $choice in
            1) setup_node ;;
            2) show_node_address ;;
            3) start_node ;;
            4) check_status ;;
            5) stop_node ;;
            6) clear; exit 0 ;;
            *) echo -e "${RED}Invalid option!${NC}"; sleep 1 ;;
        esac
    done
}

# Start menu
show_menu
