#!/usr/bin/env bash
sudo ln -sf /opt/info-app/info-app.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now info-app
