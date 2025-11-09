FROM nginx:latest

# Install git for runtime repo updates
RUN apt-get update \
    && apt-get install -y git \
    && rm -rf /var/lib/apt/lists/*

# Copy SSL certificates
COPY ./ssl/cert.pem /etc/nginx/ssl/cert.pem
COPY ./ssl/key.pem /etc/nginx/ssl/key.pem

# Copy custom nginx configuration
COPY ./nginx.conf /etc/nginx/nginx.conf

# Copy repo shell script
COPY ./update_repo.sh /usr/local/bin/update_repo.sh

# Make sure the script is executable
RUN chmod +x /usr/local/bin/update_repo.sh

# Run the repo update script and then start nginx in foreground
CMD ["/bin/sh", "-c", "/usr/local/bin/update_repo.sh && nginx -g 'daemon off;'"]
