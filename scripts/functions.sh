#!/bin/bash

# Source configuration file
source ./config.env

# Function to create typing effect
typing_print() {
    local text="$1"
    local delay=0.0001
    
    # Print each character with delay
    for ((i=0; i<${#text}; i++)); do
        echo -n "${text:$i:1}"
        sleep "$delay"
    done
    echo ""
}

# Intro message with logo
print_intro() {
    clear
    echo -e "\e[36m"
    typing_print "=============================================="
    typing_print "                                              "
    typing_print "      ██╗   ██╗██████╗ ███╗   ███╗███████╗    "
    typing_print "      ██║   ██║██╔══██╗████╗ ████║██╔════╝    "
    typing_print "      ██║   ██║██║  ██║██╔████╔██║███████╗    "
    typing_print "      ██║   ██║██║  ██║██║╚██╔╝██║╚════██║    "
    typing_print "      ╚██████╔╝██████╔╝██║ ╚═╝ ██║███████║    "
    typing_print "      ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝     "
    typing_print "                                              "
    typing_print "=============================================="
    typing_print "                                              "
    typing_print "Welcome to UDMS (Ultimate Docker Media Server)"
    typing_print "                                              "
    typing_print "=============================================="
    echo -e "\e[0m"
}

# Error handling
error_exit() {
    message="$1"
    echo -e "$(printf "\e[31m$message\e[0m")" | tee -a "$LOGS/error.log" 1>&2
    exit 255
}

# Install Docker and Docker Compose
install_docker() {
    echo -e "\e[36m"
    typing_print "================================================"
    typing_print "  Step 1: Installing Docker and Docker Compose  "
    typing_print "================================================"
    typing_print "                      ##        .               "
    typing_print "                ## ## ##       ==               "
    typing_print "             ## ## ## ##      ===               "
    typing_print "         /""""""""""""""""\___/ ===             "
    typing_print "    ~~~ {~~ ~~~~ ~~~ ~~~~ ~~ ~ /  ===- ~~~      "
    typing_print "         \______ o          __/                 "
    typing_print "           \    \        __/                    "
    typing_print "            \____\______/                       "
    typing_print "================================================"
    echo -e "\e[0m"

    # Check if curl is installed, if not, install it
    if ! command -v curl &> /dev/null; then
        echo "curl is not installed. Installing curl..."
        if command -v dnf &> /dev/null; then
            sudo dnf install -y curl || error_exit "Failed to install curl."
        elif command -v apt-get &> /dev/null; then
            sudo apt-get install -y curl || error_exit "Failed to install curl."
        else
            error_exit "No supported package manager found (dnf or apt-get). Please install curl manually."
        fi
        typing_print "curl installed successfully."
    fi

    # Check if docker is installed, if not, install it
    if ! command -v docker &> /dev/null; then
        curl -fsSL https://get.docker.com -o install-docker.sh || error_exit "Failed to download Docker installation script."
        sudo sh install-docker.sh || error_exit "Docker installation failed."
        typing_print "Docker and Docker Compose installed."
    else
        typing_print "Docker is already installed."
    fi

    # Enable Docker to start on boot
    sudo systemctl enable docker || error_exit "Failed to enable Docker on boot."
    typing_print "Docker enabled to start on boot."
}

# Install Cockpit and enable it
install_cockpit() {
    echo -e "\e[36m"
    typing_print "================================================"
    typing_print "  Step 2: Installing Cockpit                    "
    typing_print "================================================"
    echo -e "\e[0m"

    if systemctl list-unit-files cockpit.socket &> /dev/null; then
        typing_print "Cockpit is already installed."
    else
        typing_print "Installing Cockpit..."
        if command -v dnf &> /dev/null; then
            sudo dnf install -y cockpit cockpit-files || error_exit "Failed to install Cockpit."
        elif command -v apt-get &> /dev/null; then
            sudo apt-get install -y cockpit || error_exit "Failed to install Cockpit."
        else
            error_exit "No supported package manager found (dnf or apt-get). Please install Cockpit manually."
        fi
        typing_print "Cockpit installed."
    fi

    # Enable and start cockpit socket
    sudo systemctl enable --now cockpit.socket || error_exit "Failed to enable Cockpit."
    typing_print "Cockpit enabled and running."

    # Open firewall port (handle both firewalld and ufw)
    if command -v firewall-cmd &> /dev/null; then
        sudo firewall-cmd --add-service=cockpit --permanent 2>/dev/null
        sudo firewall-cmd --reload
        typing_print "Firewall rule added for Cockpit (firewalld)."
    elif command -v ufw &> /dev/null; then
        sudo ufw allow 9090/tcp
        typing_print "Firewall rule added for Cockpit (ufw)."
    else
        typing_print "No firewall detected — skipping firewall rule. Cockpit port 9090 should be accessible."
    fi

    typing_print "Cockpit is available at http://$(hostname -I | awk '{print $1}'):9090"
}

# Verify Docker installation
verify_docker() {
    typing_print "Verifying Docker installation..."
    sudo docker --version || error_exit "Docker is not installed correctly."
    sudo docker compose version || error_exit "Docker Compose is not installed correctly."
    typing_print "Docker installation verified."
}

# Create necessary directories
create_directories() {
    typing_print "Creating necessary directories..."
    mkdir -p "$APPDATA" "$COMPOSE" "$LOGS" "$SCRIPTS" "$SECRETS" "$SHARED"
    typing_print "Directories created:"
    typing_print "  - $APPDATA"
    typing_print "  - $COMPOSE"
    typing_print "  - $LOGS"
    typing_print "  - $SCRIPTS"
    typing_print "  - $SECRETS"
    typing_print "  - $SHARED"

    # Create or update .env via the Python env manager
    if [[ -f "$ENV_FILE" ]]; then
        python3 ./update-env.py
    else
        python3 ./update-env.py --init
    fi
}

# Set permissions
set_permissions() {
    typing_print "Setting permissions for secrets folder and .env file..."
    sudo chown root:root "$SECRETS" "$ENV_FILE"
    sudo chmod 600 "$SECRETS" "$ENV_FILE"
    typing_print "Permissions set for secrets folder, .env file and config file."

    typing_print "Setting permissions for Docker root folder..."
    if command -v dnf &> /dev/null; then
        sudo dnf install -y acl || error_exit "Failed to install ACL."
    elif command -v apt-get &> /dev/null; then
        sudo apt-get install -y acl || error_exit "Failed to install ACL."
    else
        error_exit "No supported package manager found (dnf or apt-get). Please install acl manually."
    fi
    sudo chmod 775 "$DOCKER_ROOT"
    sudo setfacl -Rdm u:"$USER":rwx "$DOCKER_ROOT"
    sudo setfacl -Rm u:"$USER":rwx "$DOCKER_ROOT"
    sudo setfacl -Rdm g:docker:rwx "$DOCKER_ROOT"
    sudo setfacl -Rm g:docker:rwx "$DOCKER_ROOT"
    typing_print "Permissions set for Docker root folder: $DOCKER_ROOT"

    typing_print "Setting permissions for Jellyfin directory..."
    mkdir -p "$DOCKER_ROOT/appdata/jellyfin"
    sudo chown -R "$USER":"$USER" "$DOCKER_ROOT/appdata/jellyfin"
    typing_print "Permissions set for Jellyfin directory: $DOCKER_ROOT/appdata/jellyfin"
}

# Create Docker Compose files
create_compose_files() {
    typing_print "Creating runtime docker-compose file..."
    cp "$SOURCE_COMPOSE" "$COMPOSE_FILE"
    typing_print "Runtime compose file created: $COMPOSE_FILE"

    typing_print "Syncing component compose files..."
    cp "$COMPOSE_FILES"/*.yml "$COMPOSE/"
    typing_print "Component compose files synced to: $COMPOSE"
}

# Start Docker containers
start_containers() {
    typing_print "Starting the containers..."
    sudo docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d --remove-orphans || error_exit "Failed to start containers."
}

# Seed a runtime configuration file on first setup without overwriting edits.
seed_file() {
    local source="$1"
    local destination="$2"

    mkdir -p "$(dirname "$destination")"
    if [[ -e "$destination" ]]; then
        typing_print "Preserved existing configuration: $destination"
        return 0
    fi

    cp "$source" "$destination" || error_exit "Failed to seed configuration: $destination"
    typing_print "Seeded configuration: $destination"
}

# Seed Homepage configuration files on first setup.
create_homepage_config() {
    typing_print "Seeding Homepage configuration files..."
    local file
    for file in bookmarks.yaml services.yaml settings.yaml widgets.yaml; do
        seed_file "$HOMEPAGE_CONFIG/$file" "$APPDATA/homepage/$file"
    done
}

# Seed qBittorrent configuration on first setup.
create_qbittorrent_config() {
    typing_print "Seeding qBittorrent configuration..."
    seed_file "$QBITTORRENT_CONFIG" "$QBITTORRENT_CONF"
}

# Seed Deluge configuration on first setup.
create_deluge_config() {
    typing_print "Seeding Deluge configuration..."
    seed_file "$DELUGE_CONFIG1" "$DELUGE_CONF1"
    seed_file "$DELUGE_CONFIG2" "$DELUGE_CONF2"
}

# Add Docker aliases to bash configuration without replacing existing files.
add_docker_aliases() {
    typing_print "Seeding Docker aliases..."
    seed_file "./bash_aliases.env.example" "$BASH_ENV"
    seed_file "./bash_aliases" "$BASH_CONFIG"

    if ! grep -q "source $BASH_CONFIG" "$BASHRC"; then
        echo "[[ -f $BASH_ENV ]] && source $BASH_ENV" >> "$BASHRC"
        echo "[[ -f $BASH_CONFIG ]] && source $BASH_CONFIG" >> "$BASHRC"
        typing_print "Added alias sources to $BASHRC."
    else
        typing_print "$BASHRC already sources $BASH_CONFIG."
    fi
}

# Seed Decypharr configuration on first setup.
create_decypharr_config() {
    typing_print "Seeding Decypharr configuration..."
    seed_file "$DECYPHARR_CONFIG" "$APPDATA/decypharr/config.json"
}

# Seed the docker-gc exclusion file on first setup.
create_docker_gc_exclude() {
    typing_print "Seeding docker-gc exclusion file..."
    seed_file "$DOCKERGC_EXCLUDE" "$APPDATA/docker-gc/docker-gc-exclude"
}

print_setup_complete() {
    echo -e "\e[32m"
    typing_print "██████╗  ██████╗ ███╗   ██╗███████╗"
    typing_print "██╔══██╗██╔═══██╗████╗  ██║██╔════╝"
    typing_print "██║  ██║██║   ██║██╔██╗ ██║█████╗  "
    typing_print "██║  ██║██║   ██║██║╚██╗██║██╔══╝  "
    typing_print "██████╔╝╚██████╔╝██║ ╚████║███████╗"
    typing_print "╚═════╝  ╚═════╝ ╚═╝  ╚═══╝╚══════╝"
    typing_print "Setup complete."
    echo -e "\e[0m"
}
