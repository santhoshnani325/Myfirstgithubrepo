#!/bin/bash
set -e

# ============================================
# Jenkins Installation for Multiple Linux Distributions
# ============================================
# Supports: Ubuntu, Debian, CentOS, RHEL, Fedora, Amazon Linux
# Production-ready with password protection
# ============================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_header() {
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}========================================${NC}"
}

print_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
  echo -e "${RED}✗ $1${NC}"
}

# Detect Linux Distribution
detect_distro() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
  elif type lsb_release >/dev/null 2>&1; then
    OS=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
    VER=$(lsb_release -sr)
  elif [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
    OS=$(echo $DISTRIB_ID | tr '[:upper:]' '[:lower:]')
    VER=$DISTRIB_RELEASE
  else
    OS=$(uname -s)
    VER=$(uname -r)
  fi
  
  echo "$OS"
}

# Update system based on distribution
update_system() {
  case "$1" in
    ubuntu|debian)
      print_header "Updating Debian/Ubuntu System"
      sudo apt-get update -y
      sudo apt-get upgrade -y
      ;;
    centos|rhel|fedora)
      print_header "Updating CentOS/RHEL/Fedora System"
      sudo yum update -y
      ;;
    amzn)
      print_header "Updating Amazon Linux System"
      sudo yum update -y
      ;;
    *)
      print_error "Unknown distribution: $1"
      exit 1
      ;;
  esac
  print_success "System updated"
}

# Install Java based on distribution
install_java() {
  case "$1" in
    ubuntu|debian)
      print_header "Installing Java 21 on Debian/Ubuntu"
      sudo apt-get install -y openjdk-21-jdk openjdk-21-jre
      ;;
    centos|rhel)
      print_header "Installing Java 21 on CentOS/RHEL"
      sudo yum install -y java-21-openjdk java-21-openjdk-devel
      ;;
    fedora)
      print_header "Installing Java 21 on Fedora"
      sudo dnf install -y java-21-openjdk java-21-openjdk-devel
      ;;
    amzn)
      print_header "Installing Java 21 on Amazon Linux"
      sudo yum install -y java-21-amazon-corretto java-21-amazon-corretto-devel
      ;;
    *)
      print_error "Unknown distribution: $1"
      exit 1
      ;;
  esac
  
  java -version
  print_success "Java 21 installed"
}

# Install dependencies based on distribution
install_dependencies() {
  case "$1" in
    ubuntu|debian)
      print_header "Installing Dependencies on Debian/Ubuntu"
      sudo apt-get install -y wget curl gnupg2 net-tools git
      ;;
    centos|rhel|amzn)
      print_header "Installing Dependencies on CentOS/RHEL/Amazon Linux"
      sudo yum install -y wget curl gnupg2 net-tools git
      ;;
    fedora)
      print_header "Installing Dependencies on Fedora"
      sudo dnf install -y wget curl gnupg2 net-tools git
      ;;
    *)
      print_error "Unknown distribution: $1"
      exit 1
      ;;
  esac
  print_success "Dependencies installed"
}

