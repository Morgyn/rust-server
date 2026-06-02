FROM ubuntu:25.04 AS build

#  _         _ _    _ 
# | |__ _  _(_) |__| |
# | '_ \ || | | / _` |
# |_.__/\_,_|_|_\__,_|

ENV NODE_ENV production

RUN apt-get update && apt-get upgrade -y && apt-get dist-upgrade -y && apt-get autoremove -y

RUN apt-get install -y \
    nodejs \
    unzip \
    npm \
    wget \
    jq
 
COPY apps /app/
WORKDIR /app/

# Create merged package.json from all apps and install
# This is to only install each package once, and keep image smaller
RUN jq -s 'reduce .[] as $d ({}; . *= $d)' */package.json >package.json &&\
    npm install
#    npm ci --only=production

# Install Depot Downloader    
RUN mkdir -p /depotdownloader
WORKDIR /depotdownloader/

RUN wget -O /tmp/DepotDownloader-linux-x64.zip https://github.com/SteamRE/DepotDownloader/releases/latest/download/DepotDownloader-linux-x64.zip &&\
    unzip /tmp/DepotDownloader-linux-x64.zip

FROM ubuntu:25.04

LABEL org.opencontainers.image.authors="morgyn@gmail.com"

#               _   _           
#  _ _ _  _ _ _| |_(_)_ __  ___ 
# | '_| || | ' \  _| | '  \/ -_)
# |_|  \_,_|_||_\__|_|_|_|_\___|

ENV NODE_ENV production

COPY --from=build /app/ /app/
COPY --from=build /depotdownloader/ /depotdownloader/

RUN mkdir -p /rust

RUN apt-get update && \
    apt-get install -y \
        nodejs \
        busybox 

RUN busybox --install    

RUN ln -s /app/rcon_app/app.js /usr/bin/rcon

# Copy the Rust startup script
ADD start_rust.sh /app/start_rust.sh
RUN chmod +x /app/start_rust.sh /usr/bin/rcon

# Set the current working directory
WORKDIR /

# Run as a non-root user by default
ENV PGID 1000
ENV PUID 1000

# Setup default environment variables for the server
ENV RUST_SERVER_STARTUP_ARGUMENTS "-batchmode -load +server.secure 1"
ENV RUST_SERVER_IDENTITY "docker"
ENV RUST_SERVER_PORT ""
ENV RUST_SERVER_QUERYPORT ""
ENV RUST_SERVER_SEED "50000"
ENV RUST_SERVER_NAME "Rust Server [DOCKER]"
ENV RUST_SERVER_DESCRIPTION "Rust Server"
ENV RUST_SERVER_URL ""
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
ENV RUST_SERVER_WORLDSIZE "4250"
ENV RUST_SERVER_MAXPLAYERS "50"
ENV RUST_SERVER_SAVE_INTERVAL "600"

# Define directories to take ownership of
ENV CHOWN_DIRS "/app,/rust,/depotdownloader"

# Start the server
CMD [ "bash", "/app/start_rust.sh"]