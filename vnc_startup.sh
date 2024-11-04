#!/bin/bash
### every exit != 0 fails the script
set -e

echo "start redis-server"
redis-server --daemonize yes

# place at highest, takes some time
# echo "start agent js subs"
# pm2 start $HOME/agent/agentSubscriber.js

# 8002 root
mkdir -p ${HOME}/www
echo "{\"deviceId\": \"${DEVICE_ID}\", \"env\": \"${ENV}\", \"hostname\": \"$(hostname)\"}" > ${HOME}/www/info.json

# nignx
echo "start nginx"
sudo nginx

## print out help
help (){
echo "
USAGE:
docker run -it -p 6901:6901 -p 5901:5901 consol/<image>:<tag> <option>

IMAGES:
consol/ubuntu-xfce-vnc
consol/centos-xfce-vnc
consol/ubuntu-icewm-vnc
consol/centos-icewm-vnc

TAGS:
latest  stable version of branch 'master'
dev     current development version of branch 'dev'

OPTIONS:
-w, --wait      (default) keeps the UI and the vncserver up until SIGINT or SIGTERM will received
-s, --skip      skip the vnc startup and just execute the assigned command.
                example: docker run consol/centos-xfce-vnc --skip bash
-d, --debug     enables more detailed startup output
                e.g. 'docker run consol/centos-xfce-vnc --debug bash'
-h, --help      print out this help

Fore more information see: https://github.com/ConSol/docker-headless-vnc-container
"
}
if [[ $1 =~ -h|--help ]]; then
    help
    exit 0
fi

# should also source $STARTUPDIR/generate_container_user
source $HOME/.bashrc

# add `--skip` to startup args, to skip the VNC startup procedure
if [[ $1 =~ -s|--skip ]]; then
    echo -e "\n\n------------------ SKIP VNC STARTUP -----------------"
    echo -e "\n\n------------------ EXECUTE COMMAND ------------------"
    echo "Executing command: '${@:2}'"
    exec "${@:2}"
fi
if [[ $1 =~ -d|--debug ]]; then
    echo -e "\n\n------------------ DEBUG VNC STARTUP -----------------"
    export DEBUG=true
fi

## correct forwarding of shutdown signal
cleanup () {
    kill -s SIGTERM $!
    exit 0
}
trap cleanup SIGINT SIGTERM

## write correct window size to chrome properties
# $STARTUPDIR/chrome-init.sh

## resolve_vnc_connection
VNC_IP=$(hostname -i)


## for ARM
## reinstall vncserver
# !!! /usr/bin/vncpasswd: cannot execute binary file: Exec format error
# ref: https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-vnc-on-ubuntu-22-04
# apt list --installed | grep vncserver
# export VNC_OK=`echo $?`
export VNC_OK=`apt list --installed | grep vnc | wc -l`
# if [[ $VNC_OK -ne '0' ]];
echo ">>>>>>>>> VNCOK = $VNC_OK"

# check is /usr/bin/vncpasswd runnable in cpu arch
os_arch=`uname -m`
# check if /usr/bin/vncpasswd arch is same as os_arch, otherwise reinstall
if [[ ! `ldd /usr/bin/vncpasswd | grep $os_arch` ]];
then
    apt -y remove tightvncserver
    echo 'reinstall vnc'
    rm -rf /usr/bin/vncserver
    rm -rf /usr/bin/vncpasswd
    apt -y install tightvncserver
else 
    echo 'vnc ok'    
fi    
export USER=root

## fix arm PUPPETEER
[[ `arch` = "aarch64" ]] && export PUPPETEER_SKIP_DOWNLOAD=1


## change vnc password
echo -e "\n------------------ change VNC password  ------------------"
# first entry is control, second is view (if only one is valid for both)
mkdir -p "$HOME/.vnc"
PASSWD_PATH="$HOME/.vnc/passwd"

if [[ -f $PASSWD_PATH ]]; then
    echo -e "\n---------  purging existing VNC password settings  ---------"
    rm -f $PASSWD_PATH
fi

if [[ $VNC_VIEW_ONLY == "true" ]]; then
    echo "start VNC server in VIEW ONLY mode!"
    #create random pw to prevent access
    echo $(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 20) | vncpasswd -f > $PASSWD_PATH
