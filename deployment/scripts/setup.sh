#!/bin/bash
# Setup script for Software Deployment Labs
# Run on a fresh Ubuntu 22.04 or CentOS 9 system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Software Deployment Labs Setup ===${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root${NC}"
   exit 1
fi

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo -e "${RED}Error: Cannot detect OS${NC}"
    exit 1
fi

echo -e "${YELLOW}Detected OS: $OS${NC}"

# ============== Update System ==============
echo -e "${YELLOW}[1/10] Updating system packages...${NC}"

if [ "$OS" == "ubuntu" ]; then
    apt-get update
    apt-get upgrade -y
    apt-get install -y python3 python3-pip python3-venv git mysql-server nginx \
        curl wget vim supervisor
elif [ "$OS" == "centos" ] || [ "$OS" == "rhel" ]; then
    yum update -y
    yum install -y python3 python3-pip git mysql-server nginx curl wget vim
else
    echo -e "${RED}Unsupported OS: $OS${NC}"
    exit 1
fi

echo -e "${GREEN}✓ System updated${NC}"

# ============== Create Users ==============
echo -e "${YELLOW}[2/10] Creating system users...${NC}"

# Create 'app' user (systemd service user)
if ! id -u app > /dev/null 2>&1; then
    useradd --system --shell /bin/false --home-dir /opt/software-deployment-labs app
    echo -e "${GREEN}✓ Created 'app' user${NC}"
else
    echo -e "${GREEN}✓ 'app' user already exists${NC}"
fi

# Create 'student' user with administrative access
if ! id -u student > /dev/null 2>&1; then
    useradd --shell /bin/bash --home-dir /home/student -m student
    echo "student:12345678" | chpasswd
    usermod -aG sudo student
    # Force password change on first login
    chage -d 0 student
    echo -e "${GREEN}✓ Created 'student' user${NC}"
else
    echo -e "${GREEN}✓ 'student' user already exists${NC}"
fi

# Create 'teacher' user with administrative access
if ! id -u teacher > /dev/null 2>&1; then
    useradd --shell /bin/bash --home-dir /home/teacher -m teacher
    echo "teacher:12345678" | chpasswd
    usermod -aG sudo teacher
    # Force password change on first login
    chage -d 0 teacher
    echo -e "${GREEN}✓ Created 'teacher' user${NC}"
else
    echo -e "${GREEN}✓ 'teacher' user already exists${NC}"
fi

# Create 'operator' user with limited access
if ! id -u operator > /dev/null 2>&1; then
    useradd --shell /bin/bash --home-dir /home/operator -m operator
    echo "operator:12345678" | chpasswd
    # Force password change on first login
    chage -d 0 operator
    echo -e "${GREEN}✓ Created 'operator' user${NC}"
else
    echo -e "${GREEN}✓ 'operator' user already exists${NC}"
fi

echo -e "${GREEN}✓ Users created${NC}"

# ============== Setup Sudo Access ==============
echo -e "${YELLOW}[3/10] Configuring sudo access...${NC}"

# Create sudoers file for operator with limited access
cat > /etc/sudoers.d/operator << 'EOF'
# operator user can manage mywebapp service and nginx reload
operator ALL=(ALL) NOPASSWD: /bin/systemctl start mywebapp
operator ALL=(ALL) NOPASSWD: /bin/systemctl stop mywebapp
operator ALL=(ALL) NOPASSWD: /bin/systemctl restart mywebapp
operator ALL=(ALL) NOPASSWD: /bin/systemctl status mywebapp
operator ALL=(ALL) NOPASSWD: /bin/systemctl reload nginx
EOF

chmod 440 /etc/sudoers.d/operator
echo -e "${GREEN}✓ Sudo access configured${NC}"

# ============== Setup Application ==============
echo -e "${YELLOW}[4/10] Setting up application...${NC}"

APP_DIR="/opt/software-deployment-labs"

# Clone or setup repo (assuming it's already in /opt or cloned by user)
if [ ! -d "$APP_DIR" ]; then
    echo -e "${YELLOW}Cloning repository...${NC}"
    git clone https://github.com/StenSOn27/practice-software-deployment-labs.git "$APP_DIR"
fi

# Set proper permissions
chown -R app:app "$APP_DIR"
chmod 750 "$APP_DIR"

# Install Python dependencies
cd "$APP_DIR"
python3 -m pip install --upgrade pip setuptools wheel
python3 -m pip install -r requirements.txt

echo -e "${GREEN}✓ Application setup complete${NC}"

# ============== Setup Database ==============
echo -e "${YELLOW}[5/10] Setting up database...${NC}"

# Start MySQL
if [ "$OS" == "ubuntu" ]; then
    systemctl start mysql
    systemctl enable mysql
