#!/bin/bash

ZONE=us-central1-a
VM_NAME=apache-vm

gcloud compute instances create $VM_NAME \
--zone=$ZONE \
--machine-type=e2-micro \
--image-family=debian-11 \
--image-project=debian-cloud \
--tags=http-server

gcloud compute firewall-rules create allow-http \
--allow tcp:80 \
--target-tags=http-server || true

gcloud compute ssh $VM_NAME --zone=$ZONE --command="
sudo apt update &&
sudo apt install -y apache2 &&
sudo systemctl start apache2 &&
sudo systemctl enable apache2
"

gcloud compute instances list --filter="name=$VM_NAME"