fi
echo "$VNC_PW" | vncpasswd -f >> $PASSWD_PATH
chmod 600 $PASSWD_PATH


## start vncserver and noVNC webclient
echo -e "\n------------------ start noVNC  ----------------------------"
if [[ $DEBUG == true ]]; then echo "$NO_VNC_HOME/utils/launch.sh --vnc localhost:$VNC_PORT --listen $NO_VNC_PORT"; fi
$NO_VNC_HOME/utils/launch.sh --vnc localhost:$VNC_PORT --listen $NO_VNC_PORT &> $STARTUPDIR/no_vnc_startup.log &
PID_SUB=$!

echo -e "\n------------------ start VNC server ------------------------"
echo "remove old vnc locks to be a reattachable container"
vncserver -kill $DISPLAY &> $STARTUPDIR/vnc_startup.log \
    || rm -rfv /tmp/.X*-lock /tmp/.X11-unix &> $STARTUPDIR/vnc_startup.log \
    || echo "no locks present"

echo -e "start vncserver with param: VNC_COL_DEPTH=$VNC_COL_DEPTH, VNC_RESOLUTION=$VNC_RESOLUTION\n..."
if [[ $DEBUG == true ]]; then echo "vncserver $DISPLAY -depth $VNC_COL_DEPTH -geometry $VNC_RESOLUTION"; fi
vncserver $DISPLAY -depth $VNC_COL_DEPTH -geometry $VNC_RESOLUTION &> $STARTUPDIR/no_vnc_startup.log
echo -e "start window manager\n..."
$HOME/wm_startup.sh &> $STARTUPDIR/wm_startup.log

# ref: https://superuser.com/questions/1081489/how-to-enable-text-copy-and-paste-for-vnc
# enable clipboard
# autocutsel -fork

echo -e "\n------------------ start terminal  ----------------------------"
# xfce4-terminal > /dev/null &
node /headless/browser_device/start_terminal.js > /dev/null &

# HASH_1=$(sha1sum /headless/browser_device/browser_device.ts | awk '{print $1}')
# HASH_2=$(sha1sum /headless/browser_device/dist/browser_device.js | awk '{print $1}')
# if [[ ! `grep -ir $HASH_1 /headless/browser_device/cache/version.txt` || ! `grep -ir $HASH_2 /headless/browser_device/cache/version.txt` ]]; then
#     echo "---------- building tsc ----------"
#     npm i --prefix=$HOME/browser_device
#     cd $HOME/browser_device \
#         && tsc \
#         && ls -al dist

#     rm -rf /headless/browser_device/cache/version.txt
#     sha1sum /headless/browser_device/browser_device.ts | awk '{print $1}' >> /headless/browser_device/cache/version.txt
#     sha1sum /headless/browser_device/dist/browser_device.js | awk '{print $1}' >> /headless/browser_device/cache/version.txt
#     echo "---------- tsc done ----------"
# else
#     echo 'no tsc'
# fi

# [[ `arch` = "aarch64" ]] && apt -y install chromium-browser

echo "start google chrome"
pm2 start $STARTUPDIR/ecosystem.config.js

## log connect options
echo -e "\n\n------------------ VNC environment started ------------------"
echo -e "\nVNCSERVER started on DISPLAY= $DISPLAY \n\t=> connect via VNC viewer with $VNC_IP:$VNC_PORT"
echo -e "\nnoVNC HTML client started:\n\t=> connect via http://$VNC_IP:$NO_VNC_PORT/?password=...\n"


if [[ $DEBUG == true ]] || [[ $1 =~ -t|--tail-log ]]; then
    echo -e "\n------------------ $HOME/.vnc/*$DISPLAY.log ------------------"
    # if option `-t` or `--tail-log` block the execution and tail the VNC log
    tail -f $STARTUPDIR/*.log $HOME/.vnc/*$DISPLAY.log
fi

if [ -z "$1" ] || [[ $1 =~ -w|--wait ]]; then
    wait $PID_SUB
else
    # unknown option ==> call command
    echo -e "\n\n------------------ EXECUTE COMMAND ------------------"
    echo "Executing command: '$@'"
    exec "$@"
fi
