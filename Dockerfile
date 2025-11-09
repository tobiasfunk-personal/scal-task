FROM nginx:latest

# Install git for runtime repo updates
RUN apt-get update \
    && apt-get install -y git iputils-ping dnsutils curl \
    && rm -rf /var/lib/apt/lists/*

# Copy SSL certificates (expects ./certs to contain fullchain.pem and privkey.pem)
COPY ./certs /etc/nginx/certs

# Copy custom nginx configuration
COPY ./nginx.conf /etc/nginx/nginx.conf

# Copy repo shell script
COPY ./update_repo.sh /usr/local/bin/update_repo.sh

# Make sure the script is executable
RUN chmod +x /usr/local/bin/update_repo.sh

# Run the repo update script and then start nginx in foreground
CMD ["/bin/sh", "-c", "/usr/local/bin/update_repo.sh && nginx -g 'daemon off;'"]
