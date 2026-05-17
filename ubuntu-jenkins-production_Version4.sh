#!/bin/bash
set -e

echo "=========================================="
echo "Jenkins Installation - PRODUCTION READY"
echo "=========================================="
echo ""
echo "Features:"
echo "  ✓ Password protection enabled"
echo "  ✓ Initial setup wizard enabled"
echo "  ✓ Security-hardened configuration"
echo "  ✓ Suitable for public IP access"
echo "  ✓ Reverse proxy ready"
echo ""

# Step 1: Update system and install Java 21
echo "Step 1: Installing Java 21..."
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y openjdk-21-jdk openjdk-21-jre
java -version

# Step 2: Install dependencies
echo ""
echo "Step 2: Installing dependencies..."
sudo apt install -y wget curl gnupg2 net-tools

# Step 3: Download Jenkins WAR
echo ""
echo "Step 3: Downloading Jenkins..."
cd /tmp
rm -f jenkins.war
wget https://get.jenkins.io/war-stable/latest/jenkins.war
echo "✓ Jenkins downloaded successfully"

# Step 4: Setup Jenkins directories
echo ""
echo "Step 4: Setting up Jenkins directories..."
sudo mkdir -p /opt/jenkins
sudo mv jenkins.war /opt/jenkins/
sudo chmod 755 /opt/jenkins
sudo chmod 644 /opt/jenkins/jenkins.war
echo "✓ Jenkins directories created"

# Step 5: Create Jenkins user with restricted shell
echo ""
echo "Step 5: Creating Jenkins system user..."
sudo useradd -r -m -s /usr/sbin/nologin jenkins 2>/dev/null || true
sudo mkdir -p /var/lib/jenkins
sudo mkdir -p /var/cache/jenkins
sudo mkdir -p /var/log/jenkins
sudo chown -R jenkins:jenkins /var/lib/jenkins
sudo chown -R jenkins:jenkins /var/cache/jenkins
sudo chown -R jenkins:jenkins /var/log/jenkins
sudo chown -R jenkins:jenkins /opt/jenkins
sudo chmod 750 /var/lib/jenkins
echo "✓ Jenkins user created with restricted permissions"

# Step 6: Create production systemd service
echo ""
echo "Step 6: Creating production systemd service..."
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
echo "✓ Production systemd service created"

# Step 7: Create Jenkins configuration
echo ""
echo "Step 7: Creating Jenkins configuration..."
sudo tee /var/lib/jenkins/jenkins.model.JenkinsLocationConfiguration.xml > /dev/null <<'EOF'
<?xml version="1.1" encoding="UTF-8"?>
<jenkins.model.JenkinsLocationConfiguration>
  <adminAddress>admin@example.com</adminAddress>
  <jenkinsUrl>http://localhost:8080/</jenkinsUrl>
</jenkins.model.JenkinsLocationConfiguration>
EOF
sudo chown jenkins:jenkins /var/lib/jenkins/jenkins.model.JenkinsLocationConfiguration.xml
echo "✓ Jenkins configuration created"

# Step 8: Create firewall rules (if UFW is enabled)
echo ""
echo "Step 8: Configuring firewall..."
if command -v ufw &> /dev/null; then
  # Check if UFW is active
  if sudo ufw status | grep -q "Status: active"; then
    echo "UFW is active. Adding Jenkins port rules..."
    sudo ufw allow 8080/tcp comment "Jenkins HTTP" 2>/dev/null || true
    sudo ufw allow 50000/tcp comment "Jenkins Agent Port" 2>/dev/null || true
    echo "✓ Firewall rules added"
  else
    echo "UFW is not active. Skipping firewall configuration."
  fi
else
  echo "UFW not installed. Skipping firewall configuration."
fi

# Step 9: Start Jenkins service
echo ""
echo "Step 9: Starting Jenkins service..."
sudo systemctl daemon-reload
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Wait for Jenkins to initialize
echo ""
echo "Waiting for Jenkins to start (30 seconds)..."
sleep 30

# Step 10: Get initial admin password
echo ""
echo "Step 10: Retrieving initial admin password..."
INITIAL_PASS_FILE="/var/lib/jenkins/secrets/initialAdminPassword"

# Wait for password file to be created
COUNT=0
while [ ! -f "$INITIAL_PASS_FILE" ] && [ $COUNT -lt 60 ]; do
  sleep 1
  COUNT=$((COUNT + 1))
done

if [ -f "$INITIAL_PASS_FILE" ]; then
  INITIAL_PASSWORD=$(sudo cat "$INITIAL_PASS_FILE")
  echo "✓ Initial admin password retrieved"
else
  echo "⚠ Initial admin password file not found yet. It will be created on first access."
  INITIAL_PASSWORD="CHECK_LOGS"
fi

# Step 11: Verify Jenkins is running
echo ""
echo "Step 11: Verifying Jenkins installation..."
sudo systemctl status jenkins

# Step 12: Display summary
echo ""
echo "=========================================="
echo "✅ PRODUCTION JENKINS INSTALLED!"
echo "=========================================="
echo ""
echo "📋 JENKINS DETAILS:"
echo "  - Status: Running"
echo "  - Java Version: 21"
echo "  - Service: jenkins"
echo "  - Port: 8080"
echo "  - Setup Wizard: ENABLED"
echo "  - Password Protection: ENABLED"
echo ""
echo "🌐 ACCESS INFORMATION:"
echo "  - Local Access: http://localhost:8080"
echo "  - Public IP Access: http://<your-public-ip>:8080"
echo "  - Jenkins Prefix: /jenkins"
echo ""
echo "🔐 INITIAL ADMIN PASSWORD:"
echo "=========================================="
if [ "$INITIAL_PASSWORD" != "CHECK_LOGS" ]; then
  echo "$INITIAL_PASSWORD"
else
  echo "Password not yet generated. Check after first access:"
  echo "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
fi
echo "=========================================="
echo ""
echo "📝 FIRST TIME SETUP INSTRUCTIONS:"
echo "  1. Open http://<your-public-ip>:8080 in browser"
echo "  2. Enter the initial admin password above"
echo "  3. Click 'Continue'"
echo "  4. Install suggested plugins"
echo "  5. Create first admin user"
echo "  6. Configure Jenkins URL"
echo "  7. Complete setup"
echo ""
echo "🔒 SECURITY RECOMMENDATIONS FOR PRODUCTION:"
echo "  1. Use Nginx/Apache reverse proxy with SSL/TLS"
echo "  2. Enable 2FA for admin user"
echo "  3. Configure firewall to restrict IP access"
echo "  4. Regularly update Jenkins and plugins"
echo "  5. Configure LDAP/SAML for SSO"
echo "  6. Enable audit logging"
echo "  7. Configure backups"
echo "  8. Use strong admin password"
echo ""
echo "📊 USEFUL COMMANDS:"
echo "  - View logs: sudo journalctl -u jenkins -f"
echo "  - Check status: sudo systemctl status jenkins"
echo "  - Start service: sudo systemctl start jenkins"
echo "  - Stop service: sudo systemctl stop jenkins"
echo "  - Restart service: sudo systemctl restart jenkins"
echo "  - Get password: sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
echo "  - Check port: sudo ss -tlnp | grep 8080"
echo ""
echo "=========================================="