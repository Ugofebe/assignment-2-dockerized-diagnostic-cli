FROM ubuntu:22.04

# Install only the tools the subcommands and health probe need, then drop the
# apt package index so it does not inflate the image layer.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        iproute2 \
        iputils-ping \
        dnsutils \
        procps \
        netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY app/ /app/

RUN chmod +x /app/diagnostic.sh /app/health-check.sh

ENTRYPOINT ["/app/diagnostic.sh"]
CMD ["help"]
