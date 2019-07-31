#! /bin/bash

#Set receiver location here
lat=0.000
lon=0.000


let "secs=$1 * 60"
int=$2
date=$(date -I)
end=$(date --date=now+${1}mins)

echo "Gathering data every $2 seconds until $end"


SECONDS=0

while (( SECONDS < secs )); do
        cat /run/dump1090-fa/aircraft.json | jq -r '.aircraft | .[] | select(.lat != null) | select (.lon !=null) | [.lon,.lat,.rssi] | @csv' >> heatmap
        sleep $2
done

echo "Number of data points collected:"
wc -l /tmp/heatmap

gnuplot -c /dev/stdin $lat $lon $date <<"EOF"

lat=ARG1
lon=ARG2
date=ARG3

set terminal pngcairo enhanced size 1200,1000
set datafile separator comma
set object 1 rectangle from screen 0,0 to screen 1,1 fillcolor rgb "black" behind
set output 'heatmap-'.date.'.png'

set border lc rgb "white"
set grid linecolor rgb "white"

set cbrange [-35:0]
set cblabel "RSSI" tc rgb "white"
set label at lon,lat "" point pointtype 7 lc rgb "cyan" ps 1.2 front
set palette rgb 34,35,36

set title "Signal Heatmap ".date tc rgb "white"

plot 'heatmap' u ($1):($2):($3) with dots lc palette

EOF

mv heatmap heatmap-$date
sudo cp heatmap-$date.png /run/dump1090-fa/heatmap.png
