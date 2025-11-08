[Unit]
Description=Tidal Connect Docker Service
After=docker.service network-online.target avahi-daemon.service
Requires=docker.service network-online.target
Wants=avahi-daemon.service

[Service]
WorkingDirectory=${PWD}/Docker/
Type=oneshot
RemainAfterExit=yes

# Restart avahi to clear any stale mDNS registrations before starting
ExecStartPre=/bin/systemctl restart avahi-daemon
ExecStartPre=${PWD}/wait-for-avahi.sh

#ExecStartPre=/bin/docker-compose pull --quiet
ExecStart=/bin/docker-compose up -d

# Properly stop the container and restart avahi to clean up mDNS
ExecStop=/bin/docker-compose down
ExecStopPost=/bin/systemctl restart avahi-daemon

#ExecReload=/bin/docker-compose pull --quiet
ExecReload=/bin/docker-compose up -d

[Install]
WantedBy=multi-user.target

