#!/bin/bash
set -e

echo "=========================================="
echo "Jenkins Installation on Ubuntu 24.04 LTS"
echo "=========================================="

# Step 1: Update system and install Java 21
echo ""
echo "Step 1: Installing Java 21..."
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y openjdk-21-jdk openjdk-21-jre
java -version

# Step 2: Install dependencies
echo ""
echo "Step 2: Installing dependencies..."
sudo apt install -y wget curl gnupg2

# Step 3: Download Jenkins WAR directly
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

# Step 5: Create Jenkins user
echo ""
echo "Step 5: Creating Jenkins user..."
sudo useradd -r -m -s /bin/bash jenkins 2>/dev/null || true
sudo mkdir -p /var/lib/jenkins
sudo chown -R jenkins:jenkins /var/lib/jenkins
sudo chown -R jenkins:jenkins /opt/jenkins
echo "✓ Jenkins user created"

# Step 6: Create systemd service
echo ""
echo "Step 6: Creating systemd service..."
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
ExecStart=/usr/bin/java -Djenkins.install.runSetupWizard=false -jar /opt/jenkins/jenkins.war --httpPort=8080
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
echo "✓ Systemd service created"

# Step 7: Start Jenkins
echo ""
echo "Step 7: Starting Jenkins service..."
sudo systemctl daemon-reload
sudo systemctl start jenkins
sudo systemctl enable jenkins

echo ""
echo "Waiting for Jenkins to start (15 seconds)..."
sleep 15

# Step 8: Verify Jenkins is running
echo ""
echo "Step 8: Verifying Jenkins installation..."
sudo systemctl status jenkins

echo ""
echo "=========================================="
echo "✅ JENKINS INSTALLATION COMPLETE!"
echo "=========================================="
echo ""
echo "Jenkins Details:"
echo "  - Service: jenkins"
echo "  - Port: 8080"
echo "  - URL: http://localhost:8080"
echo "  - Java Version: 21"
echo ""
echo "Useful Commands:"
echo "  - Check status: sudo systemctl status jenkins"
echo "  - View logs: sudo journalctl -u jenkins -f"
echo "  - Start service: sudo systemctl start jenkins"
echo "  - Stop service: sudo systemctl stop jenkins"
echo "  - Restart service: sudo systemctl restart jenkins"
echo ""
echo "=========================================="