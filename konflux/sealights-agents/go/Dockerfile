FROM registry.redhat.io/ubi9/go-toolset:latest

USER root

# Installs Sealights Go agent and Sealights CLI
RUN wget -qO- https://agents.sealights.co/slgoagent/v1.1.80/slgoagent-linux-amd64.tar.gz | tar -xzv -C /usr/local/bin
RUN wget -qO- https://agents.sealights.co/slcli/v1.0.36/slcli-linux-amd64.tar.gz | tar -xzv -C /usr/local/bin

USER 1001