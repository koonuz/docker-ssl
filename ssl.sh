#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

before_show_menu() {
    echo -n -e "${yellow}按回车返回主菜单:${plain}" && read
    show_menu
}

ssl_cert_issue() {
    local method=""
    echo -e ""
    echo -e "${yellow}******使用说明******${plain}"
    echo -e "该脚本提供3种方式实现证书签发,证书安装路径均为${green}/root/cert${plain}"
    echo -e "${yellow}【方式1】${plain}${green}Acme Standalone mode${plain},需确保端口${green}未被占用${plain},默认使用${green}80${plain}端口"
    echo -e "${yellow}【方式2】${plain}${green}Acme DNS API mode${plain},需提供${green}Cloudflare Global API Key${plain}"
    echo -e "${yellow}【方式3】${plain}${green}Acme Webroot mode${plain},需提供域名在本机的${green}webroot路径目录${plain},默认路径为${green}/root/web${plain}"
    echo -e "若域名属于${green}免费域名${plain},则推荐使用${yellow}【方式1】${plain}进行申请.若已部署了${green}Nginx/Apache${plain}提供web服务,请先${green}手动暂停${plain}其服务"
    echo -e "若域名属于${green}付费域名${plain}且使用${green}Cloudflare${plain}进行域名解析的,则推荐使用${yellow}【方式2】${plain}进行申请"
    echo -e "若已部署${green}Nginx${plain}提供web服务且签发证书时${green}不想手动暂停其服务${plain},则推荐使用${yellow}【方式3】${plain}进行申请"
    read -p "请选择你想使用的方式【1、2、3】": method
    echo -e "你所使用的是【${yellow}方式${method}${plain}】"

    if [ "${method}" == "1" ]; then
        ssl_cert_issue_standalone
    elif [ "${method}" == "2" ]; then
        ssl_cert_issue_by_cloudflare
    elif [ "${method}" == "3" ]; then
        ssl_cert_issue_webroot
    else
        echo -e  "${red}当前输入为无效数字,请检查输入的数字!${plain}脚本将自动退出..."
        exit 1
    fi
 }

check_acme() {
    echo -e "${green}正在检测是否已安装acme.sh...${plain}"
    if ! command -v ~/.acme.sh/acme.sh &>/dev/null; then
        echo -e "${green}未检测到acme.sh,现开始进行acme.sh安装...${plain}"
        curl https://get.acme.sh | sh
        if [ $? -ne 0 ]; then
            echo -e "${red}acme.sh安装失败${plain}"
            return 1
        else
            echo -e "${green}acme.sh安装成功${plain}"
            return 0
        fi
    else
        echo -e "${green}已安装acme.sh,现开始申请SSL证书${plain}"
    fi
}

#method for Standalone mode
ssl_cert_issue_standalone() {
    echo -e ""
    echo -e "${yellow}******使用说明******${plain}"
    echo -e "${green}该脚本将使用Acme脚本申请证书,使用时需知晓以下事项${plain}"
    echo -e "${green}1.您目前使用的是【方式1】Standalone mode模式${plain}"
    echo -e "${green}2.请确保端口保持开放状态且没有被其他Web服务占用${plain}"
    echo -e "${green}3.需申请SSL证书的域名已解析到当前服务器${plain}"
    echo -e "${green}4.该脚本申请证书默认安装路径为/root/cert目录${plain}"
    echo -e "${yellow}********************${plain}"

    #check for acme.sh first
    check_acme

    #creat a directory for install cert
    certPath=/root/cert
    if [ ! -d "$certPath" ]; then
        mkdir $certPath
    else
        rm -rf $certPath
        mkdir $certPath
    fi
    #get the domain here,and we need verify it
    local domain=""
    echo -e "${yellow}请设置域名${plain}"
    read -p "请输入你的域名:" domain
    echo -e "你输入的域名为:${yellow}${domain}${plain},${green}正在进行域名合法性校验...${plain}"
    #here we need to judge whether there exists cert already
    local currentCert=$(~/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}')
    if [ ${currentCert} == ${domain} ]; then
        local certInfo=$(~/.acme.sh/acme.sh --list)
        echo -e "${red}域名合法性校验失败${plain},当前环境已有对应域名证书,不可重复申请"
        echo -e "当前证书详情:${green}$certInfo${plain}"
        exit 1
    else
        echo -e "${green}证书有效性校验通过...${plain}"
    fi
    #get needed port here
    local WebPort=80
    read -p "请输入你所希望使用的端口,按回车键将使用默认80端口:" WebPort
    if [[ ${WebPort} -gt 65535 || ${WebPort} -lt 1 ]]; then
        echo -e "${red}你所选择的端口${WebPort}为无效值${plain},将使用默认${yellow}80${plain}端口进行申请"
    fi
    echo -e "将会使用${green}${WebPort}${plain}端口进行证书申请,请确保端口${green}保持开放${plain}状态且${green}没有被其他Web服务占用${plain}..."
    #NOTE:This should be handled by user
    #open the port and kill the occupied progress
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    if [ $? -ne 0 ]; then
        echo -e "${red}修改默认CA为Lets'Encrypt失败${plain},脚本将自动退出..."
        exit 1
    fi
    ~/.acme.sh/acme.sh --issue -d ${domain} --standalone --httpport ${WebPort}
    if [ $? -ne 0 ]; then
        echo -e "${red}证书签发失败${plain},原因请详见报错信息"
        rm -rf ~/.acme.sh/${domain}
        exit 1
    else
        echo -e "${green}证书签发成功${plain},正在进行证书安装..."
    fi
    #install cert
    ~/.acme.sh/acme.sh --installcert -d ${domain} --ca-file /root/cert/ca.cer \
        --cert-file /root/cert/${domain}.cer --key-file /root/cert/${domain}.key \
        --fullchain-file /root/cert/fullchain.cer
    if [ $? -ne 0 ]; then
        echo -e "${red}证书安装失败${plain},脚本将自动退出..."
        rm -rf ~/.acme.sh/${domain}
        exit 1
    else
        echo -e "${green}证书安装成功${plain},即将开启自动更新..."
    fi
    ~/.acme.sh/acme.sh --upgrade --auto-upgrade
    if [ $? -ne 0 ]; then
        echo -e "${red}自动更新设置失败${plain},脚本将自动退出..."
        ls -lah cert
        chmod 755 $certPath
        exit 1
    else
        echo -e "${green}证书已安装成功且已开启自动更新${plain},具体信息如下"
        ls -lah cert
        chmod 755 $certPath
    fi
}

