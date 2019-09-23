#!/bin/bash

# Set receiver location and height above sea level in metres.

lat=
lon=
rh=

#Set raspberry pi IP or hostname here:

pi=raspberrypi

#Set raspberry pi username here:

un=pi

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
        rsync -amzht --info=progress2 --delete-after -e ssh $un@$pi:/run/timelapse1090/ $dir/data
        datadir=$dir/data
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

gnuplot -c /dev/stdin $rh $frame $timestamp $file $dir <<"EOF"

rh=ARG1
frame=ARG2
timestamp=ARG3
date=system("date -d @".timestamp)
file=ARG4
pwd=ARG5

set terminal pngcairo size 1920,1080 background rgb "black"
set output pwd.'/frames/elev-'.frame.'.png'
set datafile separator comma
set label date at screen 0.5, 0.95 center tc rgb "white"

unset grid
set border lc rgb "white"
set yrange [-3:20]
set xrange [0:360]
set xtics 30
set mxtics
set mytics
unset colorbox
set cbrange [0:45000]
#set palette defined (0 0 0 0.5, 1 0 0 1, 2 0 0.5 1, 3 0 1 1, 4 0.5 1 0.5, 5 1 1 0, 6 1 0.5 0, 7 1 0 0, 8 0.5 0 0)
set palette defined (0 0.5 0 0, 1 1 0 0, 2 1 0.5 0, 3 1 1 0, 4 0.5 1 0.5, 5 0 1 1, 6 0 0.5 1, 7 0 0 1, 8 0 0 0.5)

files=system("ls -1v /tmp/data*")


plot for [i=1:words(files)] word(files, i) u ($6):($7):($4) with points pt 7 ps 0.5 lc palette notitle

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
ffmpeg -framerate 120 -i tl-%05d.png -pix_fmt yuv420p -r 60 timelapse-elev.mp4
mv timelapse-elev.mp4 $dir
