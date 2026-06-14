#!/bin/bash

set -euo pipefail

# ----------------------------- helpers -----------------------------
print_banner() {
    echo "==========================================================="
    echo " FastAPI Deployment Script - For Fiotrix Job Interview Task"
    echo "==========================================================="
}

error_exit() {
    echo "ERROR: $1" >&2
    exit 1
}

command_exists() {
    command -v "$1" &>/dev/null
}

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

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

# ------------------------- Docker -------------------------
install_docker() {
    local os="$1"
    echo "Installing Docker and Docker Compose..."
    case "$os" in
        ubuntu|debian)
            sudo apt-get update
            sudo apt-get install -y docker.io docker-compose-v2 || {
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
        *) echo "Unsupported OS. Please install Docker and Docker Compose manually." && return 1 ;;
    esac
    sudo usermod -aG docker "$USER"
    echo "Docker installed. You may need to log out and back in for group changes."
}

run_docker_compose() {
    echo "Running docker compose up..."
    docker compose up -d
    echo "All containers are up and running."
}

setup_docker_compose() {
    echo "Checking Docker and Docker Compose..."
    local need_install=0
    if ! command_exists docker; then
        echo "Docker is not installed."
        need_install=1
    fi
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

# ------------------------- PostgreSQL / systemd -------------------------
install_postgres() {
    local os="$1"
    echo "Installing PostgreSQL..."
    case "$os" in
        ubuntu|debian)
            sudo apt-get update && sudo apt-get install -y postgresql postgresql-contrib
            ;;
        fedora|centos|rhel)
            sudo dnf install -y postgresql-server postgresql-contrib || sudo yum install -y postgresql-server postgresql-contrib
            sudo postgresql-setup --initdb
            sudo systemctl start postgresql
            sudo systemctl enable postgresql
            ;;
        *) echo "Unsupported OS. Please install PostgreSQL manually." && return 1 ;;
    esac
    echo "PostgreSQL installed."
}

create_db_user() {
    local username="$1"
    local password="$2"
    echo "Creating PostgreSQL user '$username'..."
    sudo -u postgres psql -c "CREATE USER \"$username\" WITH PASSWORD '$(echo "$password" | sed "s/'/''/g")';" \
        || error_exit "Failed to create user '$username'."
    echo "User '$username' created."
}

create_db() {
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
        sudo -u postgres psql -c "CREATE DATABASE \"$db_name\" OWNER \"$1\";" || error_exit "Failed to create database."
    }
    echo "Database '$db_name' created with owner '$1'."
}

# Install uv using pip (as requested)
install_uv() {
    echo "Installing uv via pip..."
    if command_exists pip3; then
        pip3 install uv
    elif command_exists pip; then
        pip install uv
    else
        error_exit "pip is not installed. Please install pip first."
    fi
    # After pip install, uv should be available in PATH
}

setup_systemd() {
    # --- 1. Check prerequisites ---
    echo "Checking prerequisites..."
    if ! command_exists python3; then
        error_exit "Python3 is not installed. Please install Python 3.9+ and rerun."
    fi
    if ! command_exists uv; then
        echo "uv is not installed."
        if ask_yes_no "Would you like to install uv now?"; then
            install_uv
        else
            error_exit "uv is required. Exiting."
        fi
    fi
    # PostgreSQL check
    if ! command_exists psql; then
        echo "PostgreSQL is not installed."
        if ask_yes_no "Would you like to install PostgreSQL now?"; then
            install_postgres "$(detect_os)" || error_exit "PostgreSQL installation failed."
        else
            error_exit "PostgreSQL is required. Exiting."
        fi
    else
        echo "PostgreSQL is already installed."
    fi

    # --- 2. Move project to /opt/task-service ---
    local PROJECT_SRC="$(pwd)"
    local PROJECT_DEST="/opt/task-service"

    # Ensure we are inside the cloned repo
    if [ "$(basename "$PROJECT_SRC")" != "Task-Sample-FioTrix" ]; then
        error_exit "Script must be run from inside the cloned repo directory (Task-Sample-FioTrix)."
    fi

    echo "Moving project to $PROJECT_DEST..."
    sudo mkdir -p "$PROJECT_DEST"
    # Move all contents (including hidden files except . and ..)
    sudo mv "$PROJECT_SRC"/* "$PROJECT_SRC"/.[!.]* "$PROJECT_DEST" 2>/dev/null || true
    # Remove the empty original directory (optional)
    cd /
    sudo rmdir "$PROJECT_SRC" 2>/dev/null || true
    cd "$PROJECT_DEST"

    # --- 3. Create virtual environment and install dependencies ---
    echo "Creating uv virtual environment..."
    uv venv --python 3.14 "$PROJECT_DEST/.venv"   # adjust Python version if needed
    source "$PROJECT_DEST/.venv/bin/activate"
    echo "Installing project dependencies..."
    # Use the appropriate install command for your project
    uv sync --verbose

    # --- 4. Prepare the systemd service file ---
    local SERVICE_TEMPLATE="/opt/task-service/systemd/task.service"
    if [ ! -f "$SERVICE_TEMPLATE" ]; then
        error_exit "Service template '$SERVICE_TEMPLATE' not found in project."
    fi

    echo "Updating systemd service file..."
    # Define the entrypoint (adjust app:main according to your FastAPI app)
    local ENTRYPOINT="main:app"          # e.g., "app:app" or "main:create_app()"
    local VENV_PYTHON="$PROJECT_DEST/.venv/bin/python3"
    local WORKDIR="$PROJECT_DEST"

    # Replace placeholders in the service file
    sudo sed -i "s|^ExecStart=.*|ExecStart=$VENV_PYTHON -m uvicorn $ENTRYPOINT --host 0.0.0.0 --port 8000|" "$SERVICE_TEMPLATE"
    sudo sed -i "s|^WorkingDirectory=.*|WorkingDirectory=$WORKDIR|" "$SERVICE_TEMPLATE"
    # Keep User=root (or change if needed)

    echo "Copying service file to /etc/systemd/system/task.service..."
    sudo cp "$SERVICE_TEMPLATE" /etc/systemd/system/task.service

    # --- 5. Database setup ---
    echo
    echo "Please provide the PostgreSQL user credentials for your application."
    read -r -p "Username: " db_username
    read -r -s -p "Password: " db_password
    echo
    create_db_user "$db_username" "$db_password"
    create_db "$db_username"

    # --- 6. Enable and start the service ---
    echo "Reloading systemd and starting task.service..."
    sudo systemctl daemon-reload
    sudo systemctl enable task.service
    sudo systemctl start task.service

    echo "Service task.service is now running."
    echo "Check status with: sudo systemctl status task.service"
}

# ------------------------- Main -------------------------
main() {
    # Must run with root privileges (for systemd and /opt)
    if [ "$EUID" -ne 0 ]; then
        error_exit "Please run this script with sudo or as root."
    fi

    if ! command_exists git; then
        error_exit "git is not installed. Install git and run this script again."
    fi

    # Clone the repository if not already in it
    if [ ! -d "Task-Sample-FioTrix" ]; then
        git clone https://github.com/alisharify7/Task-Sample-FioTrix
    fi
    cd Task-Sample-FioTrix

    print_banner
    if ask_yes_no "Have you created the .env file in the root of the project?"; then
        echo "Good. Let's proceed."
    else
        error_exit ".env is required. Create it using: cp env.sample .env and fill in the required fields."
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
