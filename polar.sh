#! /bin/bash

#Set receiver location and height above sea level here
lat=
lon=
rh=

#Set altitude limits

low=5000
high=25000

#Set plot range in nm

range=230

#Set raspberry pi IP or hostname here:

pi=raspberrypi

#Set raspberry pi username here:

un=pi

#Set heywhatsthat.com site ID here:

hwt=

# Keep data - yes/no

keep=yes

int=$2
date=$(date -I)
PWD=$(pwd)
archiveloc=/run/timelapse1090
TMPDIR=$(mktemp -d)
HWTDIR=$(mktemp -d)



mem=$(free -m|awk '/^Mem:/{print $2}')

if [ "$mem" -gt "1000" ]; then

        wdir=$TMPDIR
        echo "Using tmpfs : $wdir"

else
        wdir=$PWD
        echo "Using disk : $wdir"
fi

SECONDS=0

if [[ $1 == "-1" ]]; then

        if [ -d "$archiveloc" ]; then

        echo "Using local archive:"
        datadir=$archiveloc

        else

        echo "Retrieving remote data.."
        rsync -amzht --info=progress2 --delete-after -e ssh $un@$pi:/run/timelapse1090/ $PWD/data
        datadir=$PWD/data

        fi

        echo "Unpacking compressed data:"
        for i in $datadir/chunk_*.gz; do
                echo -n "."
                zcat $i | jq -r '.files | .[] | .aircraft | .[] | select(.lat != null) | select (.lon !=null) | select(.rssi != -49.5) | [.lon,.lat,.rssi,.alt_baro] | @csv' >> $wdir/heatmap


        done
        echo ""
        echo "Retrieving recent history:"
        for i in $datadir/history_*.json; do
                echo -n "."
                sed -e '$d' $i | jq -r '.aircraft | .[] | select(.lat != null) | select (.lon !=null) | select(.rssi != -49.5) | [.lon,.lat,.rssi,.alt_baro] | @csv' >> $wdir/heatmap
        done
        echo ""

else

        secs=$(($1 *60))
        echo $secs
        end=$(date --date=now+${1}mins)
        echo "Gathering data every $2 seconds until $end"

        while (( SECONDS < secs )); do
        jq -r '.aircraft | .[] | select(.lat != null) | select (.lon !=null) | select(.rssi != -49.5) | [.lon,.lat,.rssi,.alt_baro] | @csv' /run/dump1090-fa/aircraft.json >> $wdir/heatmap
        sleep $2
        done


fi



count=$(wc -l < $wdir/heatmap)

echo "Number of data points collected: $count"

echo "Calculating Range, Azimuth and Elevation data:"

nice -n 19 awk -i inplace -F "," -v rlat=$lat -v rlon=$lon -v rh=$rh 'function data(lat1,lon1,elev1,lat2,lon2,elev2,rssi,  lamda,a,c,dlat,dlon,x) {

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
    printf("%f,%f,%.1f,%.0f,%.0f,%f,%f\n",lon2,lat2 * (180 / 3.1415926),rssi,elev2 * 3.28,d,phi,lamda)
        }

    function radians(degree) { # degrees to radians
    return degree * (3.1415926 / 180.)}

        {data(rlat,rlon,rh,$2,$1,$4,$3)}' $wdir/heatmap

echo "Filtering altitudes"
awk -v low="$low" -F "," '$4 <= low' $wdir/heatmap > $wdir/heatmap_low
awk -v high="$high" -F "," '$4 >= high' $wdir/heatmap > $wdir/heatmap_high

echo "Processing heywhatsthat.com data:"

file=$PWD/upintheair.json

if [[ -f $file ]] && [[ ! -s $file ]]; then

echo "Removing empty upintheair.json"
rm $file

fi


if [ ! -f "$file" ]; then


  echo "Retrieving terrain profiles from heywhatsthat.com:"
  curl "http://www.heywhatsthat.com/api/upintheair.json?id=${hwt}&refraction=0.0&alts=50,606,1212,1818,2424,3030,3636,4242,4848,5454,6060,6667,7273,7879,8485,9091,9697,10303,10909,11515,12121" > upintheair.json


fi


