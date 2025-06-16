#!/bin/bash
#
# Author: nano

uname -a

# if [ ! -f "nezha-agent" ]; then
#     curl -LO https://github.com/nezhahq/agent/releases/latest/download/nezha-agent_linux_amd64.zip
#     unzip nezha-agent_linux_amd64.zip nezha-agent
#     rm nezha-agent_linux_amd64.zip
# fi

# if [ ! -f "cloudflared" ]; then
#     curl -L -o cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
# fi

# if [ ! -f "xray" ]; then
#     curl -LO https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
#     unzip Xray-linux-64.zip xray
#     rm Xray-linux-64.zip
# fi

is_nz_running="false"
is_xray_running="false"
is_cf_running="false"

for pid_path in /proc/[0-9]*/; do
    if [ -r "${pid_path}cmdline" ]; then
        pid="${pid_path//[^0-9]/}"
        cmdline_file="${pid_path}cmdline"
        cmdline_output=$(xargs -0 < "$cmdline_file" 2>/dev/null)
        if echo "$cmdline_output" | grep -q "nezha-agent"; then
            # kill -9 "$pid"
            is_nz_running="true"
        fi
        if echo "$cmdline_output" | grep -q "xray"; then
            # kill -9 "$pid"
            is_xray_running="true"
        fi
        if echo "$cmdline_output" | grep -q "cloudflared"; then
            # kill -9 "$pid"
            is_cf_running="true"
        fi
    fi
done

echo
echo "is_nz_running: $is_nz_running"
echo
echo "is_xray_running: $is_xray_running"
echo
echo "is_cf_running: $is_cf_running"
echo

###########################################

export NZ_SERVER=${NZ_SERVER:-""}
export NZ_CLIENT_SECRET=${NZ_CLIENT_SECRET:-""}
export NZ_TLS=${NZ_TLS:-"true"}
export NZ_INSECURE_TLS=${NZ_INSECURE_TLS:-"false"}
export NZ_DISABLE_AUTO_UPDATE=${NZ_DISABLE_AUTO_UPDATE:-"true"}
export NZ_UUID=${NZ_UUID:-""}

CF_TOKEN=${CF_TOKEN:-""}

# 节点信息，除端口和对应的域名外只有需要固定密码才设置，否则随机，随机母鸡重启将重置密码
XRAY_ID=${XRAY_ID:-""}
VLESS_XHTTP_PORT=${VLESS_XHTTP_PORT:-"3001"}
VLESS_XHTTP_DOMAIN=${VLESS_XHTTP_DOMAIN:-""}
VMESS_XHTTP_PORT=${VMESS_XHTTP_PORT:-"3002"}
VMESS_XHTTP_DOMAIN=${VMESS_XHTTP_DOMAIN:-""}
XHTTP_PATH=${XHTTP_PATH:-""}
WS_PORT=${WS_PORT:-"3003"}
WS_DOMAIN=${WS_DOMAIN:-""}
VLESS_WS_PATH=${VLESS_WS_PATH:-""}
VMESS_WS_PATH=${VMESS_WS_PATH:-""}
TROJAN_WS_PATH=${TROJAN_WS_PATH:-""}

###########################################

if [ "$is_nz_running" = "false" ]; then
    chmod +x nezha-agent
    ./nezha-agent service -c config.yml install &>/dev/null
    nohup ./nezha-agent -c config.yml &>/dev/null &
fi

if [ "$is_cf_running" = "false" ]; then
    chmod +x cloudflared
    nohup ./cloudflared tunnel run --token "$CF_TOKEN" &>/dev/null &
fi