# Main installation process
main() {
  print_header "Jenkins Production Installation for Linux"
  echo -e ""
  echo -e "${GREEN}Features:${NC}"
  echo -e "  ✓ Multi-distribution support"
  echo -e "  ✓ Password protection enabled"
  echo -e "  ✓ Initial setup wizard enabled"
  echo -e "  ✓ Security-hardened configuration"
  echo -e "  ✓ Suitable for public IP access"
  echo -e "  ✓ Production-ready"
  echo -e ""

  # Detect distribution
  echo "Detecting Linux distribution..."
  DISTRO=$(detect_distro)
  echo "Detected distribution: $DISTRO"
  print_success "Distribution detected: $DISTRO"
  echo ""

  # Step 1: Update system
  print_header "Step 1: System Update"
  update_system "$DISTRO"
  echo ""

  # Step 2: Install Java
  print_header "Step 2: Installing Java 21"
  install_java "$DISTRO"
  echo ""

  # Step 3: Install dependencies
  print_header "Step 3: Installing Dependencies"
  install_dependencies "$DISTRO"
  echo ""

  # Step 4: Download Jenkins
  print_header "Step 4: Downloading Jenkins WAR"
  cd /tmp
  rm -f jenkins.war
  wget https://get.jenkins.io/war-stable/latest/jenkins.war
  print_success "Jenkins downloaded successfully"
  echo ""

  # Step 5: Setup Jenkins directories
  print_header "Step 5: Setting Up Jenkins Directories"
  sudo mkdir -p /opt/jenkins
  sudo mv jenkins.war /opt/jenkins/
  sudo chmod 755 /opt/jenkins
  sudo chmod 644 /opt/jenkins/jenkins.war
  print_success "Jenkins directories created"
  echo ""

  # Step 6: Create Jenkins user
  print_header "Step 6: Creating Jenkins System User"
  sudo useradd -r -m -s /usr/sbin/nologin jenkins 2>/dev/null || true
  sudo mkdir -p /var/lib/jenkins
  sudo mkdir -p /var/cache/jenkins
  sudo mkdir -p /var/log/jenkins
  sudo chown -R jenkins:jenkins /var/lib/jenkins
  sudo chown -R jenkins:jenkins /var/cache/jenkins
  sudo chown -R jenkins:jenkins /var/log/jenkins
  sudo chown -R jenkins:jenkins /opt/jenkins
  sudo chmod 750 /var/lib/jenkins
  print_success "Jenkins user created with restricted permissions"
  echo ""

  # Step 7: Create systemd service
  print_header "Step 7: Creating Systemd Service"
  sudo tee /etc/systemd/system/jenkins.service > /dev/null <<'EOF'
[Unit]
Description=Jenkins Automation Server
After=network.target syslog.target
Wants=network-online.target

[Service]
Type=simple
User=jenkins
Group=jenkins
WorkingDirectory=/var/lib/jenkins

# Production-grade configuration
ExecStart=/usr/bin/java \
  -Xmx1024m \
  -Xms512m \
  -Djenkins.install.runSetupWizard=true \
  -Djenkins.model.Jenkins.logStartupPerformance=true \
  -Dcom.sun.akuma.Daemon=true \
  -Djava.awt.headless=true \
  -Dorg.apache.commons.jelly.tags.fmt.timeZone=UTC \
  -Duser.timezone=UTC \
  -jar /opt/jenkins/jenkins.war \
  --httpPort=8080 \
  --prefix=/jenkins \
  --requestLogFormat='%{X-Forwarded-For}i %a %m %U%q %W'

# Restart policy
Restart=on-failure
RestartSec=10
StartLimitInterval=600
StartLimitBurst=5

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=jenkins

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/lib/jenkins /var/cache/jenkins /var/log/jenkins

# Resource limits
LimitNOFILE=65536
LimitNPROC=32768

[Install]
WantedBy=multi-user.target
EOF
  print_success "Systemd service created"
  echo ""

  # Step 8: Create Jenkins configuration
  print_header "Step 8: Creating Jenkins Configuration"
  sudo tee /var/lib/jenkins/jenkins.model.JenkinsLocationConfiguration.xml > /dev/null <<'EOF'
<?xml version="1.1" encoding="UTF-8"?>
<jenkins.model.JenkinsLocationConfiguration>
  <adminAddress>admin@example.com</adminAddress>
  <jenkinsUrl>http://localhost:8080/</jenkinsUrl>
</jenkins.model.JenkinsLocationConfiguration>
EOF
  sudo chown jenkins:jenkins /var/lib/jenkins/jenkins.model.JenkinsLocationConfiguration.xml
  print_success "Jenkins configuration created"
  echo ""

  # Step 9: Configure firewall (if available)
  print_header "Step 9: Configuring Firewall"
  configure_firewall "$DISTRO"
  echo ""

  # Step 10: Start Jenkins service
  print_header "Step 10: Starting Jenkins Service"
  sudo systemctl daemon-reload
  sudo systemctl start jenkins
  sudo systemctl enable jenkins
  print_success "Jenkins service started and enabled"
  echo ""

  # Step 11: Wait for Jenkins to initialize
  echo "Waiting for Jenkins to start (30 seconds)..."
  sleep 30

  # Step 12: Retrieve initial admin password
  print_header "Step 11: Retrieving Initial Admin Password"
  INITIAL_PASS_FILE="/var/lib/jenkins/secrets/initialAdminPassword"

  COUNT=0
  while [ ! -f "$INITIAL_PASS_FILE" ] && [ $COUNT -lt 60 ]; do
    sleep 1
    COUNT=$((COUNT + 1))
  done

  if [ -f "$INITIAL_PASS_FILE" ]; then
    INITIAL_PASSWORD=$(sudo cat "$INITIAL_PASS_FILE")
    print_success "Initial admin password retrieved"
  else
    print_warning "Initial admin password file not found yet"
    INITIAL_PASSWORD="CHECK_LOGS"
  fi
  echo ""

  # Step 13: Verify Jenkins
  print_header "Step 12: Verifying Jenkins Installation"
  sudo systemctl status jenkins
  echo ""

  # Step 14: Display summary
  print_header "PRODUCTION JENKINS INSTALLED SUCCESSFULLY"
  echo ""
  echo -e "${GREEN}📋 JENKINS DETAILS:${NC}"
  echo "  - Status: Running"
  echo "  - Java Version: 21"
  echo "  - Service: jenkins"
  echo "  - Port: 8080"
  echo "  - Setup Wizard: ENABLED"
  echo "  - Password Protection: ENABLED"
  echo "  - Distribution: $DISTRO"
  echo ""

  echo -e "${GREEN}🌐 ACCESS INFORMATION:${NC}"
  echo "  - Local Access: http://localhost:8080"
  echo "  - Public IP Access: http://<your-public-ip>:8080"
  echo "  - Jenkins Prefix: /jenkins"
  echo ""

  echo -e "${GREEN}🔐 INITIAL ADMIN PASSWORD:${NC}"
  echo "=========================================="
  if [ "$INITIAL_PASSWORD" != "CHECK_LOGS" ]; then
    echo "$INITIAL_PASSWORD"
  else
    echo "Password not yet generated. Check after first access:"
    echo "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
  fi
  echo "=========================================="
  echo ""

  echo -e "${GREEN}📝 FIRST TIME SETUP INSTRUCTIONS:${NC}"
  echo "  1. Open http://<your-public-ip>:8080 in browser"
  echo "  2. Enter the initial admin password above"
  echo "  3. Click 'Continue'"
  echo "  4. Install suggested plugins"
  echo "  5. Create first admin user"
  echo "  6. Configure Jenkins URL"
  echo "  7. Complete setup"
  echo ""

  echo -e "${GREEN}🔒 SECURITY RECOMMENDATIONS FOR PRODUCTION:${NC}"
  echo "  1. Use Nginx/Apache reverse proxy with SSL/TLS"
  echo "  2. Enable 2FA for admin user"
  echo "  3. Configure firewall to restrict IP access"
  echo "  4. Regularly update Jenkins and plugins"
  echo "  5. Configure LDAP/SAML for SSO"
  echo "  6. Enable audit logging"
  echo "  7. Configure automated backups"
  echo "  8. Use strong admin password"
  echo "  9. Implement network segmentation"
  echo "  10. Monitor logs and metrics"
  echo ""

  echo -e "${GREEN}📊 USEFUL COMMANDS:${NC}"
  echo "  - View logs: sudo journalctl -u jenkins -f"
  echo "  - Check status: sudo systemctl status jenkins"
  echo "  - Start service: sudo systemctl start jenkins"
  echo "  - Stop service: sudo systemctl stop jenkins"
  echo "  - Restart service: sudo systemctl restart jenkins"
  echo "  - Get password: sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
  echo "  - Check port: sudo ss -tlnp | grep 8080"
  echo ""

  print_header "Installation Complete!"
}