for i in {0..20}; do

        ring=$(jq --argjson i "$i" --raw-output '.rings | .[$i] | .alt' upintheair.json)
        jq --argjson i "$i" --raw-output '.rings | .[$i] | .points | .[] | @csv' upintheair.json > $HWTDIR/$ring


done

for i in $(ls -1v $HWTDIR); do

awk -i inplace -F "," -v rlat="$lat" -v rlon="$lon" -v rh="$rh" 'function data(lat1,lon1,elev1,lat2,lon2,elev2,  lamda,a,c,dlat,dlon,x) {
                dlat = radians(lat2-lat1)
                dlon = radians(lon2-lon1)
                lat1 = radians(lat1)
                lat2 = radians(lat2)
                a = (sin(dlat/2))^2 + cos(lat1) * cos(lat2) * (sin(dlon/2))^2
                c = 2 * atan2(sqrt(a),sqrt(1-a))
                d = 6371000 * c
                x = atan2(sin(dlon * cos(lat2)), cos(lat1)*sin(lat2)-sin(lat1)*cos(lat2)*cos(dlon))
                phi = (x * (180 / 3.1415926) + 360) % 360
                lamda = (180 / 3.1415926) * ((elev2 - elev1) / d - d / (2 * 6371000))
                printf("%f,%f,%f,%f,%f,\n",lat2 * (180 / 3.1415926),lon2,d,phi,lamda)
                }

                function radians(degree) { # degrees to radians
                return degree * (3.1415926 / 180.)}

                {data(rlat,rlon,rh,$1,$2,$i)}' $HWTDIR/$i
done

for i in $(ls -1v $HWTDIR); do

        max=$(sort -t',' -k3nr $HWTDIR/$i | head -1)
        max="$max$i"
        echo $max >> $HWTDIR/max

        min=$(sort -t',' -k3n $HWTDIR/$i | head -1)
        min="$min$i"
        echo $min >> $HWTDIR/min
done

gnuplot -c /dev/stdin $lat $lon $date $low $high $rh $range $wdir $HWTDIR <<"EOF"

lat=ARG1
lon=ARG2
date=ARG3
low=ARG4
high=ARG5
rh=ARG6
range=ARG7
dir=ARG8
hwt=ARG9

set terminal pngcairo dashed enhanced size 2000,2000
set datafile separator comma
set object 1 rectangle from screen 0,0 to screen 1,1 fillcolor rgb "black" behind
set output 'polarheatmap-'.date.'.png'

set border lc rgb "white"

set cbrange [-40:0]
set cblabel "RSSI" tc rgb "white"
#set label at 0,0 "" point pointtype 7 lc rgb "cyan" ps 1.2 front
set palette rgb 21,22,23

set polar
set angles degrees
set theta clockwise top
set grid polar 45 linecolor rgb "white" front
set colorbox user vertical origin 0.9, 0.80 size 0.02, 0.15


set size square
set title "Signal Heatmap ".date tc rgb "white"
set xrange [-range:range]
set yrange [-range:range]
set rtics 50
set xtics 50
set ytics 50

print "Generating all altitudes heatmap..."

plot dir.'/heatmap' u ($6):($5/1852):($3) with dots lc palette, \
        hwt.'/12121' u  ($4):($3/1852) with lines lc rgb "white" notitle, \
        hwt.'/12121' u ($4):($3/1852) every 359::0::359 with lines lc rgb "white" notitle


set output 'polarheatmap_high-'.date.'.png'
set title "Signal Heatmap aircraft above ".high." feet - ".date tc rgb "white"
print "Generating high altitude heatmap..."

plot dir.'/heatmap_high' u ($6):($5/1852):($3) with dots lc palette, \
        hwt.'/12121' u  ($4):($3/1852) with lines lc rgb "white" notitle, \
        hwt.'/12121' u ($4):($3/1852) every 359::0::359 with lines lc rgb "white" notitle


set output 'polarheatmap_low-'.date.'.png'
set title "Signal Heatmap aircraft below ".low." feet - ".date tc rgb "white"
print "Generating low altitude heatmap..."
set xrange [-80:80]
set yrange [-80:80]
set rtics 20
set xtics 20
set ytics 20

plot dir.'/heatmap_low' u ($6):($5/1852):($3) with dots lc palette

