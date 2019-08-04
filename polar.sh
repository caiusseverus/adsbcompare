#! /bin/bash

#Set receiver location and height above sea level here
lat=0.0
lon=0.0
rh=0

#Set altitude limits

low=5000
high=25000

#Set maximum plot range in nm

range=230


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

echo "Calculating Range, Azimuth and Elevation data:"

nice -n 19 awk -F "," -v rlat=$lat -v rlon=$lon -v rh=$rh 'function data(lat1,lon1,elev1,lat2,lon2,elev2,  lamda,a,c,dlat,dlon,x) {

    dlat = radians(lat2-lat1)
    dlon = radians(lon2-lon1)
    lat1 = radians(lat1)
    lat2 = radians(lat2)
    elev2 = elev2 / 3.28
    a = (sin(dlat/2))^2 + cos(lat1) * cos(lat2) * (sin(dlon/2))^2
    c = 2 * atan2(sqrt(a),sqrt(1-a))
    d = 6371000 * c
    x = atan2(sin(dlon * cos(lat2)), cos(lat1)*sin(lat2)-sin(lat1)*cos(lat2)*cos(dlon))
    phi = (x * (180 / 3.1415926) + 360) % 360
    lamda = (180 / 3.1415926) * ((elev2 - elev1) / d - d / (2 * 6371000))
    printf("%.0f,%f,%f\n",d,phi,lamda)
        }

    function radians(degree) { # degrees to radians
    return degree * (3.1415926 / 180.)}

        {data(rlat,rlon,rh,$2,$1,$4)}' heatmap > /tmp/range.csv

paste -d "," heatmap /tmp/range.csv > polarheatmap

echo "Filtering altitudes"
awk -v low="$low" -F "," '$4 <= low' polarheatmap > /tmp/heatmap_low
awk -v high="$high" -F "," '$4 >= high' polarheatmap > /tmp/heatmap_high

gnuplot -c /dev/stdin $lat $lon $date $low $high $rh $range <<"EOF"

lat=ARG1
lon=ARG2
date=ARG3
low=ARG4
high=ARG5
rh=ARG6
range=ARG7

set terminal pngcairo enhanced size 2000,2000
set datafile separator comma
set object 1 rectangle from screen 0,0 to screen 1,1 fillcolor rgb "black" behind
set output 'polarheatmap-'.date.'.png'

set border lc rgb "white"

set cbrange [-40:0]
set cblabel "RSSI" tc rgb "white"
#set label at 0,0 "" point pointtype 7 lc rgb "cyan" ps 1.2 front
set palette rgb 34,35,36

set polar
set angles degrees
set theta clockwise top
set grid polar 45 linecolor rgb "white"
set colorbox user vertical origin 0.9, 0.80 size 0.02, 0.15


show angles
set size square
set xrange [-range:range]
set yrange [-range:range]
set rtics 50
set xtics 50
set ytics 50

set title "Signal Heatmap ".date tc rgb "white"
print "Generating all altitudes heatmap..."

plot 'polarheatmap' u ($6):($5/1852):($3) with dots lc palette


set output 'polarheatmap_high-'.date.'.png'
set title "Signal Heatmap aircraft above ".high." feet - ".date tc rgb "white"
print "Generating high altitude heatmap..."

plot '/tmp/heatmap_high' u ($6):($5/1852):($3) with dots lc palette


set output 'polarheatmap_low-'.date.'.png'
set title "Signal Heatmap aircraft below ".low." feet - ".date tc rgb "white"
print "Generating low altitude heatmap..."
set xrange [-120:120]
set yrange [-120:120]
set rtics 25
set xtics 25
set ytics 25

plot '/tmp/heatmap_low' u ($6):($5/1852):($3) with dots lc palette




reset

set terminal pngcairo enhanced size 1920,1080
set datafile separator comma
set output 'elevation-'.date.'.png'

set object 1 rectangle from screen 0,0 to screen 1,1 fillcolor rgb "black" behind
set cbrange [-40:0]
set title "Azimuth/Elevation plot" tc rgb "white"
set border lc rgb "white"
set grid linecolor rgb "white"
set palette rgb 34,35,36
set yrange [0:30]
set xrange [0:360]
set xtics 45
print "Generating elevation heatmap..."

plot 'polarheatmap' u ($6):($7):($3) with dots lc palette

set output 'altgraph-'.date.'.png'

set cblabel "RSSI" tc rgb "white"
set palette rgb 34,35,36
set colorbox user vertical origin 0.9, 0.1 size 0.02, 0.15


set title "Range/Altitude" tc rgb "white"
set xrange [0:*]
set yrange [0:45000]
set xtics 25
set ytics 5000

f(x) = (x**2 / 1.5129) - (rh * 3.3)

print "Generating Range/Altitude plot..."

plot 'polarheatmap-2019-08-02' u ($5/1852):($4):($3) with dots lc palette, f(x) lt rgb "white" notitle


EOF

rm /tmp/heatmap_*
rm heatmap
mv polarheatmap polarheatmap-$date
sudo cp polarheatmap-$date.png /run/dump1090-fa/heatmap.png
sudo cp polarheatmap_low-$date.png /run/dump1090-fa/heatmap_low.png
sudo cp polarheatmap_high-$date.png /run/dump1090-fa/heatmap_high.png
sudo cp elevation-$date.png /run/dump1090-fa/elevation.png
sudo cp altgraph-$date.png /run/dump1090-fa/altgraph.png

IP=$(ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')

echo "The following graphs are now available:"
echo "http://$IP/dump1090-fa/data/heatmap.png"
echo "http://$IP/dump1090-fa/data/heatmap_low.png"
echo "http://$IP/dump1090-fa/data/heatmap_high.png"
echo "http://$IP/dump1090-fa/data/elevation.png"
echo "http://$IP/dump1090-fa/data/altgraph.png"



