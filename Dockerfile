FROM ubuntu:latest

RUN apt-get update \
	&& apt-get install -y \
	curl \
	gnupg \
	lsb-release \
	net-tools \
	dante-server \
	sudo \
	iproute2 \
	&& apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN mkdir /var/log/danted/ /etc/warp/

COPY danted/danted.conf /etc/
COPY warp/start.sh /etc/warp/start.sh

RUN chmod +x /etc/warp/start.sh

# Add Cloudflare GPG key
RUN curl https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg

# Add the Cloudflare repository
RUN echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflare-client.list

# Install Cloudflare Warp
RUN apt-get update && apt-get install -y cloudflare-warp

CMD ["/bin/bash", "/etc/warp/start.sh"]