gen_xray_config() {
    XRAY_ID=${XRAY_ID:-"$(./xray uuid)"}

    if [ "$XHTTP_PATH" = "" ]; then
        XHTTP_PATH=$(./xray uuid)
        XHTTP_PATH=${XHTTP_PATH:0:8}
    fi

    if [ "$VLESS_WS_PATH" = "" ]; then
        VLESS_WS_PATH=$(./xray uuid)
        VLESS_WS_PATH=${VLESS_WS_PATH:0:8}
    fi

    if [ "$VMESS_WS_PATH" = "" ]; then
        VMESS_WS_PATH=$(./xray uuid)
        VMESS_WS_PATH=${VMESS_WS_PATH:0:8}
    fi

    if [ "$TROJAN_WS_PATH" = "" ]; then
        TROJAN_WS_PATH=$(./xray uuid)
        TROJAN_WS_PATH=${TROJAN_WS_PATH:0:8}
    fi

    echo "{
    \"inbounds\": [
        {
            \"listen\": \"::\",
            \"port\": $VLESS_XHTTP_PORT,
            \"protocol\": \"vless\",
            \"settings\": {
                \"clients\": [
                    {
                        \"id\": \"$XRAY_ID\"
                    }
                ],
                \"decryption\": \"none\"
            },
            \"streamSettings\": {
                \"network\": \"xhttp\",
                \"security\": \"none\",
                \"xhttpSettings\": {
                    \"path\": \"$XHTTP_PATH\"
                }
            }
        },
        {
            \"listen\": \"::\",
            \"port\": $VMESS_XHTTP_PORT,
            \"protocol\": \"vmess\",
            \"settings\": {
                \"clients\": [
                    {
                        \"id\": \"$XRAY_ID\"
                    }
                ]
            },
            \"streamSettings\": {
                \"network\": \"xhttp\",
                \"security\": \"none\",
                \"xhttpSettings\": {
                    \"path\": \"$XHTTP_PATH\"
                }
            }
        },
        {
            \"listen\": \"::\",
            \"port\": $WS_PORT,
            \"protocol\": \"vless\",
            \"settings\": {
                \"clients\": [
                    {
                        \"id\": \"$XRAY_ID\"
                    }
                ],
                \"decryption\": \"none\",
                \"fallbacks\": [
                    {
                        \"dest\": $(($WS_PORT+1)),
                        \"path\": \"/$VLESS_WS_PATH\",
                        \"xver\": 1
                    },
                    {
                        \"dest\": $(($WS_PORT+2)),
                        \"path\": \"/$VMESS_WS_PATH\",
                        \"xver\": 1
                    },
                    {
                        \"dest\": $(($WS_PORT+3)),
                        \"path\": \"/$TROJAN_WS_PATH\",
                        \"xver\": 1
                    }
                ]
            },
            \"streamSettings\": {
                \"network\": \"raw\",
                \"security\": \"none\"
            }
        },
        {
            \"listen\": \"::\",
            \"port\": $(($WS_PORT+1)),
            \"protocol\": \"vless\",
            \"settings\": {
                \"clients\": [
                    {
                        \"id\": \"$XRAY_ID\"
                    }
                ],
                \"decryption\": \"none\"
            },
            \"streamSettings\": {
                \"network\": \"ws\",
                \"security\": \"none\",
                \"wsSettings\": {
                    \"path\": \"$VLESS_WS_PATH\",
                    \"acceptProxyProtocol\": true
                }
            }
        },
        {
            \"listen\": \"::\",
            \"port\": $(($WS_PORT+2)),
            \"protocol\": \"vmess\",
            \"settings\": {
                \"clients\": [
                    {
                        \"id\": \"$XRAY_ID\"
                    }
                ]
            },
            \"streamSettings\": {
                \"network\": \"ws\",
                \"security\": \"none\",
                \"wsSettings\": {
                    \"path\": \"$VMESS_WS_PATH\",
                    \"acceptProxyProtocol\": true
                }
            }
        },
        {
            \"listen\": \"::\",
            \"port\": $(($WS_PORT+3)),
            \"protocol\": \"trojan\",
            \"settings\": {
                \"clients\": [
                    {
                        \"password\": \"$XRAY_ID\"
                    }
                ]
            },
            \"streamSettings\": {
                \"network\": \"ws\",
                \"security\": \"none\",
                \"wsSettings\": {
                    \"path\": \"$TROJAN_WS_PATH\",
                    \"acceptProxyProtocol\": true
                }
            }
        }
    ],
    \"outbounds\": [
        {
            \"protocol\": \"freedom\"
        }
    ]
}" > config.json

    vmess_xhttp_config="{
  \"v\": \"2\",
  \"ps\": \"vmess xhttp\",
  \"add\": \"ip.sb\",
  \"port\": \"80\",
  \"id\": \"$XRAY_ID\",
  \"aid\": \"0\",
  \"scy\": \"auto\",
  \"net\": \"xhttp\",
  \"type\": \"packet-up\",
  \"host\": \"$VMESS_XHTTP_DOMAIN\",
  \"path\": \"$XHTTP_PATH\",
  \"tls\": \"\",
  \"sni\": \"\",
  \"alpn\": \"\",
  \"fp\": \"\"
}"
    vless_xhttp_link="vless://${XRAY_ID}@ip.sb:443?encryption=none&security=tls&type=xhttp&host=${VLESS_XHTTP_DOMAIN}&path=${XHTTP_PATH}&mode=packet-up#vless xhttp"
    vmess_xhttp_link="vmess://$(echo -n "$vmess_xhttp_config" | base64 -w 0)"
    
    vmess_ws_config="{
  \"v\": \"2\",
  \"ps\": \"vmess ws\",
  \"add\": \"ip.sb\",
  \"port\": \"80\",
  \"id\": \"$XRAY_ID\",
  \"aid\": \"0\",
  \"scy\": \"auto\",
  \"net\": \"ws\",
  \"type\": \"none\",
  \"host\": \"$WS_DOMAIN\",
  \"path\": \"$VMESS_WS_PATH\",
  \"tls\": \"\",
  \"sni\": \"\",
  \"alpn\": \"\",
  \"fp\": \"\"
}"
    vless_ws_link="vless://${XRAY_ID}@ip.sb:443?encryption=none&security=tls&type=ws&host=${WS_DOMAIN}&path=${VLESS_WS_PATH}#vless ws"
    vmess_ws_link="vmess://$(echo -n "$vmess_ws_config" | base64 -w 0)"
    trojan_ws_link="trojan://${XRAY_ID}@ip.sb:443?security=tls&type=ws&host=${WS_DOMAIN}&path=${TROJAN_WS_PATH}#trojan ws"

    echo -e "${vless_xhttp_link}\n${vmess_xhttp_link}\n${vless_ws_link}\n${vmess_ws_link}\n${trojan_ws_link}" | base64 -w 0 > links.txt
}

if [ "$is_xray_running" = "false" ]; then
    chmod +x xray
    gen_xray_config
    nohup ./xray &>/dev/null &
fi

####################################################

for pid_path in /proc/[0-9]*/; do
    if [ -r "${pid_path}cmdline" ]; then
        pid="${pid_path//[^0-9]/}"
        echo -n "${pid}: "
        xargs -0 < "${pid_path}cmdline"
        echo
    fi
done

commands=("curl" "unzip" "ps" "ip" "hostname" "pkill" "grep" "openssl" "base64")
for cmd in "${commands[@]}"; do
    echo -n "$cmd "
    if command -v "$cmd" &> /dev/null; then
        echo "存在"
    else
        echo "不存在"
    fi
    echo
done