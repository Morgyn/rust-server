#!/usr/bin/env bash

# Enable debugging
# set -x

# Define the exit handler
exit_handler()
{
	echo "Shutdown signal received"

    ## TODO: Make shutdown into a bash function
	# Execute the RCON shutdown command
	node /app/shutdown_app/app.js
	SHUTDOWN_PID=$!
	wait "$SHUTDOWN_PID"

	echo "Exiting.."
	exit 0
}

# Define the install/update function
install_or_update()
{
	INSTALL_ARGS=()
	INSTALL_ARGS+=("-app 258550")
	# INSTALL_ARGS+=("-depot 258552")
	INSTALL_ARGS+=("-dir /rust/")
	if [[ -n "${RUST_BRANCH}" && "${RUST_BRANCH}" != "public" ]]; then
		INSTALL_ARGS+=("-beta ${RUST_BRANCH}")
	fi
	INSTALL_ARGS+=("-validate")

	# Install Rust
	echo "Installing or updating Rust.."
	/depotdownloader/DepotDownloader "${INSTALL_ARGS[@]}"

	# Terminate if exit code wasn't zero
	if [ $? -ne 0 ]; then
		echo "Exiting, depot downloader install or update failed!"
		exit 1
	fi
}

# Preparing arguments
function add_argument_pair {
        local -n arr=$1
        if  [ ! -z "${!3}" ]; then
                  arr+=("${2}");
                  arr+=("${!3}");
        fi
}

# Print the user we're currently running as
echo "Running as user: $(whoami)"

# Update SSL just in case
apt-get install -y ca-certificates
update-ca-certificates --fresh

# Trap specific signals and forward to the exit handler
trap 'exit_handler' SIGINT SIGTERM

