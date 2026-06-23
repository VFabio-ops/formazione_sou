FROM docker.io/jenkins/inbound-agent:rhel-ubi9-jdk25

USER root

RUN dnf install -y --nodocs --setopt install_weak_deps=false slirp4netns podman shadow-utils jq git && \
    dnf clean all && \
    rm -rf /var/cache/dnf && \
    echo "[engine]" > /etc/containers/containers.conf && \
    echo "cgroup_manager = 'cgroupfs'" >> /etc/containers/containers.conf && \
    echo "events_logger = 'file'" >> /etc/containers/containers.conf 

ARG HELM_VERSION=3.15.4
RUN curl -fsSL -o /tmp/helm.tar.gz https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz \
    && tar -zxvf /tmp/helm.tar.gz -C /tmp \
    && mv /tmp/linux-amd64/helm /usr/local/bin/helm \
    && rm -rf /tmp/helm.tar.gz /tmp/linux-amd64

VOLUME ["/home/jenkins/agent"]