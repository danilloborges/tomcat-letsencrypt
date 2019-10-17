#!/bin/bash
set -ex
DOMAIN=""
TOMCAT_KEY_PASS=""
CERTBOT_BIN="/usr/local/bin/certbot-auto"
EMAIL_NOTIFICATION="email_address"

# Install certbot

install_certbot () {
    if [[ ! -f /usr/local/bin/certbot-auto ]]; then
        wget https://dl.eff.org/certbot-auto -P /usr/local/bin
        chmod a+x $CERTBOT_BIN
    fi
}

# Attempt cert renewal:
renew_ssl () {    
    ${CERTBOT_BIN} certonly --webroot -w /usr/share/tomcat/webapps --keep -d ${DOMAIN} > /tmp/crt.txt
    
    cat /tmp/crt.txt | grep "Certificate not yet due for renewal"
    if [[ $? -eq "0" ]]; then
        echo "Cert not yet due for renewal"
        exit 0
    else
        # Create Letsencypt ssl dir if doesn't exist
        echo "Renewing ssl certificate..."
        # copy keys to tomcatFolder /etc/letsencrypt/live/    
        cd /etc/letsencrypt/live/${DOMAIN}
        cp cert.pem /usr/share/tomcat/conf
        cp chain.pem /usr/share/tomcat/conf
        cp privkey.pem /usr/share/tomcat/conf
        chown tomcat:tomcat /usr/share/tomcat/conf/*.pem     
        systemctl restart tomcat
    fi
}

# Send email notification on completion
send_email_notification () {
    if [[ $? -eq "0" ]]; then
        echo " Retarting tomcat server"
        systemctl restart tomcat
        if [[ $? -eq "0" ]]; then
            echo "" > /tmp/success
            echo "Letsencrypt ssl certificate for $DOMAIN successfully renewed by cron job." >> /tmp/success
            echo "" >> /tmp/success
            echo "Tomcat successfully restarted after renewal" >> /tmp/success
            mail -s "$DOMAIN Letsencrypt renewal" support-notify@angani.co < /tmp/success
        else
            echo "" > /tmp/failure
            echo "Letsencrypt ssl certificate for $DOMAIN renewal by cron job failed." >> /tmp/failure
            echo "" >> /tmp/failure
            echo "Try again manually.." >> /tmp/failure
            mail -s "$DOMAIN Letsencrypt renewal" $EMAIL_NOTIFICATION < /tmp/failure
        fi
    fi
}

# Main

install_certbot
renew_ssl
send_email_notification
