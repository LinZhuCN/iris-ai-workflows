#!/bin/sh
set -eu
cp /config/CSP.ini /opt/webgateway/bin/CSP.ini
printf '\nUsername=ContestGateway\nPassword=' >> /opt/webgateway/bin/CSP.ini
cat /run/secrets/gateway-password >> /opt/webgateway/bin/CSP.ini
cp /config/CSP.conf /etc/apache2/conf-enabled/CSP.conf
exec /startWebGateway
