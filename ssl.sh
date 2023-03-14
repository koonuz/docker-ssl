#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

before_show_menu() {
    echo -n -e "${yellow}按回车返回主菜单: ${plain}" && read
    show_menu
}

ssl_cert_issue() {
    local method=""
    echo -e ""
    echo -e "${yellow}******使用说明******${plain}"
    echo -e "${green}该脚本提供3种方式实现证书签发,证书安装路径均为/root/cert${plain}"
    echo -e "${green}方式1:acme Standalone mode${plain},需要保持端口未被占用,本脚本默认使用端口为${green}80端口${plain}"
    echo -e "${green}方式2:acme DNS API mode${plain},需要提供Cloudflare Global API Key"
    echo -e "${green}方式3:acme Webroot mode${plain},无需暂停Nginx/Apache的Web服务"
    echo -e "如域名属于${green}免费域名${plain},则推荐使用${green}方式1${plain}进行申请.若已部署了Nginx/Apache,请先手动暂停其服务"
    echo -e "如域名属于${green}非免费域名${plain}且${green}使用Cloudflare进行域名解析${plain}的,则推荐使用${green}方式2${plain}进行申请"
    echo -e "如${green}已部署了Nginx/Apache的Web服务${plain}且${green}不想暂停其Web服务${plain}的,则推荐使用${green}方式3${plain}进行申请"
    read -p "请选择你想使用的方式【1、2、3】": method
    echo -e "你所使用的方式为${green}${method}${plain}"

    if [ "${method}" == "1" ]; then
        ssl_cert_issue_standalone
    elif [ "${method}" == "2" ]; then
        ssl_cert_issue_by_cloudflare
    elif [ "${method}" == "3" ]; then
        ssl_cert_issue_webroot
    else
        echo -e  "${red}输入无效,请检查你的输入,脚本将退出...${plain}"
        exit 1
    fi
 }

install_acme() {
    echo -e "${green}开始安装acme.sh脚本...${plain}"
    curl https://get.acme.sh | sh
    if [ $? -ne 0 ]; then
        echo -e "${red}acme.sh安装失败${plain}"
        return 1
    else
        echo -e "${green}acme.sh安装成功${plain}"
    fi
    return 0
}

#method for Standalone mode
ssl_cert_issue_standalone() {
    #check for acme.sh first
    if ! command -v ~/.acme.sh/acme.sh &>/dev/null; then
        install_acme
        if [ $? -ne 0 ]; then
            echo -e "${red}无法安装acme.sh,请检查错误日志${plain}"
            exit 1
        fi
    fi
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
    read -p "请输入你的域名:" domain
    echo -e "${yellow}你输入的域名为:${domain},正在进行域名合法性校验...${plain}"
    #here we need to judge whether there exists cert already
    local currentCert=$(~/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}')
    if [ ${currentCert} == ${domain} ]; then
        local certInfo=$(~/.acme.sh/acme.sh --list)
        echo -e "${red}域名合法性校验失败,当前环境已有对应域名证书,不可重复申请${plain}"
        echo -e "${green}当前证书详情:$certInfo${plain}"
        exit 1
    else
        echo -e "${green}证书有效性校验通过...${plain}"
    fi
    #get needed port here
    local WebPort=80
    read -p "请输入你所希望使用的端口,按回车键将使用默认80端口:" WebPort
    if [[ ${WebPort} -gt 65535 || ${WebPort} -lt 1 ]]; then
        echo -e "${red}你所选择的端口${WebPort}为无效值${plain},将使用${yellow}默认80端口${plain}进行申请"
    fi
    echo -e "${green}将会使用${WebPort}端口进行证书申请,请确保端口保持开放状态且没有被其他Web服务占用...${plain}"
    #NOTE:This should be handled by user
    #open the port and kill the occupied progress
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    ~/.acme.sh/acme.sh --issue -d ${domain} --standalone --httpport ${WebPort}
    if [ $? -ne 0 ]; then
        echo -e "${red}证书申请失败,原因请详见报错信息${plain}"
        rm -rf ~/.acme.sh/${domain}
        exit 1
    else
        echo -e "${green}证书申请成功,开始安装证书...${plain}"
    fi
    #install cert
    ~/.acme.sh/acme.sh --installcert -d ${domain} --ca-file /root/cert/ca.cer \
        --cert-file /root/cert/${domain}.cer --key-file /root/cert/${domain}.key \
        --fullchain-file /root/cert/fullchain.cer
    if [ $? -ne 0 ]; then
        echo -e "${red}证书安装失败,脚本退出${plain}"
        rm -rf ~/.acme.sh/${domain}
        exit 1
    else
        echo -e "${green}证书安装成功,开启自动更新...${plain}"
    fi
    ~/.acme.sh/acme.sh --upgrade --auto-upgrade
    if [ $? -ne 0 ]; then
        echo -e "${red}自动更新设置失败,脚本退出${plain}"
        ls -lah cert
        chmod 755 $certPath
        exit 1
    else
        echo -e "${green}证书已安装且已开启自动更新,具体信息如下${plain}"
        ls -lah cert
        chmod 755 $certPath
    fi
}