#method for DNS API mode
ssl_cert_issue_by_cloudflare() {
    echo -e ""
    echo -e "${yellow}******使用说明******${plain}"
    echo -e "${green}该脚本将使用Acme脚本申请证书,使用时需知晓以下事项${plain}"
    echo -e "${green}1.知晓Cloudflare 注册邮箱${plain}"
    echo -e "${green}2.知晓Cloudflare Global API Key${plain}"
    echo -e "${green}3.需申请SSL证书的域名已通过Cloudflare解析到当前服务器${plain}"
    echo -e "${green}4.该脚本申请证书默认安装路径为/root/cert目录${plain}"
    echo -e "${yellow}********************${plain}"

    #check for acme.sh first
    check_acme

    CF_Domain=""
    CF_GlobalKey=""
    CF_AccountEmail=""

    #creat a directory for install cert
    certPath=/root/cert
    if [ ! -d "$certPath" ]; then
        mkdir $certPath
    else
        rm -rf $certPath
        mkdir $certPath
    fi
    echo -e "${yellow}请设置域名${plain}"
    read -p "请输入你的域名:" CF_Domain
    echo -e "你输入的域名为:${yellow}${CF_Domain}${plain},正在进行域名合法性校验..."
    #here we need to judge whether there exists cert already
    local currentCert=$(~/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}')
    if [ ${currentCert} == ${CF_Domain} ]; then
        local certInfo=$(~/.acme.sh/acme.sh --list)
        echo -e "${red}域名合法性校验失败${plain},当前环境已有对应域名证书,不可重复申请"
        echo -e "当前证书详情:${green}$certInfo${plain}"
        exit 1
    else
        echo -e "${green}证书有效性校验通过...${plain}"
    fi
    echo -e "${yellow}请输入你的域名Global API Key密钥${plain}"
    read -p "请输入你的域名Global API Key:" CF_GlobalKey
    echo -e "你的域名Global API Key密钥为:${yellow}${CF_GlobalKey}${plain}"
    echo -e "${yellow}请输入你在Cloudflare的注册邮箱${plain}"
    read -p "请输入你在Cloudflare的注册邮箱:" CF_AccountEmail
    echo -e "你的Cloudflare注册邮箱为:${yellow}${CF_AccountEmail}${plain}"
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    if [ $? -ne 0 ]; then
        echo -e "${red}修改默认CA为Lets'Encrypt失败${plain},脚本将自动退出..."
        exit 1
    fi
    export CF_Key="${CF_GlobalKey}"
    export CF_Email=${CF_AccountEmail}
    ~/.acme.sh/acme.sh --issue --dns dns_cf -d ${CF_Domain} -d *.${CF_Domain} --log
    if [ $? -ne 0 ]; then
        echo -e "${red}证书签发失败${plain},脚本将自动退出..."
        rm -rf ~/.acme.sh/${CF_Domain}
        exit 1
    else
        echo -e "${green}证书签发成功${plain},正在进行证书安装..."
    fi
    ~/.acme.sh/acme.sh --installcert -d ${CF_Domain} -d *.${CF_Domain} --ca-file /root/cert/ca.cer \
        --cert-file /root/cert/${CF_Domain}.cer --key-file /root/cert/${CF_Domain}.key \
        --fullchain-file /root/cert/fullchain.cer
    if [ $? -ne 0 ]; then
        echo -e "${red}证书安装失败${plain},脚本将自动退出..."
        rm -rf ~/.acme.sh/${CF_Domain}
        exit 1
    else
        echo -e "${green}证书安装成功${plain},即将开启自动更新..."
    fi
    ~/.acme.sh/acme.sh --upgrade --auto-upgrade
    if [ $? -ne 0 ]; then
        echo -e "${red}自动更新设置失败${plain},脚本将自动退出..."
        ls -lah cert
        chmod 755 $certPath
        exit 1
    else
        echo -e "${green}证书已安装成功且已开启自动更新,具体信息如下${plain}"
        ls -lah cert
        chmod 755 $certPath
    fi
}

