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
ExecStartPre=/bin/bash -c 'TIMEOUT=30; ELAPSED=0; until systemctl is-active --quiet avahi-daemon; do if [ $${ELAPSED} -ge $${TIMEOUT} ]; then echo "ERROR: Avahi did not become ready within 30s"; exit 1; fi; sleep 1; ELAPSED=$$((ELAPSED+1)); done; echo "Avahi is ready after $${ELAPSED} seconds"'

#ExecStartPre=/bin/docker-compose pull --quiet
ExecStart=/bin/docker-compose up -d

# Properly stop the container and restart avahi to clean up mDNS
ExecStop=/bin/docker-compose down
ExecStopPost=/bin/systemctl restart avahi-daemon

#ExecReload=/bin/docker-compose pull --quiet
ExecReload=/bin/docker-compose up -d

[Install]
WantedBy=multi-user.target

