
# docker run --name del --platform linux/amd64 \
# -v "/Users/lawrence/Downloads/Esc_Config_Tool_1_82_Linux:/Esc_Config_Tool_1_82_Linux" \
# -v "sleep.js:/headless/browser_device/dist/browser_device.js" \
# -p 5901:5901 \
# -p 6901:6901 \
# lncknight/whatsapp:20231218 sleep 9999


From lncknight/whatsapp:20231218

WORKDIR /Esc_Config_Tool_1_82_Linux

# apt install -y libgl1
# apt install -y libglib2.0-0
# apt install python3-pip -y
# pip3 install opencv-python-headless
# apt install libxcb-cursor0 -y
# apt-get install -y libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-render-util0 libxcb-randr0 libxcb-xinerama0
# apt-get install -y libxcb-xkb1 libxkbcommon-x11-0 libxkbcommon-dev

# install libraries
RUN apt-get update && apt-get install -y \
    libgl1 \
    libglib2.0-0 \
    python3-pip \
    libxcb-cursor0 \
    libxcb-icccm4 \
    libxcb-image0 \
    libxcb-keysyms1 \
    libxcb-render-util0 \
    libxcb-randr0 \
    libxcb-xinerama0 \
    libxcb-xkb1 \
    libxkbcommon-x11-0 \
    libxkbcommon-dev