#method for DNS API mode
ssl_cert_issue_by_cloudflare() {
    echo -e ""
    echo -e "${yellow}******使用说明******${plain}"
    echo -e "${green}该脚本将使用Acme脚本申请证书,使用时需保证:${plain}"
    echo -e "${green}1.知晓Cloudflare 注册邮箱${plain}"
    echo -e "${green}2.知晓Cloudflare Global API Key${plain}"
    echo -e "${green}3.域名已通过Cloudflare进行解析到当前服务器${plain}"
    echo -e "${green}4.该脚本申请证书默认安装路径为/root/cert目录${plain}"
    if ! command -v ~/.acme.sh/acme.sh &>/dev/null; then
        install_acme
        if [ $? -ne 0 ]; then
            echo -e "${red}无法安装acme.sh,请检查错误日志${plain}"
            exit 1
        fi
    fi
    CF_Domain=""
    CF_GlobalKey=""
    CF_AccountEmail=""
    certPath=/root/cert
    if [ ! -d "$certPath" ]; then
        mkdir $certPath
    else
        rm -rf $certPath
        mkdir $certPath
    fi
    echo -e "${yellow}请设置域名:${plain}"
    read -p "请输入你的域名:" CF_Domain
    echo -e "${green}你的域名设置为:${CF_Domain},正在进行域名合法性校验...${plain}"
    #here we need to judge whether there exists cert already
    local currentCert=$(~/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}')
    if [ ${currentCert} == ${CF_Domain} ]; then
        local certInfo=$(~/.acme.sh/acme.sh --list)
        echo -e "${red}域名合法性校验失败,当前环境已有对应域名证书,不可重复申请${plain}"
        echo -e "${green}当前证书详情:$certInfo${plain}"
        exit 1
    else
        echo -e "${green}证书有效性校验通过...${plain}"
    fi
    echo -e "${yellow}请输入你的域名Global API Key密钥:${plain}"
    read -p "请输入你的域名Global API Key:" CF_GlobalKey
    echo -e "${yellow}你的域名Global API Key密钥为:${CF_GlobalKey}${plain}"
    echo -e "${yellow}请输入你在Cloudflare的注册邮箱:${plain}"
    read -p "请输入你在Cloudflare的注册邮箱:" CF_AccountEmail
    echo -e "${yellow}你的Cloudflare注册邮箱为:${CF_AccountEmail}${plain}"
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    if [ $? -ne 0 ]; then
        echo -e "${red}修改默认CA为Lets'Encrypt失败,脚本退出${plain}"
        exit 1
    fi
    export CF_Key="${CF_GlobalKey}"
    export CF_Email=${CF_AccountEmail}
    ~/.acme.sh/acme.sh --issue --dns dns_cf -d ${CF_Domain} -d *.${CF_Domain} --log
    if [ $? -ne 0 ]; then
        echo -e "${red}证书签发失败,脚本退出${plain}"
        rm -rf ~/.acme.sh/${CF_Domain}
        exit 1
    else
        echo -e "${green}证书签发成功,安装中...${plain}"
    fi
    ~/.acme.sh/acme.sh --installcert -d ${CF_Domain} -d *.${CF_Domain} --ca-file /root/cert/ca.cer \
        --cert-file /root/cert/${CF_Domain}.cer --key-file /root/cert/${CF_Domain}.key \
        --fullchain-file /root/cert/fullchain.cer
    if [ $? -ne 0 ]; then
        echo -e "${red}证书安装失败,脚本退出${plain}"
        rm -rf ~/.acme.sh/${CF_Domain}
        exit 1
    else
        echo -e "${green}证书安装成功,开启自动更新...${plain}"
    fi
    ~/.acme.sh/acme.sh --upgrade --auto-upgrade
    if [ $? -ne 0 ]; then
        echo -e "${red}自动更新设置失败,脚本退出${plain}"
        ls -lah cert
        chmod 755 $certPath
        exit 1
    else
        echo -e "${green}证书已安装且已开启自动更新,具体信息如下${plain}"
        ls -lah cert
        chmod 755 $certPath
    fi
}

