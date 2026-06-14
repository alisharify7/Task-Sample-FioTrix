#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Deployment script for FastAPI app (Docker Compose vs. systemd with PostgreSQL)
# -----------------------------------------------------------------------------

set -e  # exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\'\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper: print colored messages
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# -----------------------------------------------------------------------------
# Docker Compose section
# -----------------------------------------------------------------------------
check_docker() {
    if command -v docker &> /dev/null; then
        info "Docker found."
        return 0
    else
        warn "Docker is not installed."
        return 1
    fi
}

check_docker_compose() {
    if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
        info "Docker Compose found."
        return 0
    else
        warn "Docker Compose is not installed."
        return 1
    fi
}

ask_install_docker() {
    echo -e "${YELLOW}Docker is required but not installed.${NC}"
    read -p "Do you want to install Docker now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Detect OS and provide installation command (supports Debian/Ubuntu)
        if [[ -f /etc/debian_version ]]; then
            info "Installing Docker on Debian/Ubuntu..."
            sudo apt update
            sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            sudo apt update
            sudo apt install -y docker-ce docker-ce-cli containerd.io
            sudo systemctl enable docker
            sudo systemctl start docker
            sudo usermod -aG docker $USER
            info "Docker installed. Please log out and back in for group changes to take effect."
        else
            error "Automatic installation only supported on Debian/Ubuntu. Please install Docker manually: https://docs.docker.com/engine/install/"
            exit 1
        fi
        # Also install docker-compose plugin
        sudo apt install -y docker-compose-plugin || true
    else
        error "Docker is required. Exiting."
        exit 1
    fi
}

run_docker_compose() {
    # According to spec: just print "running docker compose up"
    # but we also actually run it (optional). For exact spec:
    echo "running docker compose up"
    # Uncomment next line to actually start the containers:
    # docker compose up -d
}

deploy_docker_compose() {
    info "Deploying with Docker Compose..."
    if ! check_docker; then
        ask_install_docker
    fi
    if ! check_docker_compose; then
        warn "Docker Compose missing, attempting to install plugin..."
        sudo apt update && sudo apt install -y docker-compose-plugin || {
            error "Could not install Docker Compose plugin. Please install manually."
            exit 1
        }
    fi
    run_docker_compose
}

# -----------------------------------------------------------------------------
# Systemd with PostgreSQL section
# -----------------------------------------------------------------------------
check_postgres_installed() {
    if command -v psql &> /dev/null; then
        info "PostgreSQL client found."
        return 0
    else
        warn "PostgreSQL is not installed."
        return 1
    fi
}

ask_install_postgres() {
    echo -e "${YELLOW}PostgreSQL is required but not installed.${NC}"
    read -p "Do you want to install PostgreSQL now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [[ -f /etc/debian_version ]]; then
            info "Installing PostgreSQL on Debian/Ubuntu..."
            sudo apt update
            sudo apt install -y postgresql postgresql-contrib
            sudo systemctl enable postgresql
            sudo systemctl start postgresql
            info "PostgreSQL installed and started."
        else
            error "Automatic installation only supported on Debian/Ubuntu. Please install PostgreSQL manually."
            exit 1
        fi
    else
        error "PostgreSQL is required. Exiting."
        exit 1
    fi
}

create_postgres_user() {
    local pg_user pg_pass
    read -p "Enter PostgreSQL username (new or existing): " pg_user
    read -s -p "Enter password for user '$pg_user': " pg_pass
    echo
    # Check if user already exists
    if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$pg_user'" | grep -q 1; then
        info "User '$pg_user' already exists. Updating password..."
        sudo -u postgres psql -c "ALTER USER \"$pg_user\" WITH PASSWORD '$pg_pass';"
    else
        info "Creating PostgreSQL user '$pg_user'..."
        sudo -u postgres psql -c "CREATE USER \"$pg_user\" WITH PASSWORD '$pg_pass';"
    fi
    # Grant necessary privileges (e.g., CREATEDB for future migrations)
    sudo -u postgres psql -c "ALTER USER \"$pg_user\" WITH CREATEDB;"
    info "User '$pg_user' created/updated with CREATEDB privilege."
}

extract_db_name_from_env() {
    local env_file=".env"
    if [[ ! -f "$env_file" ]]; then
        error ".env file not found in current directory. Please ensure DATABASE_NAME is defined."
        exit 1
    fi
    # Extract DATABASE_NAME, ignore comments and trim spaces
    db_name=$(grep -E '^DATABASE_NAME=' "$env_file" | cut -d '=' -f2- | xargs)
    if [[ -z "$db_name" ]]; then
        error "DATABASE_NAME not defined in .env file."
        exit 1
    fi
    echo "$db_name"
}

create_database() {
    local db_name=$1
    local pg_user=$2
    info "Creating database '$db_name'..."
    # Check if database exists
    if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$db_name"; then
        warn "Database '$db_name' already exists. Skipping creation."
    else
        sudo -u postgres psql -c "CREATE DATABASE \"$db_name\" OWNER \"$pg_user\";"
        info "Database '$db_name' created with owner '$pg_user'."
    fi
}

copy_systemd_service() {
    local service_file="./systemd/task.service"
    if [[ ! -f "$service_file" ]]; then
        error "Service file $service_file not found. Please ensure it exists."
        exit 1
    fi
    info "Copying service file to /etc/systemd/system/task.service"
    sudo cp "$service_file" /etc/systemd/system/
    sudo chmod 644 /etc/systemd/system/task.service
}

reload_and_start_systemd() {
    info "Reloading systemd daemon..."
    sudo systemctl daemon-reload
    info "Enabling task.service to start on boot..."
    sudo systemctl enable task.service
    info "Starting task.service..."
    sudo systemctl start task.service
    info "Service status:"
    sudo systemctl status task.service --no-pager || {
        warn "Service failed to start. Check logs with: journalctl -u task.service"
    }
}

deploy_systemd() {
    info "Deploying with systemd and PostgreSQL..."
    if ! check_postgres_installed; then
        ask_install_postgres
    fi
    create_postgres_user
    # Capture the username for DB creation
    # (we need the username that was just set; we can prompt again or store it)
    # Simpler: reuse the variable from create_postgres_user, but that function is interactive.
    # We'll call create_postgres_user and then ask the user to provide the same username again,
    # or we can refactor to return the username. For simplicity, we prompt again for the username
    # because the function already printed it. Alternatively, we can read the username from a temp file.
    # Let's just ask the user for the username again.
    read -p "Please enter the PostgreSQL username you just created (for database owner): " pg_user
    db_name=$(extract_db_name_from_env)
    create_database "$db_name" "$pg_user"
    copy_systemd_service
    reload_and_start_systemd
}

# -----------------------------------------------------------------------------
# Main menu
# -----------------------------------------------------------------------------
main() {
    echo "========================================"
    echo "  FastAPI App Deployment"
    echo "========================================"
    echo "Choose deployment method:"
    echo "  1) Docker Compose"
    echo "  2) System service (systemd + PostgreSQL)"
    read -p "Enter your choice [1 or 2]: " choice

    case "$choice" in
        1)
            deploy_docker_compose
            ;;
        2)
            deploy_systemd
            ;;
        *)
            error "Invalid choice. Please run the script again and select 1 or 2."
            exit 1
            ;;
    esac
}

# Run the main function
main