# Remove old lock files (used by restart_app/ and update_check.sh)
rm -fr /tmp/*.lock

# Create the necessary folder structure
if [ ! -d "/rust/server/${RUST_SERVER_IDENTITY}" ]; then
	echo "Missing /rust/server/${RUST_SERVER_IDENTITY}, creating.."
	mkdir -p "/rust/server/${RUST_SERVER_IDENTITY}"
fi

# Disable auto-update if start mode is 2
if [ "$RUST_START_MODE" = "2" ] && [ -f "/rust/RustDedicated" ]; then	
	echo "Rust Start Mode set to 2 (Don't Update), Rust installed, skipping update.."
else
	install_or_update
fi

# Check if Oxide is enabled
if [ "$RUST_OXIDE_ENABLED" = "1" ]; then
	# Next check if Oxide doesn't exist, or if we want to always update it
	if [ ! -f "/rust/RustDedicated_Data/Managed/Oxide.Core.dll" ] || [ "$RUST_OXIDE_UPDATE_ON_BOOT" = "1" ]; then
		
		OXIDE_URL="https://umod.org/games/rust/download/develop"
		if [ "$RUST_OXIDE_GITHUB" = "1" ]; then
			OXIDE_URL="https://github.com/OxideMod/Oxide.Rust/releases/latest/download/Oxide.Rust-linux.zip"
		fi

		echo "Downloading and installing latest Oxide... (${OXIDE_URL})"

		OXIDE_TEMP="$(mktemp)" && \
			wget -O "${OXIDE_TEMP}" "${OXIDE_URL}" && \
			unzip -o "${OXIDE_TEMP}" -d "/rust/" && \
			rm -f "${OXIDE_TEMP}" || \
			echo "Download and install of oxide FAILED"
	fi
fi

# Start mode 1 means we only want to update
if [ "$RUST_START_MODE" = "1" ]; then
	echo "Exiting, Start Mode is 1 (Update Only).."
	exit 0
fi

# Remove extra whitespace from startup command
RUST_STARTUP_COMMAND=$(echo "$RUST_SERVER_STARTUP_ARGUMENTS" | tr -s " ")

# Add RCON support if necessary
if [ ! -z ${RUST_RCON_PORT+x} ]; then
	RUST_STARTUP_COMMAND="$RUST_STARTUP_COMMAND +rcon.port $RUST_RCON_PORT"
fi
if [ ! -z ${RUST_RCON_PASSWORD+x} ]; then
	RUST_STARTUP_COMMAND="$RUST_STARTUP_COMMAND +rcon.password $RUST_RCON_PASSWORD"
fi

# Disable logrotate if "-logfile" is set in $RUST_STARTUP_COMMAND
LOGROTATE_ENABLED=1
if [[ "${RUST_STARTUP_COMMAND,,}" == *" -logfile "* ]]; then
	LOGROTATE_ENABLED=0
fi

if [ "$LOGROTATE_ENABLED" = "1" ]; then
	echo "Log rotation enabled!"

	# Log to stdout by default
	RUST_STARTUP_COMMAND="${RUST_STARTUP_COMMAND} -logfile /dev/stdout"
	echo "Using startup arguments: ${RUST_SERVER_STARTUP_ARGUMENTS}"

	# Create the logging directory structure
	if [ ! -d "/rust/logs/archive" ]; then
		mkdir -p /rust/logs/archive
	fi

	# Set the logfile filename/path
	DATE=`date '+%Y-%m-%d_%H-%M-%S'`
	RUST_SERVER_LOG_FILE="/rust/logs/${RUST_SERVER_IDENTITY}_${DATE}.txt"

	# Archive old logs
	echo "Cleaning up old logs.."
	mv /rust/logs/*.txt /rust/logs/archive | true
else
	echo "Log rotation disabled!"
fi

# Disable logging to stdout/stderr if "-logfile /dev/" is used
STDLOG_ENABLED=1
if [[ "${RUST_STARTUP_COMMAND,,}" == *" -logfile /dev/"* ]]; then
	echo "Disabling internal stdout/stderr logging!"
	STDLOG_ENABLED=0
fi

# Set the working directory
cd /rust

# Run the server
echo "Starting Rust.."

# If levelurl is set, generate a seed hashed off the url
if [ ! -z "${RUST_LEVELURL}" ]; then
	RUST_LEVELURL_CRC=$(echo "${RUST_LEVELURL}" | cksum | cut -c 1-8)
fi

ARGUMENTS=()

add_argument_pair ARGUMENTS "+server.port" "RUST_SERVER_PORT"
add_argument_pair ARGUMENTS "+server.queryport" "RUST_SERVER_QUERYPORT"
add_argument_pair ARGUMENTS "+server.identity" "RUST_SERVER_IDENTITY"

if [ -z "${RUST_LEVELURL}" ]; then
	add_argument_pair ARGUMENTS "+server.worldsize" "RUST_SERVER_WORLDSIZE"
	add_argument_pair ARGUMENTS "+server.seed" "RUST_SERVER_SEED"
else
	add_argument_pair ARGUMENTS "+server.levelurl" "RUST_LEVELURL"
	add_argument_pair ARGUMENTS "+server.seed" "RUST_LEVELURL_CRC"
fi

add_argument_pair ARGUMENTS "+server.hostname" "RUST_SERVER_NAME"
add_argument_pair ARGUMENTS "+server.url" "RUST_SERVER_URL"
add_argument_pair ARGUMENTS "+server.headerimage" "RUST_SERVER_BANNER_URL"
add_argument_pair ARGUMENTS "+server.description" "RUST_SERVER_DESCRIPTION"
add_argument_pair ARGUMENTS "+server.maxplayers" "RUST_SERVER_MAXPLAYERS"
add_argument_pair ARGUMENTS "+server.saveinterval" "RUST_SERVER_SAVE_INTERVAL"
add_argument_pair ARGUMENTS "+app.port" "RUST_APP_PORT"

chmod +x /rust/RustDedicated

# Rust includes a 64-bit version of steamclient.so, so we need to tell the OS where it exists
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/rust/RustDedicated_Data/Plugins/x86_64

if [ "$LOGROTATE_ENABLED" = "1" ]; then
	stdbuf -oL /rust/RustDedicated "${RUST_STARTUP_COMMAND}" "${ARGUMENTS[@]}" 2>&1 | grep --line-buffered -Ev '^\s*$|Filename' | tee $RUST_SERVER_LOG_FILE &
elif [ "$STDLOG_ENABLED" = "1" ]; then
	/rust/RustDedicated "${RUST_STARTUP_COMMAND}" "${ARGUMENTS[@]}" 2>&1 &
else
	/rust/RustDedicated "${RUST_STARTUP_COMMAND}" "${ARGUMENTS[@]}" &
fi

child=$!
wait "$child"

echo "Exiting.."
exit 0