# Configure firewall based on distribution
configure_firewall() {
  case "$1" in
    ubuntu|debian)
      if command -v ufw &> /dev/null; then
        if sudo ufw status | grep -q "Status: active"; then
          print_header "Configuring UFW Firewall"
          sudo ufw allow 8080/tcp comment "Jenkins HTTP" 2>/dev/null || true
          sudo ufw allow 50000/tcp comment "Jenkins Agent Port" 2>/dev/null || true
          print_success "UFW firewall rules added"
        else
          print_warning "UFW is not active"
        fi
      else
        print_warning "UFW not installed"
      fi
      ;;
    centos|rhel|fedora|amzn)
      if command -v firewall-cmd &> /dev/null; then
        if sudo systemctl is-active --quiet firewalld; then
          print_header "Configuring FirewallD"
          sudo firewall-cmd --permanent --add-port=8080/tcp 2>/dev/null || true
          sudo firewall-cmd --permanent --add-port=50000/tcp 2>/dev/null || true
          sudo firewall-cmd --reload 2>/dev/null || true
          print_success "FirewallD rules added"
        else
          print_warning "FirewallD is not active"
        fi
      else
        print_warning "FirewallD not installed"
      fi
      ;;
    *)
      print_warning "Firewall configuration skipped for $1"
      ;;
  esac
}

# Check if running as root
if [ "$EUID" -ne 0 ] && ! sudo -n true 2>/dev/null; then
  print_error "This script must be run with sudo privileges"
  exit 1
fi

# Run main function
main