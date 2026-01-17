FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl wget jq bash sudo sqlite3 ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create x-ui directory
RUN mkdir -p /usr/local/x-ui

# Set working directory
WORKDIR /usr/local/x-ui

# Copy installation script
COPY scripts/install-xui.sh /tmp/install-xui.sh
RUN chmod +x /tmp/install-xui.sh

# Install x-ui (will be done in entrypoint if not exists)
COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Copy initialization script
COPY scripts/init-xui.sh /usr/local/bin/init-xui.sh
RUN chmod +x /usr/local/bin/init-xui.sh

# Copy extras installation script
COPY scripts/install-extras.sh /usr/local/bin/install-extras.sh
RUN chmod +x /usr/local/bin/install-extras.sh

# Expose ports
EXPOSE 2053 8443 8080

ENTRYPOINT ["/entrypoint.sh"]
CMD ["x-ui"]
