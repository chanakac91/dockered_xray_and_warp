#!/bin/bash

# Change system configurations
rm -rf /etc/localtime
cp /usr/share/zoneinfo/Asia/Colombo /etc/localtime
date -R
sudo sed -i "s/#\$nrconf{restart} = 'i'/\$nrconf{restart} = 'a'/" /etc/needrestart/needrestart.conf

# install docker
sudo apt update -y && apt upgrade -y
sudo apt install -y docker.io docker-compose

NAME="portainer"

# Install Portainer
if [ ! "$(docker ps -q -f name=$NAME)" ]; then
    docker volume create portainer_data
    docker run -d -p 9000:9000 --name portainer --restart always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest
fi

NAME="xray"
IMAGE="teddysun/xray"

# Install xray
if [ ! "$(docker ps -q -f name=$NAME)" ]; then

    #input uuid
    echo -e "\e[96mEnter a valid gen4 UUID:\e[0m"
    read uuid

    rm -rf xray/config/config.json
cat << EOF > xray/config/config.json
{
    "log": {
        "access": "/var/log/xray/access.log",
        "error": "/var/log/xray/error.log",
        "loglevel": "warning",
        "dnsLog": false
    },
    "inbounds": [
        {
            "port": 80,
            "protocol": "vmess",
            "tag":"vmess",
            "settings": {
                "clients": [
                    {
                        "id": "$uuid",
                        "level": 0,
                        "alterId": 0,
                        "security": "auto",
                        "email": "admin@email.com"
                    }
                ]
            },
            "streamSettings": {
                "network": "ws",
                "wsSettings": {
                    "acceptProxyProtocol": false,
                    "path": "/vmess"
                },
                "tcpSettings": {
                    "header": {
                        "type": "http",
                        "response": {
                            "version": "1.1",
                            "status": "200",
                            "reason": "OK",
                            "headers": {
                                "Content-encoding": [
                                    "gzip"
                                ],
                                "Content-Type": [
                                    "text/html; charset=utf-8"
                                ],
                                "Cache-Control": [
                                    "no-cache"
                                ],
                                "Vary": [
                                    "Accept-Encoding"
                                ],
                                "X-Frame-Options": [
                                    "deny"
                                ],
                                "X-XSS-Protection": [
                                    "1; mode=block"
                                ],
                                "X-content-type-options": [
                                    "nosniff"
                                ]
                            }
                        }
                    }
                }
            },
            "sniffing": {
                "enabled": true,
                "destOverride": [
                    "http",
                    "tls"
                ]
            }
        },
        {
            "port": 443,
            "protocol": "vless",
            "tag":"vless",
            "settings": {
                "clients": [
                    { 
                        "id": "$uuid",
                        "flow": "xtls-rprx-vision",
                        "level": 0,
                        "email": "admin@email.com"
                    }
                ],
                "decryption": "none",
                "fallbacks": [
                    {
                        "dest": "www.baidu.com:80"
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "wsSettings": {
                    "acceptProxyProtocol": false,
                    "path": "/vless"
                },
                "security": "tls",
                "tlsSettings": {
                    "allowInsecure": true,
                    "certificates": [
                        {
                            "certificateFile": "/etc/xray/xray.crt",
                            "keyFile": "/etc/xray/xray.key"
                        }
                    ]
                },
                "xtlsSettings": {
                    "alpn": [
                        "http/1.1"
                    ],
                    "certificates": [
                        {
                            "certificateFile": "/etc/xray/xray.crt",
                            "keyFile": "/etc/xray/xray.key"
                        }
                    ]
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "socks",
            "tag": "warp",
            "settings": {
                "servers": [
                    {
                        "address": "localhost",
                        "port": 9050
                    }
                ]
            }
        },
        {
          "protocol": "freedom",
          "settings": {},
          "tag": "direct"
        }
    ],
    "routing": {
        "rules": [
            {
                "type": "field",
                "user": ["admin@email.com"],
                "outboundTag": "direct"
            }
            {
                "type": "field",
                "domain":[
                    "geosite:openai",
                    "ip.gs"
                ],
                "outboundTag": "warp"
            }
        ]
    }
}
EOF

    # Pull the image from dockerhub
    docker pull teddysun/xray

    # Coping xray files
    rm -rf /etc/xray /var/log/xray
    mkdir -p /etc/xray /var/log/xray
    cp xray/config/* /etc/xray/
    cp xray/logs/* /var/log/xray/

    # Generate certificates
    openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
    -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=www.example.com" \
    -keyout xray.key  -out xray.crt
    mv -t /etc/xray/ xray.key xray.crt
    chmod 644 /etc/xray/xray.key

    # create docker image
    docker run -d \
        --name "${NAME}" \
        --privileged \
        --interactive \
        --restart=always \
        -p 80:80 \
        -p 443:443 \
        -v /etc/xray:/etc/xray \
        -v "/var/log/xray/access.log:/var/log/xray/access.log" \
        -v "/var/log/xray/error.log:/var/log/xray/error.log" \
        $IMAGE
fi

NAME="warp"
IMAGE="warp"

# Install warp
if [ ! "$(docker ps -q -f name=$NAME)" ]; then

    docker build -t "$IMAGE" .
    
    docker run \
        --hostname "${NAME}" \
        --name "${NAME}" \
        --privileged \
        --interactive \
        --detach \
        --restart=always \
        -p 9050:1080 \
        $IMAGE
fi

pubip="$(dig +short myip.opendns.com @resolver1.opendns.com)"
if [ "$pubip" == "" ];then
    pubip=`ifconfig eth0 | awk 'NR==2 {print $2}'
fi
if [ "$pubip" == "" ];then
    pubip=`ifconfig ens3 | awk 'NR==2 {print $2}'
fi
if [ "$pubip" == "" ];then
    echo -e "\e[95mUnknown IP!.\e[0m" 1>&2
fi

echo " "
echo -e "\e[96mInstallation has been completed!!\e[0m"
echo " "
echo "Script from https://t.me/CHATHURANGA_91"
echo "Copyright mAX web™"
echo " "
echo "Server Information"
echo "   - IP address   : ${pubip}"
echo "   - VMESS        : 80"
echo "   - VLESS        : 443"
echo "   - Portainer    : 9000"
echo " "
echo " "