#method for Webroot mode
ssl_cert_issue_webroot() {
    #check for acme.sh first
    if ! command -v ~/.acme.sh/acme.sh &>/dev/null; then
        install_acme
        if [ $? -ne 0 ]; then
            echo -e "${red}无法安装acme.sh,请检查错误日志${plain}"
            exit 1
        fi
    fi
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
    read -p "请输入你的域名:" WR_Domain
    echo -e "${yellow}你输入的域名为:${WR_Domain},正在进行域名合法性校验...${plain}"
    #here we need to judge whether there exists cert already
    local currentCert=$(~/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}')
    if [ ${currentCert} == ${WR_Domain} ]; then
        local certInfo=$(~/.acme.sh/acme.sh --list)
        echo -e "${red}域名合法性校验失败,当前环境已有对应域名证书,不可重复申请${plain}"
        echo -e "${green}当前证书详情:$certInfo${plain}"
        exit 1
    else
        echo -e "${green}证书有效性校验通过...${plain}"
    fi
    #get needed the web root folder here
    local Webroot=/root/web
    read -p "请输入域名的webroot文件夹路径,按回车键将使用路径为/root/web作为默认文件夹:" Webroot
    echo -e "${green}将通过域名:${WR_Domain}的webroot目录路径${Webroot}进行证书申请校验...${plain}"
    #NOTE:This should be handled by user
    #open the port and kill the occupied progress
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    ~/.acme.sh/acme.sh --issue -d ${WR_Domain} --webroot ${Webroot}
    if [ $? -ne 0 ]; then
        echo -e "${red}证书申请失败,原因请详见报错信息${plain}"
        rm -rf ~/.acme.sh/${WR_Domain}
        exit 1
    else
        echo -e "${green}证书申请成功,开始安装证书...${plain}"
    fi
    #install cert
    ~/.acme.sh/acme.sh --installcert -d ${WR_Domain} --ca-file /root/cert/ca.cer \
        --cert-file /root/cert/${WR_Domain}.cer --key-file /root/cert/${WR_Domain}.key \
        --fullchain-file /root/cert/fullchain.cer
    if [ $? -ne 0 ]; then
        echo -e "${red}证书安装失败,脚本退出${plain}"
        rm -rf ~/.acme.sh/${WR_Domain}
        exit 1
    else
        echo -e "${green}证书安装成功,开启自动更新...${plain}"
    fi
    ~/.acme.sh/acme.sh --upgrade --auto-upgrade
    if [ $? -ne 0 ]; then
        echo -e "${red}自动更新设置失败,脚本退出${plain}"
        ls -lah cert
        chmod 755 $certPath
        exit 1
    else
        echo -e "${green}证书已安装且已开启自动更新,具体信息如下${plain}"
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
