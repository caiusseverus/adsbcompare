#! /bin/bash

#Set receiver location here
lat=0.0
lon=0.0

#Set altitude limits

low=5000
high=25000


let "secs=$1 * 60"
int=$2
date=$(date -I)
end=$(date --date=now+${1}mins)

echo "Gathering data every $2 seconds until $end"


SECONDS=0

while (( SECONDS < secs )); do
	cat /run/dump1090-fa/aircraft.json | jq -r '.aircraft | .[] | select(.lat != null) | select (.lon !=null) | select(.rssi != -49.5) | [.lon,.lat,.rssi,.alt_baro] | @csv' >> heatmap
	sleep $2
done

if [[ $1 == "-1" ]]; then
	for i in /run/timelapse1090/chunk_*.gz; do
		echo $i
		zcat $i | jq -r '.files | .[] | .aircraft | .[] | select(.lat != null) | select (.lon !=null) | select(.rssi != -49.5) | [.lon,.lat,.rssi,.alt_baro] | @csv' >>heatmap
	done
	for i in /run/timelapse1090/history_*.json; do
		sed -e '$d' $i | jq -r '.aircraft | .[] | select(.lat != null) | select (.lon !=null) | select(.rssi != -49.5) | [.lon,.lat,.rssi,.alt_baro] | @csv' >> heatmap
	done
fi


echo "Number of data points collected:"
wc -l ./heatmap


echo "Filtering altitudes"
awk -v low="$low" -F "," '$4 <= low' heatmap > /tmp/heatmap_low
awk -v high="$high" -F "," '$4 >= high' heatmap > /tmp/heatmap_high


echo "Generating Graphs - this could take several minutes with large data sets"

gnuplot -c /dev/stdin $lat $lon $date $low $high<<"EOF"

lat=ARG1
lon=ARG2
date=ARG3
low=ARG4
high=ARG5

set terminal pngcairo enhanced size 2400,2000
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
print "Generating all altitudes heatmap..."

plot 'heatmap' u ($1):($2):($3) with dots lc palette

set output 'heatmap_low-'.date.'.png'
set title "Signal Heatmap aircraft below ".low." feet - ".date tc rgb "white"
print "Generating low altitude heatmap..."


plot '/tmp/heatmap_low' u ($1):($2):($3) with dots lc palette

set output 'heatmap_high-'.date.'.png'
set title "Signal Heatmap aircraft above ".high." feet - ".date tc rgb "white"
print "Generating high altitude heatmap..."

plot '/tmp/heatmap_high' u ($1):($2):($3) with dots lc palette


EOF

rm /tmp/heatmap_*
mv heatmap heatmap-$date
sudo cp heatmap-$date.png /run/dump1090-fa/heatmap.png
sudo cp heatmap_low-$date.png /run/dump1090-fa/heatmap_low.png
sudo cp heatmap_high-$date.png /run/dump1090-fa/heatmap_high.png

