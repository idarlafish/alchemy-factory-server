#!/usr/bin/env bash
# Shared settings and helpers. Sourced by every other script.

SERVER_DIR="${SERVER_DIR:-/data/server}"
DATA_DIR="${DATA_DIR:-/data}"
PROTON_DIR="${PROTON_DIR:-/opt/proton}"
STEAMCMDDIR="${STEAMCMDDIR:-/home/steam/steamcmd}"
STEAM_APP_ID="${STEAM_APP_ID:-4550060}"
GAME_APP_ID="${GAME_APP_ID:-3669570}"
CONFIG_NAME="${CONFIG_NAME:-ServerConfig.ini}"
SERVER_BINARY="${SERVER_BINARY:-AlchemyFactory/Binaries/Win64/AlchemyFactoryServer-Win64-Shipping.exe}"
RESTART_FLAG="${DATA_DIR}/.scheduled-restart"
export SERVER_DIR DATA_DIR PROTON_DIR STEAMCMDDIR STEAM_APP_ID GAME_APP_ID
export CONFIG_NAME SERVER_BINARY RESTART_FLAG

log() { echo "==> $*"; }