elif [ "$OS" == "centos" ] || [ "$OS" == "rhel" ]; then
    systemctl start mysqld
    systemctl enable mysqld
fi

# Wait for MySQL to start
sleep 3

# Create database and user
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-root}"
DB_NAME="software_labs"
DB_USER="app_user"
DB_PASSWORD="app_password_123"

mysql -u root -p"$MYSQL_ROOT_PASSWORD" << EOF || true
CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# Update config.ini with database credentials
mkdir -p "$APP_DIR/etc"
cat > "$APP_DIR/src/config.ini" << EOF
[database]
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
DB_HOST=127.0.0.1
DB_PORT=3306
DB_SCHEME=mysql+aiomysql

[service]
HOST=127.0.0.1
PORT=8000
EOF

chown app:app "$APP_DIR/src/config.ini"
chmod 640 "$APP_DIR/src/config.ini"

echo -e "${GREEN}✓ Database setup complete${NC}"
echo -e "${YELLOW}Database credentials saved in $APP_DIR/src/config.ini${NC}"

# ============== Run Migrations ==============
echo -e "${YELLOW}[6/10] Running database migrations...${NC}"

cd "$APP_DIR"
sudo -u app python3 -m alembic upgrade head || {
    echo -e "${RED}Warning: Migrations may have failed, check logs${NC}"
}

echo -e "${GREEN}✓ Migrations completed${NC}"

# ============== Setup Systemd Service ==============
echo -e "${YELLOW}[7/10] Setting up systemd service...${NC}"

# Copy systemd service file
cp "$APP_DIR/deployment/configs/mywebapp.service" /etc/systemd/system/mywebapp.service
cp "$APP_DIR/deployment/configs/mywebapp.socket" /etc/systemd/system/mywebapp.socket

# Update paths in service file if needed
sed -i "s|/opt/software-deployment-labs|$APP_DIR|g" /etc/systemd/system/mywebapp.service

# Reload systemd
systemctl daemon-reload

# Enable service
systemctl enable mywebapp.service

echo -e "${GREEN}✓ Systemd service configured${NC}"

# ============== Setup Nginx ==============
echo -e "${YELLOW}[8/10] Configuring Nginx...${NC}"

# Backup original config
cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup

# Create site-specific config
cp "$APP_DIR/deployment/configs/nginx.conf" /etc/nginx/sites-available/mywebapp || \
cp "$APP_DIR/deployment/configs/nginx.conf" /etc/nginx/conf.d/mywebapp.conf

# Remove default site
rm -f /etc/nginx/sites-enabled/default

# Enable site
if [ -d /etc/nginx/sites-enabled ]; then
    ln -sf /etc/nginx/sites-available/mywebapp /etc/nginx/sites-enabled/mywebapp
fi

# Test nginx config
nginx -t

# Enable Nginx
systemctl enable nginx

echo -e "${GREEN}✓ Nginx configured${NC}"

# ============== Create Gradebook ==============
echo -e "${YELLOW}[9/10] Creating gradebook file...${NC}"

echo "28" > /home/student/gradebook
chown student:student /home/student/gradebook
chmod 644 /home/student/gradebook

echo -e "${GREEN}✓ Gradebook created at /home/student/gradebook${NC}"

# ============== Start Services ==============
echo -e "${YELLOW}[10/10] Starting services...${NC}"

# Start mywebapp
systemctl start mywebapp
sleep 2

# Start Nginx
systemctl restart nginx

# Check status
if systemctl is-active --quiet mywebapp; then
    echo -e "${GREEN}✓ mywebapp service is running${NC}"
else
    echo -e "${RED}✗ mywebapp service failed to start${NC}"
    systemctl status mywebapp
fi

if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✓ Nginx is running${NC}"
else
    echo -e "${RED}✗ Nginx failed to start${NC}"
    systemctl status nginx
fi

# ============== Summary ==============
echo -e "${GREEN}=== Setup Complete ===${NC}"
echo
echo "System Information:"
echo "  - Application directory: $APP_DIR"
echo "  - Database: $DB_NAME"
echo "  - Database user: $DB_USER"
echo "  - Systemd service: /etc/systemd/system/mywebapp.service"
echo "  - Nginx config: /etc/nginx/sites-available/mywebapp"
echo
echo "Default Users (password: 12345678 - must be changed):"
echo "  - student: sudo access, home /home/student"
echo "  - teacher: sudo access, home /home/teacher"
echo "  - operator: limited sudo, can manage app and nginx"
echo "  - app: system user for running the service"
echo
echo "Next Steps:"
echo "  1. SSH into VM: ssh student@<ip-address>"
echo "  2. Change password: passwd"
echo "  3. Test health endpoint: curl http://localhost/health/alive"
echo "  4. View application: http://<ip-address>"
echo "  5. Check logs: sudo journalctl -u mywebapp -f"
echo

exit 0
