FROM slechev/openwebrxplus-softmbe:latest

RUN apt-get update && apt-get install -y \
    libpulse-dev pavucontrol libsndfile1-dev libfftw3-dev liblapack-dev socat \
    libusb-1.0-0-dev libncurses5 libncurses5-dev cmake git wget make build-essential \
    libitpp-dev libcodec2-dev && \
    rm -rf /var/lib/apt/lists/*

RUN wget https://raw.githubusercontent.com/lwvmobile/dsd-fme/audio_work/download-and-install.sh && \
sed -i 's/sudo //g' download-and-install.sh && \
yes | sh download-and-install.sh

ENV LD_LIBRARY_PATH=/usr/local/lib

COPY owrx/modes.py /usr/lib/python3/dist-packages/owrx/modes.py
COPY csdr/chain/m17.py /usr/lib/python3/dist-packages/csdr/chain/m17.py
COPY csdr/module/m17.py /usr/lib/python3/dist-packages/csdr/module/m17.py