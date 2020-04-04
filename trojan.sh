#!/bin/sh
##################################
#主目录
dirtmp=/tmp/trojan
#配置
diretc=/etc/storage/trojan

##################################
[ ! -d $dirtmp ] && mkdir -p $dirtmp
[ ! -d $diretc ] && mkdir -p $diretc
cd $dirtmp

trojan_user () {
if [ -s $diretc/trojan_user.txt ] ; then
	trojan_server=$(cat $diretc/trojan_user.txt |awk -F'@=' '/trojan_server@=/{print $2}')
	trojan_password=$(cat $diretc/trojan_user.txt |awk -F'@=' '/trojan_password@=/{print $2}')
	trojan_port=$(cat $diretc/trojan_user.txt |awk -F'@=' '/trojan_port@=/{print $2}')
else
	echo -e \\n"↓↓请输入trojan配置参数↓↓"\\n
	read -p "trojan 服务器：" trojan_server
	read -p "trojan 密码：" trojan_password
	read -p "trojan 端口：" trojan_port
	echo "trojan_server@=$trojan_server
trojan_password@=$trojan_password
trojan_port@=$trojan_port" > $diretc/trojan_user.txt
fi
}
trojan_renew_user () {
[ -s $diretc/trojan_user.txt ] && rm $diretc/trojan_user.txt
trojan_user
}

trojan_down () {
filename="trojan"
m=10
n=1
while [ $n -lt $m ]
do
if [ ! -s ./$filename ] ; then
	echo -e \\n"\e[1;36m▶『$filename』检测到主程序不存在，開始第[$n]次下载......\e[0m"
	curl -# -L https://github.com/maskedeken/trojan-gfw/releases/download/1.15.1/trojan-1.15.1-linux-mipsel.tar.gz -O
	tar xzvf trojan*gz
	rm trojan*gz
	chmod 777 trojan
	ver=`./trojan -v 2>&1|awk '/trojan/{print $4}'`
	if [ ! -z "$ver" ] ; then
		echo -e \\n"\e[1;32m    ✓ 解壓成功，$filename版本【$ver】。\e[0m"\\n
	else
		echo -e \\n"\e[1;31m    ✘ 解壓失敗，$filename版本為空！\e[0m"\\n
	fi
	n=`expr $n + 1`
else
	break
fi
done
[ ! -s ./$filename ] && echo -e \\n"\e[1;31m✖『$filename』下载[$m]次都失败！！！\e[0m"\\n
}


trojan_config () {
cat > ./trojan_client.json << EOF
{
    "run_type": "client",
    "local_addr": "::",
    "local_port": 1234,
    "remote_addr": "$trojan_server",
    "remote_port": $trojan_port,
    "password": ["$trojan_password"],
    "log_level": 1,
    "ssl": {
        "verify": true,
        "verify_hostname": true,
        "cert": "",
        "cipher_tls13": "TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
        "sni": "",
        "alpn": ["h2", "http/1.1"],
        "reuse_session": true,
        "session_ticket": false,
        "curves": ""
    },
    "tcp": {
        "no_delay": true,
        "keep_alive": true,
        "reuse_port": false,
        "fast_open": true,
        "fast_open_qlen": 20
    }
}
EOF
}

#透明代理
transocks_stop () {
[ ! -z "`ps -w | grep -v grep | grep tran`" ] && echo -e \\n"\e[1;33m▶检测到transocks正在运行，stop...\e[0m" && nvram set app_27=0 && /etc/storage/script/Sh58_tran_socks.sh stop
[ ! -z "`ps -w | grep -v grep | grep chinadns`" ] && nvram set app_1=0 && /etc/storage/script/Sh19_chinadns.sh stop
#ps -w |grep -v grep |grep tran |awk '{print $1}' |xargs kill -9
}
transocks_start () {
echo -e \\n"\e[1;33m▶启动transocks透明代理......\e[0m"
nvram set app_27=1
nvram set transocks_proxy_mode_x=socks5
#路由模式 0 为chnroute, 1 为 gfwlist, 2 为全局
nvram set app_28=1
lan_ipaddr=`nvram get lan_ipaddr`
nvram set app_30=$lan_ipaddr
#透明重定向的代理端口
nvram set app_31=1234
nvram set app_32=$lan_ipaddr
#chinadns
nvram set app_1=1
nvram set app_5="223.5.5.5,208.67.222.222:5353,8.8.8.8"
/etc/storage/script/Sh58_tran_socks.sh start &
/etc/storage/script/Sh19_chinadns.sh start &
}

