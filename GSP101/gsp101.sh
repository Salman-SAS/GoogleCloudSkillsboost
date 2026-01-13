#!/bin/bash

ZONE=us-central1-a
VM_NAME=prd-eng-j4o

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
echo 'Hello World!' | sudo tee /var/www/html/index.html &&
sudo systemctl restart apache2
"