set output 'closerange-'.date.'.png'
set title 'Close range signals - '.date tc rgb "white"
print "Generating close range heatmap"
set xrange [-5:5]
set yrange [-5:5]
set rtics 1
set xtics 1
set ytics 1

plot dir.'/heatmap_low' u ($6):($5/1852):($3) with points pt 7 ps 0.5 lc palette


reset

set terminal pngcairo enhanced size 1920,1080
set datafile separator comma
set output 'elevation-'.date.'.png'

set object 1 rectangle from screen 0,0 to screen 1,1 fillcolor rgb "black" behind
set cbrange [-40:0]
set title "Azimuth/Elevation plot" tc rgb "white"
set border lc rgb "white"
set cblabel "RSSI" tc rgb "white"
set colorbox user vertical origin 0.9, 0.75 size 0.02, 0.15
set grid linecolor rgb "white"
set palette rgb 21,22,23
set yrange [-2:15]
set xrange [0:360]
set xtics 45
set ytics 3

print "Generating elevation heatmap..."

plot dir.'/heatmap' u ($6):($7):($3) with dots lc palette, \
        hwt.'/50' u ($4):($5) with lines lc rgb "white" notitle

set terminal pngcairo enhanced size 1920,1080
set output 'altgraph-'.date.'.png'

set cblabel "RSSI" tc rgb "white"
set palette rgb 21,22,23
set colorbox user vertical origin 0.9, 0.1 size 0.02, 0.15


set title "Range/Altitude" tc rgb "white"
set xrange [*:250]
set yrange [0:45000]
set xtics 25
set ytics 5000

f(x) = (x**2 / 1.5129) - (rh * 3.3)

print "Generating Range/Altitude plot..."
unset key

plot dir.'/heatmap' u ($5/1852):($4):($3) with dots lc palette, f(x) lt rgb "white" notitle, \
        hwt.'/max' u ($3/1852):($6*3.3) with lines dt 2 lc rgb "green" title "Terrain limit" at end


set output 'closealt-'.date.'.png'
set title "Close Range/Altitude" tc rgb "white"
set xrange [0:50]
set yrange [0:10000]
set xtics 5
set ytics 500
set datafile missing NaN
print "Generating Close Range altitude plot"

plot dir.'/heatmap' u ($5/1852 <= 50 ? $5/1852 : 1/0):($4 <= 10000 ? $4:1/0):($3) with dots lc palette



EOF

if [ $keep == yes ]; then

mv $wdir/heatmap $PWD/polarheatmap-$date

fi

rm $wdir/heatmap_low
rm $wdir/heatmap_high
rm -r $TMPDIR
rm -r $HWTDIR

dumpdir=/run/dump1090-fa

if [ -d "$dumpdir" ]; then

sudo cp polarheatmap-$date.png $dumpdir/heatmap.png
sudo cp polarheatmap_low-$date.png $dumpdir/heatmap_low.png
sudo cp polarheatmap_high-$date.png $dumpdir/heatmap_high.png
sudo cp elevation-$date.png $dumpdir/elevation.png
sudo cp altgraph-$date.png $dumpdir/altgraph.png
sudo cp closealt-$date.png $dumpdir/closealt.png

sudo sh -c "cat > $dumpdir/plots.html" <<EOF

<!DOCTYPE html>
<html>
<body>

<h1>Heatmap plots created $date</h1>

<p>Heatmap</p>
<img src="heatmap.png" alt="Heatmap" width="1800">

<p>Aircraft below $low feet</p>
<img src="heatmap_low.png" alt="Low Altitude" width="1800">

<p>Aircraft above $high feet</p>
<img src="heatmap_high.png" alt="High Altitude" width="1800">

<p>Azimuth/Elevation plot</p>
<img src="elevation.png" alt="Elevation" width="1800">

<p>Range/Altitude</p>
<img src="altgraph.png" alt="Altitude" width="1800">

<p>Close Range Altitude</p>
<img src="closealt.png" alt="Close Range" width="1800">

</body>
</html>

EOF


echo "Graphs available at :"
echo "http://$pi/dump1090-fa/plots.html"


fi

echo "Graphs rendered in $SECONDS seconds"


