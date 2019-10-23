#!/bin/sh

host="HOST"
port="PORT"
nni="NNI"
passwd="PASSWORD"

proxy="PROXY"
proxy_sed="PROXYSED"

# help
function help() {
    echo "./setup-proxy.sh - script to setup configurations for proxy"
    echo ""
    echo -e "For \e[1mroot\e[0m commands, restart the script as root."
    echo "Some commands are not implemented yet, instead they display how to do it manually."
    echo "You may want to restart the session for all configurations to take effect"
    echo ""
    echo "Commands:"
    echo "help: display this help"
    echo "clear: clear the screen"
    echo "files: display files which will be modified by the following commands"
    echo "proxy: set host, port, nni, password and proxy"
    echo "global: set proxy for global configuration (root)"
    echo "docker: set proxy for docker (root)"
    echo "pip: set proxy for pip"
    echo "git: set proxy for git"
    echo "hg: display help on how to do it (not implemented)"
    echo "mvn: display help on how to do it (not implemented)"
    echo "svn: display help on how to do it (not implemented)"
    echo "exit: exit the program"
    echo ""
}

# set proxy
function set_proxy() {
    read -p "What is the host?: " host
    read -p "What is the port?: " port
    read -p "What is the NNI?: " nni
    read -s -p "What is the password?: " passwd
    echo ""
    proxy_sed="http:\/\/${nni}:${passwd}@${host}:${port}"
    proxy="http://${nni}:${passwd}@${host}:${port}"
}

# template function
function template() {
    file=$1
    sed_expr=$2
    func_grep=$3
    func_proxy_not_set=$4

    echo "Does $file exists?"
    ls $file &>/dev/null
    if [ $? -ne 0 ]; then
        echo "No."
        echo "Creation of $file with proxy."
        {
            func_proxy_not_set
        } >$file
    else
        echo "Yes."
        echo "Is a proxy already set?"
        {
            cat $file | func_grep
        } &>/dev/null
        if [ $? -eq 0 ]; then
            echo "Yes."
            echo "Updating proxy."
            cat $file | sed -i.proxybak "${sed_expr}" $file
        else
            echo "No."
            echo "Setting proxy."
            {
                func_proxy_not_set
            } >>$file
        fi
    fi
    return $?
}

function handle_exit_val() {
    tool=$1
    exit_val=$2
    if [ $exit_val -eq 0 ]; then
        echo -e "\e[32m$tool configuration done."
    else
        echo -e "\e[31m$tool configuration failed. You may need to restart as root."
    fi
    echo -e "\e[0m"
}

# gitconfig
function gitconfig() {
    file=${HOME}/.gitconfig
    sed_expr="s/proxy = \".*\"/proxy = \"${proxy_sed}\"/g"
    function func_grep() {
        grep "proxy"
    }
    function func_proxy_not_set() {
        echo "[http]"
        echo -e "\tproxy = \"${proxy}\""
    }
    template $file "$sed_expr" func_grep func_proxy_not_set
    handle_exit_val "git" $?
}

# environment variables
function global_config() {
    file_d=/etc/profile.d/proxy.sh
    sed_expr="s/\"http.*[1-9]\"/\"${proxy_sed}\"/g"
    function func_grep() {
        grep -iE "http_proxy|https_proxy"
    }
    function func_proxy_not_set() {
        echo "#!/bin/bash"
        echo "export http_proxy=\"${proxy}\""
        echo "export https_proxy=\"${proxy}\""
        echo "export HTTP_PROXY=\"${proxy}\""
        echo "export HTTPS_PROXY=\"${proxy}\""
    }
    template $file_d "$sed_expr" func_grep func_proxy_not_set
    handle_exit_val "$file_d" $?

    file_profile=/etc/profile
    function func_grep() {
        grep ". /etc/profile.d/proxy.sh"
    }
    sed_expr=""
    function func_proxy_not_set() {
        echo "if [ -f /etc/profile.d/proxy.sh ]; then"
        echo -e "\t. /etc/profile.d/proxy.sh"
        echo "fi"
    }
    template $file_profile "$sed_expr" func_grep func_proxy_not_set
    exit_val=$?
    handle_exit_val "$file_profile" $exit_val
    handle_exit_val "Global" $exit_val
}

