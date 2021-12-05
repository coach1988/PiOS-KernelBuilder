FROM debian:bullseye-slim

# Get prerequisites
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates kmod git gcc bc bison flex libssl-dev make libc6-dev libncurses5-dev crossbuild-essential-armhf crossbuild-essential-arm64 && \
    rm -rf /var/lib/apt/lists/*

# Add start script
COPY ./scripts/entryPoint.sh /entryPoint.sh

RUN mkdir /app && \
    chmod u+x /entryPoint.sh

WORKDIR /app

ENTRYPOINT ["/bin/bash"]
CMD ["/entryPoint.sh"]
