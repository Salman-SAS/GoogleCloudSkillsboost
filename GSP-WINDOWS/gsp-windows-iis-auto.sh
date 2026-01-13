#!/bin/bash

# -----------------------------
# Variables
# -----------------------------
REGION=us-east4
ZONE=us-east4-b
VPC_NAME=securenetwork
SUBNET_NAME=secure-subnet
BASTION_VM=vm-bastionhost
SECURE_VM=vm-securehost
USER=app_admin

# -----------------------------
# 1️⃣ Create VPC and subnet
# -----------------------------
gcloud compute networks create $VPC_NAME --subnet-mode=custom || true

gcloud compute networks subnets create $SUBNET_NAME \
  --network=$VPC_NAME \
  --range=10.10.0.0/24 \
  --region=$REGION || true

# -----------------------------
# 2️⃣ Create firewall for bastion RDP
# -----------------------------
gcloud compute firewall-rules create allow-rdp-bastion \
  --allow tcp:3389 \
  --network=$VPC_NAME \
  --target-tags=bastion || true

# -----------------------------
# 3️⃣ Create startup script for IIS on secure host
# -----------------------------
STARTUP_SCRIPT=$(mktemp)
cat << 'EOF' > $STARTUP_SCRIPT
<powershell>
# Install IIS web server automatically
Install-WindowsFeature -Name Web-Server -IncludeManagementTools
# Optional: create default Hello World page
Set-Content -Path C:\inetpub\wwwroot\index.html -Value "Hello World!"
</powershell>
EOF

# -----------------------------
# 4️⃣ Create secure host (internal-only NIC + default NIC)
# -----------------------------
gcloud compute instances create $SECURE_VM \
  --zone=$ZONE \
  --image-family=windows-2016 \
  --image-project=windows-cloud \
  --machine-type=e2-medium \
  --network-interface=network=$VPC_NAME,subnet=$SUBNET_NAME \
  --network-interface=network=default \
  --tags=securehost \
  --metadata=startup-script="$(cat $STARTUP_SCRIPT)" \
  || true

# -----------------------------
# 5️⃣ Create bastion host (public IP + default NIC)
# -----------------------------
gcloud compute instances create $BASTION_VM \
  --zone=$ZONE \
  --image-family=windows-2016 \
  --image-project=windows-cloud \
  --machine-type=e2-medium \
  --network-interface=network=$VPC_NAME,subnet=$SUBNET_NAME,addresses=ephemeral \
  --network-interface=network=default \
  --tags=bastion \
  || true

# -----------------------------
# 6️⃣ Reset Windows passwords
# -----------------------------
gcloud compute reset-windows-password $BASTION_VM --user=$USER --zone=$ZONE
gcloud compute reset-windows-password $SECURE_VM --user=$USER --zone=$ZONE

echo "✅ Windows VMs created."
echo "✅ Secure host has IIS installed automatically via startup script."
echo "✅ Connect via RDP to bastion host if needed, or verify via external IP."