#method for Webroot mode
ssl_cert_issue_webroot() {
    echo -e ""
    echo -e "${yellow}******使用说明******${plain}"
    echo -e "${green}该脚本将使用Acme脚本申请证书,使用时需知晓以下事项${plain}"
    echo -e "${green}1.您目前使用的是【方式3】Webroot mode模式${plain}"
    echo -e "${green}2.确认域名在本机的webroot路径目录${plain}"
    echo -e "${green}3.需申请SSL证书的域名已解析到当前服务器${plain}"
    echo -e "${green}4.该脚本申请证书默认安装路径为/root/cert目录${plain}"
    echo -e "${yellow}********************${plain}"

    #check for acme.sh first
    check_acme

    #creat a directory for install cert
    certPath=/root/cert
    if [ ! -d "$certPath" ]; then
        mkdir $certPath
    else
        rm -rf $certPath
        mkdir $certPath
    fi

    #get the domain here,and we need verify it
    local WR_Domain=""
    echo -e "${yellow}请设置域名${plain}"
    read -p "请输入你的域名:" WR_Domain
    echo -e "你输入的域名为:${yellow}${WR_Domain}${plain},正在进行域名合法性校验..."
    #here we need to judge whether there exists cert already
    local currentCert=$(~/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}')
    if [ ${currentCert} == ${WR_Domain} ]; then
        local certInfo=$(~/.acme.sh/acme.sh --list)
        echo -e "${red}域名合法性校验失败${plain},当前环境已有对应域名证书,不可重复申请"
        echo -e "当前证书详情:${green}$certInfo${plain}"
        exit 1
    else
        echo -e "${green}证书有效性校验通过...${plain}"
    fi
    #get needed the web root folder here
    local Webroot=/root/web
    read -p "请输入域名在本机的webroot路径目录,按回车键将使用/root/web为默认的路径目录:" Webroot
    echo -e "将通过域名:${yellow}}${WR_Domain}${plain}的webroot路径目录:${green}}${Webroot}${plain}进行证书的签发校验..."
    #NOTE:This should be handled by user
    #open the port and kill the occupied progress
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    if [ $? -ne 0 ]; then
        echo -e "${red}修改默认CA为Lets'Encrypt失败${plain},脚本将自动退出..."
        exit 1
    fi
    ~/.acme.sh/acme.sh --issue -d ${WR_Domain} --webroot ${Webroot}
    if [ $? -ne 0 ]; then
        echo -e "${red}证书签发失败${plain},原因请详见报错信息"
        rm -rf ~/.acme.sh/${WR_Domain}
        exit 1
    else
        echo -e "${green}证书签发成功${plain},正在进行证书安装..."
    fi
    #install cert
    ~/.acme.sh/acme.sh --installcert -d ${WR_Domain} --ca-file /root/cert/ca.cer \
        --cert-file /root/cert/${WR_Domain}.cer --key-file /root/cert/${WR_Domain}.key \
        --fullchain-file /root/cert/fullchain.cer
    if [ $? -ne 0 ]; then
        echo -e "${red}证书安装失败${plain},脚本将自动退出..."
        rm -rf ~/.acme.sh/${WR_Domain}
        exit 1
    else
        echo -e "${green}证书安装成功${plain},即将开启自动更新..."
    fi
    ~/.acme.sh/acme.sh --upgrade --auto-upgrade
    if [ $? -ne 0 ]; then
        echo -e "${red}自动更新设置失败${plain},脚本将自动退出..."
        ls -lah cert
        chmod 755 $certPath
        exit 1
    else
        echo -e "${green}证书已安装成功且已开启自动更新,具体信息如下${plain}"
        ls -lah cert
        chmod 755 $certPath
    fi
}

check_crontab() {
    crontab -l
    before_show_menu
}

show_menu() {
    echo -e "
  ${green}Acme.sh 一键申请域名SSL证书${plain}
————————————————
  ${green}0.${plain} 退出脚本
————————————————
  ${green}1.${plain} 申请SSL证书(含自动续签功能)
  ${green}2.${plain} 查看SSL证书自动续签任务"
  
    echo && read -p "请输入选择 [0-2]:" num
    case "${num}" in
        0) exit 0
        ;;
        1) ssl_cert_issue
        ;;
        2) check_crontab
        ;;
        *) echo -e "${red}请输入正确的数字${plain}${green}[0-2]${plain}" && show_menu
        ;;
    esac
}
show_menu
