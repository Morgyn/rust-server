FROM node:bookworm-slim

LABEL org.opencontainers.image.authors="morgyn@gmail.com"

RUN apt-get update && apt-get upgrade -y && apt-get dist-upgrade -y && apt-get autoremove -y

RUN apt-get install -y \
    lib32gcc-s1 \
    lib32stdc++6 \
    expect \
    curl \
    tar \
    jq
 
COPY apps /app/
WORKDIR /app/

RUN jq -s 'reduce .[] as $d ({}; . *= $d)' */package.json >package.json &&\
    npm install

RUN ln -s /app/rcon_app/app.js /usr/bin/rcon

# Add the steamcmd installation script
ADD install.txt /app/install.txt

# Copy the Rust startup script
ADD start_rust.sh /app/start.sh

# Copy the Rust update check script
ADD update_check.sh /app/update_check.sh

# Copy extra files
COPY README.md LICENSE.md /app/

# Set the current working directory
WORKDIR /

# Run as a non-root user by default
ENV PGID 1000
ENV PUID 1000

# Setup default environment variables for the server
ENV RUST_SERVER_STARTUP_ARGUMENTS "-batchmode -load -nographics +server.secure 1"
ENV RUST_SERVER_IDENTITY "docker"
ENV RUST_SERVER_PORT ""
ENV RUST_SERVER_QUERYPORT ""
ENV RUST_SERVER_SEED "12345"
ENV RUST_SERVER_NAME "Rust Server [DOCKER]"
ENV RUST_SERVER_DESCRIPTION "This is a Rust server running inside a Docker container!"
ENV RUST_SERVER_URL "https://hub.docker.com/r/didstopia/rust-server/"
ENV RUST_SERVER_BANNER_URL ""
ENV RUST_RCON_WEB "1"
ENV RUST_RCON_PORT "28016"
ENV RUST_RCON_PASSWORD "docker"
ENV RUST_APP_PORT "28082"
ENV RUST_UPDATE_CHECKING "0"
ENV RUST_HEARTBEAT "0"
ENV RUST_UPDATE_BRANCH "public"
ENV RUST_START_MODE "0"
ENV RUST_OXIDE_ENABLED "0"
ENV RUST_OXIDE_UPDATE_ON_BOOT "1"
ENV RUST_RCON_SECURE_WEBSOCKET "0"
ENV RUST_SERVER_WORLDSIZE "3500"
ENV RUST_SERVER_MAXPLAYERS "500"
ENV RUST_SERVER_SAVE_INTERVAL "600"

# Define directories to take ownership of
ENV CHOWN_DIRS "/app,/steamcmd,/usr/share/nginx/html,/var/log/nginx"

# Expose the volumes
# VOLUME [ "/steamcmd/rust" ]

# Start the server
CMD [ "bash", "/app/start.sh"]
