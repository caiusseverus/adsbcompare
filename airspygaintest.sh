#!/bin/bash

original=$(sed -n 's/GAIN= //p' /etc/default/airspy_adsb)
echo "Original gain= $original"
gains=( 11 13 15 17 19 21 )
end=$((SECONDS+172710))

while [ $SECONDS -lt $end ]; do
    echo "Shuffling gains"
    gains=( $(shuf -e "${gains[@]}") )
    echo "${gains[*]}"
    for i in "${gains[@]}"
    do
        echo "Setting gain to $i"
        sudo sed -i -e "s/^GAIN= .*/GAIN= $i/" /etc/default/airspy_adsb
        sudo systemctl restart airspy_adsb
        sleep 600
    done
done


echo resetting gain
sudo sed -i -e "s/^GAIN= .*/GAIN= $original/" /etc/default/airspy_adsb
sudo systemctl restart airspy_adsb
python /home/pi/plots/airspystats.py

cp /usr/local/share/tar1090/html/stats/*.png .