# pip
function pipconf() {
    dir_pip=${HOME}/.config/pip
    mkdir -p $dir_pip
    if [ $? -eq 0 ]; then
        file=${dir_pip}/pip.conf
        function func_grep() {
            grep "proxy = http://"
        }
        sed_expr="s/proxy = http:\/\/.*[1-9]/proxy = ${proxy_sed}/g"
        function func_proxy_not_set() {
            echo "[global]"
            echo "proxy = ${proxy}"
        }
        template $file "$sed_expr" func_grep func_proxy_not_set
    else
        false
    fi
    handle_exit_val "pip" $?
}

# docker
function dockerconf() {
    dir_file=/etc/systemd/system/docker.service.d
    mkdir -p $dir_file
    if [ $? -eq 0 ]; then
        file=${dir_file}/http-proxy.conf
        function func_grep() {
            grep -iE "http_proxy|https_proxy"
        }
        sed_expr="s/http:\/\/.*[1-9]/${proxy_sed}/g"
        function func_proxy_not_set() {
            echo "[Service]"
            echo "Environment=\"HTTP_PROXY=${proxy}\""
            echo "Environment=\"HTTPS_PROXY=${proxy}\""
            echo "Environment=\"http_proxy=${proxy}\""
            echo "Environment=\"https_proxy=${proxy}\""
            echo "Environment=\"NO_PROXY=localhost,127.0.0.0/8\""
        }
        template $file "$sed_expr" func_grep func_proxy_not_set
    else
        false
    fi
    handle_exit_val "docker" $?
    echo "You may want to restart docker after exiting the program:"
    echo -e "\e[1msudo systemctl daemon-reload"
    echo -e "sudo systemctl restart docker\e[0m"
}

function not_implemented() {
    tool=$1
    echo ""
    echo "$tool configuration for a proxy is not implemented."
    echo "If you feel like implementing it, then please do."
    echo "Otherwise, here is how to configure the proxy manually:"
    echo ""
}

# mercurial
function hgconfig() {
    not_implemented "Mercurial"
    echo "cd ~"
    echo "vim .hgrc"
    echo "[http_proxy]"
    echo -e "host=\e[1m${host}\e[0m:\e[1m${port}\e[0m"
    echo -e "user=\e[1m${nni}\e[0m"
    echo -e "passwd=\e[1m${passwd}\e[0m"
    echo ""
}

# maven
function mvnconfig() {
    not_implemented "Maven"
    echo -e "cd ~
cd .m2
vim settings.xml
# <settings>
#    <proxies>
#        <proxy>
#            <id>whatever</id>
#            <active>true</active>
#            <protocol>http</protocol>
#            <host>\e[1m${host}\e[0m</host>
#            <port>\e[1m${port}\e[0m</port>
#            <username>\e[1m${nni}\e[0m</username>
#            <password>\e[1m${passwd}\e[0m</password>
#            <nonProxyHosts>localhost|.other-domain.com</nonProxyHosts>
#        </proxy>
#    </proxies>
#</settings>
"
}

# svn
function svnconfig() {
    not_implemented "SVN"
    echo "# in ~/.subversion/servers"
    echo "# search for http-proxy and modify it to satisfy your needs"
    echo ""
}

# files
function modified_files() {
    echo ""
    echo -e "global: modify \e[1m/etc/profile.d/proxy.sh\e[0m and \e[1m/etc/profile\e[0m"
    echo -e "docker: modify \e[1m/etc/systemd/system/docker.service.d/http-proxy.conf\e[0m"
    echo -e "pip: modify \e[1m\${HOME}/.config/pip/pip.conf\e[0m"
    echo -e "git: modify \e[1m\${HOME}/.gitconfig\e[0m"
    echo -e "hg: manually modify \e[1m\${HOME}/.hgrc\e[0m"
    echo -e "mvn: manually modify \e[1m\${HOME}/.m2/settings.xml\e[0m"
    echo -e "svn: manually modify \e[1m\${HOME}/.subversion/servers\e[0m"
}

# cli
function command_line() {
    echo ""
    echo "Welcome! I bet you are thinking \"Proxies are sooo fun!\""
    echo -e "Type \e[1mhelp\e[0m to see the commands available."
    echo ""
    while read cmd; do {
        case "$cmd" in
        "exit") break ;;
        "help") help ;;
        "files") modified_files ;;
        "proxy") set_proxy ;;
        "global") global_config ;;
        "docker") dockerconf ;;
        "pip") pipconf ;;
        "git") gitconfig ;;
        "hg") hgconfig ;;
        "mvn") mvnconfig ;;
        "svn") svnconfig ;;
        "clear") clear ;;
        "42") echo "The answer of life" ;;
        esac
    } done
}

# set proxy at least once at the start of the program
set_proxy
command_line
