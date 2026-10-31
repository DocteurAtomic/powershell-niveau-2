# The remote host of the course (module 8) and the webhook test server (module 9).
# Microsoft publishes no PowerShell 7.6 image, and its images have no sshd: this one is
# Ubuntu 24.04 with OpenSSH and the official PowerShell 7.6.9 archive, checked by its hash.
FROM ubuntu:24.04
ARG PWSH_VERSION=7.6.9
ARG PWSH_SHA256=1da6d6d6035d651f20e70ddee7c4c15ac6ab8b9fb40ee92240d91263f28a884b
RUN apt-get update \
 && apt-get install -y --no-install-recommends openssh-server ca-certificates curl libicu74 \
 && rm -rf /var/lib/apt/lists/* \
 && curl -fsSL -o /tmp/pwsh.tar.gz "https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/powershell-${PWSH_VERSION}-linux-x64.tar.gz" \
 && echo "${PWSH_SHA256}  /tmp/pwsh.tar.gz" | sha256sum -c - \
 && mkdir -p /opt/pwsh && tar xzf /tmp/pwsh.tar.gz -C /opt/pwsh && chmod +x /opt/pwsh/pwsh \
 && ln -s /opt/pwsh/pwsh /usr/bin/pwsh && rm /tmp/pwsh.tar.gz \
 && useradd --create-home --shell /bin/bash student \
 && mkdir -p /run/sshd /home/student/.ssh && chmod 700 /home/student/.ssh \
 && chown student:student /home/student/.ssh
COPY sshd_config /etc/ssh/sshd_config.d/course.conf
COPY webhook.ps1 /opt/course/webhook.ps1
COPY entrypoint.sh /opt/course/entrypoint.sh
EXPOSE 22 8080
ENTRYPOINT ["/bin/sh", "/opt/course/entrypoint.sh"]