#状态
trojan_status () {
echo -e \\n"\e[36m▷查看trojan进程：\e[0m"
ps -w |grep -v grep| grep "trojan.*client"
echo -e \\n"\e[36m▷查看trojan网络监听端口：\e[0m"
netstat -anp | grep trojan
#判断是否启动
if [ ! -z "`ps -w |grep -v grep| grep "trojan.*client"`" ] ; then
	if [ ! -z "`netstat -anp|grep trojan`" ] ; then
		echo -e \\n"\e[1;36m✔ trojan已启动！！\e[0m"\\n
	else
		echo -e \\n"\e[1;36m✦ trojan进程已启动，但没监听端口...\e[0m"
	fi
else
	echo -e \\n"\e[1;31m✖ trojan进程启动失败，端口无监听，请检查网络问题！！\e[0m"
fi
}

#关闭
trojan_stop () {
[ ! -z "`ps -w |grep -v grep| grep "trojan.*client"`" ] && echo -e \\n\\n"\e[1;36m▶关闭trojan..." && ps -w |grep -v grep| grep "trojan.*client" | awk '{print $1}' | xargs kill -9
}
stop () {
transocks_stop
trojan_stop
}

#启动
trojan_start () {
echo -e \\n"\e[1;36m▶启动trojan主程序...\e[0m"
[ -f ./trojan_log.txt ] && mv -f ./trojan_log.txt ./old_trojan_log.txt
nohup $dirtmp/trojan -c $dirtmp/trojan_client.json > $dirtmp/trojan_log.txt 2>&1 &
}


#启动模式1：不重启transocks，只重启trojan主程序
start_1 () {
stop
trojan_user
trojan_down
trojan_config
trojan_start
sleep 2
trojan_status
}
#启动模式2：带启动transocks透明代理
start_2 () {
stop
trojan_user
trojan_down
trojan_config
trojan_start
sleep 2
trojan_status
if [ ! -z "$(ps -w | grep -v grep | grep trojan)" -a ! -z "$(netstat -anp | grep trojan)" ] ; then
	transocks_start &
else
	echo -e \\n"\e[1;31m✘检测到未启动trojan进程，取消transocks透明代理\e[0m"\\n
fi
}

#状态
zhuangtai () {
echo -e \\n"\e[1;33m当前状态：\e[0m"\\n
if [ -s ./trojan ] ; then
	echo -e "★ \e[1;36m trojan 版本：\e[1;32m【$(./trojan -v 2>&1|awk '/trojan/{print $4}')】\e[0m"
else
	echo -e "★ \e[1;36m trojan 版本：\e[1;31m【不存在】\e[0m"
fi
if [ ! -z "`ps -w |grep -v grep| grep "trojan.*client"`" ] ; then
	echo -e "● \e[1;36m trojan 进程：\e[1;32m【已运行】\e[0m"
else
	echo -e "○ \e[1;36m trojan 进程：\e[1;31m【未运行】\e[0m"
fi
if [ ! -z "`netstat -anp | grep trojan`" ] ; then
	echo -e "● \e[1;36m trojan 端口：\e[1;32m【已监听】\e[0m"
else
	echo -e "○ \e[1;36m trojan 端口：\e[1;31m【未监听】\e[0m"
fi
}

#按钮
case $1 in
0)
	stop &
	;;
1)
	start_1
	;;
2)
	start_2
	;;
9)
	trojan_renew_user
	;;
*)
	zhuangtai
	echo -e \\n"\e[1;33m脚本管理： \e[0m"\\n
	echo -e "\e[1;32m【0】\e[0m\e[1;36m stop：关闭 \e[0m "
	echo -e "\e[1;32m【1】\e[0m\e[1;36m start_1：启动trojan\e[0m"
	echo -e "\e[1;32m【2】\e[0m\e[1;36m start_2：启动trojan  + transocks 透明代理\e[0m"
	echo -e "\e[1;32m【9】\e[0m\e[1;36m renew：重置trojan用户配置 \e[0m"\\n
	read -n 1 -p "请输入数字:" num
	if [ "$num" = "0" ] ; then
		stop &
	elif [ "$num" = "1" ] ; then
		start_1
	elif [ "$num" = "2" ] ; then
		start_2
	elif [ "$num" = "9" ] ; then
		trojan_renew_user
	else
		echo -e \\n"\e[1;31m输入错误\e[0m "\\n
	fi
	;;
esac