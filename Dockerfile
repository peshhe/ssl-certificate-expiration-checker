FROM alpine:latest

ENV SLACK_WEBHOOK_URL=""

# Create and select the application's directory
WORKDIR /app

# Copy the script and make it executable
COPY --chmod=0754 certificate-checker.sh websites.conf /app/

# Install required packages, add user and group, then remove cache
RUN addgroup -g 1001 -S cert-group && \
    adduser -u 1001 -S cert-user -G cert-group && \
    apk update && \
    apk add --no-cache \
        bash \
        tzdata \
        openssl \
        coreutils \
        curl && \
    rm -rf /var/cache/apk/*

# Change ownership of the application directory
RUN chown -R cert-user:cert-group /app

# Switch to the non-root user previously created
USER cert-user

# Set default command
CMD ["/app/certificate-checker.sh"]
