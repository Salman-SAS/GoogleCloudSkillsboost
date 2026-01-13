#!/bin/bash

# -----------------------------
# Variables
# -----------------------------
PROJECT_ID=$(gcloud config get-value project)
REGION=us-east1
ZONE=us-east1-b
CLOUDSQL_INSTANCE=wordpress-sql
DB_NAME=wordpress
DB_USER=blogadmin         # Use preconfigured user in Qwiklabs
DB_PASS='Password1*'      # Use lab-provided password
LOCAL_DB_NAME=wordpress
LOCAL_DB_USER=blogadmin
LOCAL_DB_PASS='Password1*'
WP_PATH=/var/www/html/wordpress

# -----------------------------
# 0️⃣ Enable Cloud SQL API
# -----------------------------
echo "Enabling Cloud SQL Admin API..."
gcloud services enable sqladmin.googleapis.com || true

# -----------------------------
# 1️⃣ Create Cloud SQL instance
# -----------------------------
echo "Creating Cloud SQL instance..."
gcloud sql instances create $CLOUDSQL_INSTANCE \
    --database-version=MYSQL_5_7 \
    --tier=db-f1-micro \
    --region=$REGION \
    --gce-zone=$ZONE || true

# -----------------------------
# 1b️⃣ Wait until the instance is RUNNABLE
# -----------------------------
echo "Waiting for Cloud SQL instance to be READY..."
while true; do
    STATE=$(gcloud sql instances describe $CLOUDSQL_INSTANCE --format="value(state)" 2>/dev/null)
    if [ "$STATE" == "RUNNABLE" ]; then
        echo "Cloud SQL instance is ready!"
        break
    else
        echo "Waiting 10s..."
        sleep 10
    fi
done

# -----------------------------
# 2️⃣ Create the database
# -----------------------------
echo "Creating database if it doesn't exist..."
gcloud sql databases create $DB_NAME --instance=$CLOUDSQL_INSTANCE || true

# -----------------------------
# 3️⃣ Authorize blog VM to connect
# -----------------------------
BLOG_INSTANCE_IP=$(gcloud compute instances describe blog --zone=$ZONE --format='get(networkInterfaces[0].networkIP)')
echo "Authorizing blog VM ($BLOG_INSTANCE_IP) to connect to Cloud SQL..."
gcloud sql instances patch $CLOUDSQL_INSTANCE \
    --authorized-networks=$BLOG_INSTANCE_IP/32 --quiet

# -----------------------------
# 4️⃣ Dump local database
# -----------------------------
echo "Creating local database dump..."
mysqldump -u $LOCAL_DB_USER -p$LOCAL_DB_PASS $LOCAL_DB_NAME > /tmp/wordpress.sql

# -----------------------------
# 5️⃣ Import dump to Cloud SQL
# -----------------------------
echo "Importing dump into Cloud SQL..."
gcloud sql import sql $CLOUDSQL_INSTANCE /tmp/wordpress.sql --database=$DB_NAME --quiet

# -----------------------------
# 6️⃣ Update wp-config.php
# -----------------------------
CLOUDSQL_IP=$(gcloud sql instances describe $CLOUDSQL_INSTANCE --format='get(ipAddresses[0].ipAddress)')
echo "Updating wp-config.php to point to Cloud SQL..."
sudo sed -i "s/define('DB_NAME'.*/define('DB_NAME', '$DB_NAME');/" $WP_PATH/wp-config.php
sudo sed -i "s/define('DB_USER'.*/define('DB_USER', '$DB_USER');/" $WP_PATH/wp-config.php
sudo sed -i "s/define('DB_PASSWORD'.*/define('DB_PASSWORD', '$DB_PASS');/" $WP_PATH/wp-config.php
sudo sed -i "s/define('DB_HOST'.*/define('DB_HOST', '$CLOUDSQL_IP');/" $WP_PATH/wp-config.php

# -----------------------------
# 7️⃣ Restart Apache to apply changes
# -----------------------------
echo "Restarting Apache..."
sudo systemctl restart apache2

echo "✅ WordPress database migration complete!"
echo "Check your blog at http://<blog-instance-external-ip>"
