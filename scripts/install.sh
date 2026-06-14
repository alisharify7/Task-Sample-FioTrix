#!/bin/bash

set -euo pipefail

print_banner() {
    echo "==========================================================="
    echo " FastAPI Deployment Script - For Fiotrix Job Interview Task"
    echo "==========================================================="
}

error_exit() {
    echo "ERROR: $1" >&2
    exit 1
}

# Check if a command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Ask a yes/no question, returns 0 for yes, 1 for no
ask_yes_no() {
    local prompt="$1"
    local answer
    while true; do
        read -r -p "$prompt (y/n): " answer
        case "$answer" in
            [Yy]* ) return 0 ;;
            [Nn]* ) return 1 ;;
            * ) echo "Please answer yes or no." ;;
        esac
    done
}

# Detect Linux distribution (basic)
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

# ------------------------------------------------------------
# Docker / Docker Compose functions
# ------------------------------------------------------------
install_docker() {
    local os="$1"
    echo "Installing Docker and Docker Compose..."

    case "$os" in
        ubuntu|debian)
            sudo apt-get update
            sudo apt-get install -y docker.io docker-compose-v2 || {
                # Fallback if docker-compose-v2 package not available
                sudo apt-get install -y docker.io
                sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
                sudo chmod +x /usr/local/bin/docker-compose
            }
            ;;
        fedora|centos|rhel)
            sudo dnf install -y docker docker-compose || sudo yum install -y docker docker-compose
            sudo systemctl start docker
            sudo systemctl enable docker
            ;;
        *)
            echo "Unsupported OS. Please install Docker and Docker Compose manually."
            echo "Visit https://docs.docker.com/engine/install/ and https://docs.docker.com/compose/install/"
            return 1
            ;;
    esac

    # Add current user to docker group to avoid needing sudo
    sudo usermod -aG docker "$USER"
    echo "Docker installed. You may need to log out and back in for group changes to take effect."
}

run_docker_compose() {
    echo "Running docker compose up..."
    docker compose up -d
    echo "all container's are up and running "
}

setup_docker_compose() {
    echo "Checking Docker and Docker Compose..."

    local need_install=0
    if ! command_exists docker; then
        echo "Docker is not installed."
        need_install=1
    fi

    # Check for Docker Compose (both v2 and legacy)
    if ! docker compose version &>/dev/null && ! command_exists docker-compose; then
        echo "Docker Compose is not installed."
        need_install=1
    fi

    if [ $need_install -eq 1 ]; then
        if ask_yes_no "Would you like to install Docker and Docker Compose now?"; then
            install_docker "$(detect_os)" || error_exit "Installation failed."
        else
            error_exit "Docker and Docker Compose are required. Exiting."
        fi
    else
        echo "Docker and Docker Compose are already installed."
    fi

    run_docker_compose
}

# ------------------------------------------------------------
# PostgreSQL / Systemd functions
# ------------------------------------------------------------
install_postgres() {
    local os="$1"
    echo "Installing PostgreSQL..."

    case "$os" in
        ubuntu|debian)
            sudo apt-get update
            sudo apt-get install -y postgresql postgresql-contrib
            ;;
        fedora|centos|rhel)
            sudo dnf install -y postgresql-server postgresql-contrib || sudo yum install -y postgresql-server postgresql-contrib
            sudo postgresql-setup --initdb
            sudo systemctl start postgresql
            sudo systemctl enable postgresql
            ;;
        *)
            echo "Unsupported OS. Please install PostgreSQL manually."
            return 1
            ;;
    esac

    echo "PostgreSQL installed successfully."
}

create_db_user() {
    local username="$1"
    local password="$2"

    echo "Creating PostgreSQL user '$username'..."
    # Using psql with proper escaping for the password
    sudo -u postgres psql -c "CREATE USER \"$username\" WITH PASSWORD '$(echo "$password" | sed "s/'/''/g")';" \
        || error_exit "Failed to create user '$username'."
    echo "User '$username' created."
}

create_db() {
    # Extract DATABASE_NAME from .env file
    if [ ! -f .env ]; then
        error_exit ".env file not found in current directory."
    fi

    local db_name
    db_name=$(grep -E '^DATABASE_NAME=' .env | cut -d '=' -f2-)
    if [ -z "$db_name" ]; then
        error_exit "DATABASE_NAME not found in .env file."
    fi

    echo "Creating database '$db_name'..."
    sudo -u postgres createdb -O "$1" "$db_name" || {
        # Fallback using psql
        sudo -u postgres psql -c "CREATE DATABASE \"$db_name\" OWNER \"$1\";" || error_exit "Failed to create database '$db_name'."
    }
    echo "Database '$db_name' created with owner '$1'."
}

copy_and_enable_service() {
    local service_file="./systemd/task.service"
    if [ ! -f "$service_file" ]; then
        error_exit "Service file '$service_file' not found."
    fi

    echo "Copying $service_file to /etc/systemd/system/task.service..."
    sudo cp "$service_file" /etc/systemd/system/task.service

    echo "Reloading systemd and starting task.service..."
    sudo systemctl daemon-reload
    sudo systemctl enable task.service
    sudo systemctl start task.service

    echo "Service task.service is now running."
}

setup_systemd() {
    echo "Checking PostgreSQL..."

    if ! command_exists psql; then
        echo "PostgreSQL is not installed."
        if ask_yes_no "Would you like to install PostgreSQL now?"; then
            install_postgres "$(detect_os)" || error_exit "Installation failed."
        else
            error_exit "PostgreSQL is required. Exiting."
        fi
    else
        echo "PostgreSQL is already installed."
    fi

    # Ask for database credentials
    echo
    echo "Please provide the PostgreSQL user credentials for your application."
    read -r -p "Username: " db_username
    read -r -s -p "Password: " db_password
    echo  # newline after hidden input

    create_db_user "$db_username" "$db_password"
    create_db "$db_username"
    copy_and_enable_service
}

# ------------------------------------------------------------
# Main script
# ------------------------------------------------------------
main() {
    print_banner
    if ask_yes_no "do you create the .env file in the root of project?"; then
        echo "Good. let go to next steep ..."
    else
        error_exit ".env is required please create file using cp env.sample .env and fill up required fileds."
    fi
    echo "Choose deployment method:"
    echo "1) Docker Compose"
    echo "2) Systemd Service"
    read -r -p "Enter choice (1/2): " choice

    case "$choice" in
        1) setup_docker_compose ;;
        2) setup_systemd ;;
        *) error_exit "Invalid option. Run the script again and choose 1 or 2." ;;
    esac

    echo
    echo "Deployment setup complete!"
}

main "$@"
