#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
#=================================================================#
#   System Required:  Debian8_x64                                   #
#   Description: One click Install lkl-bbr kcp               #
#   Adapt from: 91yun <https://twitter.com/91yun>                     #
#   Thanks: @linrong                            #
#=================================================================#

if [[ $EUID -ne 0 ]]; then
   echo "Error:This script must be run as root!" 1>&2
   exit 1
fi


Get_Dist_Name()
{
    if grep -Eqi "CentOS" /etc/issue || grep -Eq "CentOS" /etc/*-release; then
        release='CentOS'
    elif grep -Eqi "Debian" /etc/issue || grep -Eq "Debian" /etc/*-release; then
        release='Debian'
    elif grep -Eqi "Ubuntu" /etc/issue || grep -Eq "Ubuntu" /etc/*-release; then
        release='Ubuntu'
	else
        release='unknow'
    fi
    
}
Get_Dist_Name
function getversion(){
    if [[ -s /etc/redhat-release ]];then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else    
        grep -oE  "[0-9.]+" /etc/issue
    fi    
}
ver=""
CentOSversion() {
    if [ "${release}" == "CentOS" ]; then
        local version="$(getversion)"
        local main_ver=${version%%.*}
		ver=$main_ver
    else
        ver="$(getversion)"
    fi
}
CentOSversion
Get_OS_Bit()
{
    if [[ `getconf WORD_BIT` = '32' && `getconf LONG_BIT` = '64' ]] ; then
        bit='x64'
    else
        bit='x32'
    fi
}
Get_OS_Bit

if [ "${release}" == "CentOS" ]; then
	yum install -y bc
else
	apt-get update
	apt-get install -y bc
fi

iddver=`ldd --version | grep ldd | awk '{print $NF}'`
dver=$(echo "$iddver < 2.14" | bc)
if [ $dver -eq 1 ]; then
	ldd --version
	echo "idd的版本低于2.14，系统不支持。请尝试Centos7，Debian8，Ubuntu16"
	exit 1
fi

if [ "$bit" -ne "x64" ]; then
	echo "脚本目前只支持64bit系统"
	exit 1
fi	

apt-get update
wget --no-check-certificate https://raw.githubusercontent.com/mishaelre/ovz-bbr-powered/master/rinetd
chmod +x rinetd

cat > /root/rinetd.conf<<-EOF
# bindadress bindport connectaddress connectport
0.0.0.0 443 0.0.0.0 443
EOF

cat > /etc/systemd/system/rinetd.service<<-EOF
[Unit]
Description=rinetd

[Service]
ExecStart=/root/rinetd -f -c /root/rinetd.conf raw venet0:0
Restart=always
  
[Install]
WantedBy=multi-user.target
EOF

systemctl enable rinetd.service && systemctl start rinetd.service

cd /root
mkdir /root/kcptun
cd /root/kcptun
wget --no-check-certificate https://github.com/xtaci/kcptun/releases/download/v20170329/kcptun-linux-amd64-20170329.tar.gz
tar -zxf kcptun-linux-amd64-*.tar.gz

cat > /root/kcptun/start.sh<<-EOF
#!/bin/bash
cd /root/kcptun/
./server_linux_amd64 -c /root/kcptun/server-config.json > kcptun.log 2>&1 &
echo "Kcptun started."
EOF

cat > /root/kcptun/server-config.json<<-EOF
{
    "listen": ":20900",
    "target": "127.0.0.1:443",
    "key": "test",
    "crypt": "salsa20",
    "mode": "normal",
    "mtu": 1350,
    "sndwnd": 1024,
    "rcvwnd": 1024,
    "datashard": 70,
    "parityshard": 30,
    "dscp": 46,
    "nocomp": false,
    "acknodelay": false,
    "nodelay": 0,
    "interval": 40,
    "resend": 0,
    "nc": 0,
    "sockbuf": 4194304,
    "keepalive": 10
}
EOF

chmod +x /etc/rc.local;echo "sh /root/kcptun/start.sh" >> /etc/rc.local
