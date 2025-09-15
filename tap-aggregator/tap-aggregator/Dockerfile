FROM ghcr.io/semiotic-ai/tap_aggregator:sha-d38d0b9
RUN apt-get update \
    && apt-get install -y jq \
    && rm -rf /var/lib/apt/lists/*

COPY ./run.sh /opt/run.sh
ENTRYPOINT sh -cl /opt/run.sh
