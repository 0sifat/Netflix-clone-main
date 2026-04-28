#!/bin/bash
# ============================================================
#  Jenkins Installer for Ubuntu 24.04
#  Matches official docs: https://www.jenkins.io/doc/book/installing/linux/
#  Run: sudo bash install_jenkins.sh
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $1"; }
success() { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

[[ $EUID -ne 0 ]] && error "Run as root:  sudo bash $0"

echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}   Jenkins Installer – Ubuntu 24.04        ${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

# ── 1. Clean up any previous Jenkins entries ─────────────────
info "Cleaning up any previous Jenkins repo/key entries..."
rm -f /etc/apt/sources.list.d/jenkins.list
rm -f /etc/apt/keyrings/jenkins-keyring.asc
rm -f /usr/share/keyrings/jenkins-keyring.asc   # old location cleanup
rm -f /usr/share/keyrings/jenkins-keyring.gpg
success "Cleaned."

# ── 2. System update ─────────────────────────────────────────
info "Updating system packages..."
apt-get update -qq && apt-get upgrade -y -qq
success "System updated."

# ── 3. Install Java 21 (official requirement) ────────────────
info "Installing fontconfig and OpenJDK 21..."
apt-get install -y -qq fontconfig openjdk-21-jre
java -version 2>&1 | head -1
success "Java 21 installed."

# ── 4. Import Jenkins GPG key (official 2026 key) ────────────
info "Downloading Jenkins GPG key (jenkins.io-2026.key)..."
mkdir -p /etc/apt/keyrings

wget -nv --timeout=30 \
  -O /etc/apt/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key \
  || error "Failed to download Jenkins GPG key."

# Sanity check – must be a real PGP key
grep -q "BEGIN PGP" /etc/apt/keyrings/jenkins-keyring.asc \
  || error "Downloaded file is not a valid PGP key. Check network/DNS."

success "GPG key saved to /etc/apt/keyrings/jenkins-keyring.asc"

# ── 5. Add Jenkins stable repository ─────────────────────────
info "Adding Jenkins APT repository..."
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
  | tee /etc/apt/sources.list.d/jenkins.list > /dev/null

apt-get update -qq \
  || error "apt-get update failed after adding Jenkins repo."
success "Jenkins repository added and verified."

# ── 6. Install Jenkins ────────────────────────────────────────
info "Installing Jenkins..."
apt-get install -y jenkins
success "Jenkins package installed."

# ── 7. Enable & start service ─────────────────────────────────
info "Enabling and starting Jenkins service..."
systemctl enable jenkins --quiet
systemctl start jenkins

info "Waiting for Jenkins to start (up to 90 seconds)..."
for i in $(seq 1 18); do
  systemctl is-active --quiet jenkins && break
  sleep 5
done

systemctl is-active --quiet jenkins \
  || error "Jenkins failed to start. Debug: journalctl -u jenkins -n 50"
success "Jenkins is running."

# ── 8. Retrieve initial admin password ────────────────────────
PASS_FILE="/var/lib/jenkins/secrets/initialAdminPassword"

info "Waiting for initial admin password file..."
for i in $(seq 1 18); do
  [[ -f "$PASS_FILE" ]] && break
  sleep 5
done

if [[ -f "$PASS_FILE" ]]; then
  JENKINS_PASS=$(cat "$PASS_FILE")
else
  warn "Password file not found yet. Retrieve later: sudo cat $PASS_FILE"
fi

# ── 9. Firewall ────────────────────────────────────────────────
if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
  info "Opening port 8080 in ufw..."
  ufw allow 8080/tcp > /dev/null
  success "Port 8080 opened."
else
  warn "ufw not active – open port 8080 manually if behind a firewall."
fi

# ── 10. Summary ────────────────────────────────────────────────
SERVER_IP=$(hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}   Jenkins Installation Complete!          ${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "  ${CYAN}Web UI        :${NC}  http://${SERVER_IP}:8080"
echo -e "  ${CYAN}Service status:${NC}  $(systemctl is-active jenkins)"
echo -e "  ${CYAN}Java version  :${NC}  $(java -version 2>&1 | awk -F '"' '/version/ {print $2}')"
echo ""
if [[ -n "$JENKINS_PASS" ]]; then
  echo -e "  ${YELLOW}┌──────────────────────────────────────────────┐${NC}"
  echo -e "  ${YELLOW}│        INITIAL ADMIN PASSWORD                │${NC}"
  echo -e "  ${YELLOW}│                                              │${NC}"
  echo -e "  ${YELLOW}│  ${RED}${JENKINS_PASS}${YELLOW}  │${NC}"
  echo -e "  ${YELLOW}│                                              │${NC}"
  echo -e "  ${YELLOW}│  Paste at  http://${SERVER_IP}:8080      │${NC}"
  echo -e "  ${YELLOW}└──────────────────────────────────────────────┘${NC}"
else
  echo -e "  ${YELLOW}Get password:${NC}  sudo cat $PASS_FILE"
fi
echo ""
echo -e "  ${CYAN}Useful commands:${NC}"
echo -e "    sudo systemctl status jenkins"
echo -e "    sudo systemctl restart jenkins"
echo -e "    sudo journalctl -u jenkins -f"
echo ""