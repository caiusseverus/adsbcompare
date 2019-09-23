#!/bin/bash

# Set receiver location and height above sea level in metres.

lat=
lon=
rh=

#Set maximum range to be displayed on map.
range=100

TMPDIR=$(mktemp -d)
date=$(date -I)
echo $TMPDIR
dir=$PWD
archiveloc=/run/timelapse1090

if [[ ! -d $dir/frames ]]; then

mkdir frames

fi

if [[ ! -d $dir/data ]]; then

mkdir data

fi

rm -f /tmp/data*
rm -f $dir/frames/*.png


if [ -d "$archiveloc" ]; then

        echo "Using local archive:"
        datadir=$archiveloc
else

        echo "Retrieving remote data.."
        rsync -amzht --info=progress2 --delete-after -e ssh pi@raspberrypi:/run/timelapse1090/ $dir/data
        datadir=$dir/data
fi



world=$PWD/world_10m.txt
if [ ! -f "$world" ]; then

wget https://raw.githubusercontent.com/caiusseverus/adsbcompare/master/world_10m.txt

nice -n 19 awk  -i inplace -v rlat="$lat" -v rlon="$lon" 'function data(lat1,lon1,lat2,lon2,  a,c,dlat,dlon,x,t,y) {
    dlat = radians(lat2-lat1)
    dlon = radians(lon2-lon1)
    lat1 = radians(lat1)
    lat2 = radians(lat2)
    a = (sin(dlat/2))^2 + cos(lat1) * cos(lat2) * (sin(dlon/2))^2
    c = 2 * atan2(sqrt(a),sqrt(1-a))
    d = 6371000 * c
    t = atan2(sin(dlon * cos(lat2)), cos(lat1)*sin(lat2)-sin(lat1)*cos(lat2)*cos(dlon))
    phi = (t * (180 / 3.1415926) + 360) % 360
    x = d*cos(radians(-phi)+radians(90))
    y = d*sin(radians(-phi)+radians(90))
    printf("%f,%f,%f,%f,%0.0f\n",lon2,lat2 * (180 / 3.1415926),x,y,d)
        }
    function radians(degree) { # degrees to radians
    return degree * (3.1415926 / 180.)}
        {data(rlat,rlon,$2,$1)}' world_10m.txt

nice -n 19 awk -i inplace -F "," '!($5 > (350*1852)) || ($1 == 0)' world_10m.txt
nice -n 19 sed -i '/^$/d' world_10m.txt
nice -n 19 sed -i -e 's/^0.000000,0.000000.*$//' world_10m.txt
nice -n 19 sed -i -e :a -e '/./,$!d;/^\n*$/{$d;N;};/\n$/ba' world_10m.txt

fi

FRAME=0
cd $TMPDIR
for i in $(ls -rt $datadir/chunk_*.gz); do


        echo -n "Processing $i"
        split=$(basename "$i" .gz)
        zcat $i | sed -e '1d' -e '$d' | csplit -s -b%03d - '/^,$/' '{*}'

        for chunk in $(ls -rt $TMPDIR); do
        sed -i -e '/^,$/d' $chunk
        done


        for file in $(ls -1v $TMPDIR); do

                frame=$(printf "%05d" $FRAME)
                timestamp=$(jq -r '[.now] | .[]' $TMPDIR/$file)
                date=$(date -d @$timestamp)
                jq -r '.aircraft | .[] | select(.lat != null) | select(.lon != null) | select(.rssi != -49.5) | [.lon,.lat,.rssi,.alt_baro] | @csv' $TMPDIR/$file | \
                awk -F "," -v rlat=$lat -v rlon=$lon -v rh=$rh 'function data(lat1,lon1,elev1,lat2,lon2,elev2,rssi,  lamda,a,c,dlat,dlon,x) {
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
                lamda = (180 / 3.1415926) * atan2((elev2 - elev1) / d - d / (2 * 6371000),1)
                printf("%f,%f,%.1f,%.0f,%.0f,%f,%f\n",lon2,lat2,rssi,elev2 * 3.28,d,phi,lamda)
                }

                function radians(degree) { # degrees to radians
                return degree * (3.1415926 / 180.)}

                {data(rlat,rlon,rh,$2,$1,$4,$3)}' > /tmp/data0
                echo -n "."

gnuplot -c /dev/stdin $rh $frame $timestamp $file $dir $range <<"EOF"

rh=ARG1
frame=ARG2
timestamp=ARG3
date=system("date -d @".timestamp)
file=ARG4
pwd=ARG5
range=ARG6

set terminal pngcairo size 1920,1080 background rgb "black"
set output pwd.'/frames/map-'.frame.'.png'
set datafile separator comma
set label date at screen 0.5, 0.95 center tc rgb "white"

set border lc rgb "white"
unset colorbox
set cbrange [0:45000]
#set palette defined (0 0 0 0.5, 1 0 0 1, 2 0 0.5 1, 3 0 1 1, 4 0.5 1 0.5, 5 1 1 0, 6 1 0.5 0, 7 1 0 0, 8 0.5 0 0)
set palette defined (0 0.5 0 0, 1 1 0 0, 2 1 0.5 0, 3 1 1 0, 4 0.5 1 0.5, 5 0 1 1, 6 0 0.5 1, 7 0 0 1, 8 0 0 0.5)

files=system("ls -1v /tmp/data*")

yrange=range/1.7778
set xrange [-range:range]
set yrange [-yrange:yrange]
set grid xtics lt 0 lw 1 lc rgb "white"
set grid ytics lt 0 lw 1 lc rgb "white"
set mxtics
set mytics
set angles degrees
set xtics 20
set ytics 20
set label "" at 0,0 point pointtype 1 ps 2 lc rgb "green" front

plot for [i=1:words(files)] word(files, i) u (($5/1852) * cos (- $6 + 90)):(($5/1852) * sin (-$6 + 90)):($4) w points pt 7 ps 0.5 lc palette notitle, \
        pwd.'/world_10m.txt' u ($3/1852):($4/1852) w lines lc rgb "green" notitle
EOF

FRAME=$(($FRAME + 1))

rm -f /tmp/data10

mv /tmp/data9 /tmp/data10 2>/dev/null
mv /tmp/data8 /tmp/data9 2>/dev/null
mv /tmp/data7 /tmp/data8 2>/dev/null
mv /tmp/data6 /tmp/data7 2>/dev/null
mv /tmp/data5 /tmp/data6 2>/dev/null
mv /tmp/data4 /tmp/data5 2>/dev/null
mv /tmp/data3 /tmp/data4 2>/dev/null
mv /tmp/data2 /tmp/data3 2>/dev/null
mv /tmp/data1 /tmp/data2 2>/dev/null
mv /tmp/data0 /tmp/data1 2>/dev/null

        done
echo "|"

rm $TMPDIR/*


done

cd $dir/frames
ffmpeg -framerate 120 -i map-%05d.png -pix_fmt yuv420p -r 60 timelapse-map.mp4
mv timelapse-map.mp4 $dir
