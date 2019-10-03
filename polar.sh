#! /bin/bash
set -e

if [[ -f polar.conf ]]; then
echo "Using config file"
source polar.conf

else
echo "No config file found - a new one will be written"
#Set receiver location and height above sea level here
lat=
lon=
rh=

#Set altitude limits

low=5000
high=25000

#Set plot range in nm

range=230

# Include mlat aircraft? yes/no/mlat - setting to mlat will include only mlat results.

mlat=no

#Set raspberry pi IP or hostname here:

pi=raspberrypi

#Set raspberry pi username here:

un=pi

#Set heywhatsthat.com site ID here - Note that the script will not run without it. If you want to use a new ID, delete any existing upintheair.json first

hwt=

# Keep data - yes/no

keep=yes

cat <<EOF > polar.conf
lat=$lat
lon=$lon
rh=$rh
low=$low
high=$high
range=$range
mlat=$mlat
pi=$pi
un=$un
hwt=$hwt
keep=$keep
EOF

fi

int=$2
date=$(date -I)
PWD=$(pwd)
archiveloc=/run/timelapse1090
dump1090loc=/run/dump1090-fa
dump1090data=/dump1090-fa/data
TMPDIR=$(mktemp -d)
HWTDIR=$(mktemp -d)
hwth=$(($rh +10))

if [ -z "$hwt" ]; then
        echo "Please set your HeyWhatsThat ID before running this script"
        exit
else
        echo "HWT OK"

fi

if [[ $mlat == "yes" ]]; then
        echo "ADS-B and MLAT aircraft will be plotted"
elif [[ $mlat == "no" ]]; then
        echo "ADS-B aircraft only will be plotted"
elif [[ $mlat == "mlat" ]]; then
        echo "MLAT aircraft only will be plotted"
fi


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
                if [[ $mlat == "yes" ]]; then
                zcat $i | jq -r '.files | .[] | .aircraft | .[] | select(.lat != null) | select (.lon !=null) | select(.rssi != -49.5) | select( (has("tisb") | not) or (.tisb | contains(["lat"]) | not) ) | [.lon,.lat,.rssi,.alt_baro] | @csv' >> $wdir/heatmap
                elif [[ $mlat == "no" ]]; then
                zcat $i | jq -r '.files | .[] | .aircraft | .[] | select(.lat != null) | select (.lon !=null) | select(.rssi != -49.5) | select( (has("tisb") | not) or (.tisb | contains(["lat"]) | not) ) | select(any(.mlat[] ; .) | not) | [.lon,.lat,.rssi,.alt_baro] | @csv' >> $wdir/heatmap
                elif [[ $mlat == "mlat" ]]; then
                zcat $i | jq -r '.files | .[] | .aircraft | .[] | select(.lat != null) | select (.lon !=null) | select(.rssi != -49.5) | select( (has("tisb") | not) or (.tisb | contains(["lat"]) | not) ) | select(any(.mlat[] ; .)) | [.lon,.lat,.rssi,.alt_baro] | @csv' >> $wdir/heatmap
                fi
        done

        echo ""
        echo "Retrieving recent history:"

        for i in $datadir/history_*.json; do
                echo -n "."
                if [[ $mlat == "yes" ]]; then
                sed -e '$d' $i | jq -r '.aircraft | .[] | select(.lat != null) | select (.lon !=null) | select(.rssi != -49.5) | select( (has("tisb") | not) or (.tisb | contains(["lat"]) | not) ) | [.lon,.lat,.rssi,.alt_baro] | @csv' >> $wdir/heatmap
                elif [[ $mlat == "no" ]]; then
                sed -e '$d' $i | jq -r '.aircraft | .[] | select(.lat != null) | select (.lon !=null) | select(.rssi != -49.5) | select( (has("tisb") | not) or (.tisb | contains(["lat"]) | not) ) | select(any(.mlat[] ; .) | not) | [.lon,.lat,.rssi,.alt_baro] | @csv' >> $wdir/heatmap
                elif [[ $mlat == "mlat" ]]; then
                sed -e '$d' $i | jq -r '.aircraft | .[] | select(.lat != null) | select (.lon !=null) | select(.rssi != -49.5) | select( (has("tisb") | not) or (.tisb | contains(["lat"]) | not) ) | select(any(.mlat[] ; .)) | [.lon,.lat,.rssi,.alt_baro] | @csv' >> $wdir/heatmap
                fi

        done
        echo ""

else

        if [ -d "$dump1090loc" ]; then

        secs=$(($1 *60))
        end=$(date --date=now+${1}mins)
        echo "Gathering data every $2 seconds until $end"

        while (( SECONDS < secs )); do
        if [[ $mlat == "yes" ]]; then
        jq -r '.aircraft | .[] | select(.lat != null) | select (.lon !=null) | select(.rssi != -49.5) | select( (has("tisb") | not) or (.tisb | contains(["lat"]) | not) ) | [.lon,.lat,.rssi,.alt_baro] | @csv' $dump1090loc/aircraft.json >> $wdir/heatmap
        elif [[ $mlat == "no" ]]; then
        jq -r '.aircraft | .[] | select(.lat != null) | select (.lon !=null) | select(.rssi != -49.5) | select( (has("tisb") | not) or (.tisb | contains(["lat"]) | not) ) | select(any(.mlat[] ; .) | not) | [.lon,.lat,.rssi,.alt_baro] | @csv' $dump1090loc/aircraft.json >> $wdir/heatmap
        elif [[ $mlat == "mlat" ]]; then
        jq -r '.aircraft | .[] | select(.lat != null) | select (.lon !=null) | select(.rssi != -49.5) | select( (has("tisb") | not) or (.tisb | contains(["lat"]) | not) ) | select(any(.mlat[] ; .)) | [.lon,.lat,.rssi,.alt_baro] | @csv' $dump1090loc/aircraft.json >> $wdir/heatmap
        fi
        sleep $2
        done

        else

        STATUSCODE=$(curl --silent --output /dev/null --write-out "%{http_code}" http://${pi}/${dump1090data}/aircraft.json)

         if [[ ${STATUSCODE} -ne '200' ]]; then
                echo -e "http://${pi}/${dump1090data}/aircraft.json - ERR .. EXITING ..."
                exit 1
         else
                secs=$(($1 *60))
                end=$(date --date=now+${1}mins)
                echo "Gathering data every $2 seconds until $end"

                while (( SECONDS < secs )); do
                if [[ $mlat == "yes" ]]; then
                curl -sS http://$pi/$dump1090data/aircraft.json | jq -r '.aircraft | .[] | select(.lat != null) | select (.lon !=null) | select(.rssi != -49.5) | select( (has("tisb") | not) or (.tisb | contains(["lat"]) | not) ) | [.lon,.lat,.rssi,.alt_baro] | @csv' >> $wdir/heatmap
                elif [[ $mlat == "no" ]]; then
                curl -sS http://$pi/$dump1090data/aircraft.json | jq -r '.aircraft | .[] | select(.lat != null) | select (.lon !=null) | select(.rssi != -49.5) | select( (has("tisb") | not) or (.tisb | contains(["lat"]) | not) ) | select(any(.mlat[] ; .) | not) | [.lon,.lat,.rssi,.alt_baro] | @csv' >> $wdir/heatmap
                elif [[ $mlat == "mlat" ]]; then
                curl -sS http://$pi/$dump1090data/aircraft.json | jq -r '.aircraft | .[] | select(.lat != null) | select (.lon !=null) | select(.rssi != -49.5) | select( (has("tisb") | not) or (.tisb | contains(["lat"]) | not) ) | select(any(.mlat[] ; .)) | [.lon,.lat,.rssi,.alt_baro] | @csv' >> $wdir/heatmap
                fi
                sleep $2
                done
        fi
        fi

fi



count=$(wc -l < $wdir/heatmap)

echo "Number of data points collected: $count"

echo "Calculating Range, Azimuth and Elevation data:"

nice -n 19 awk -i inplace -F "," -v rlat=$lat -v rlon=$lon -v rh=$rh 'function data(lat1,lon1,elev1,lat2,lon2,elev2,rssi,  lamda,a,c,dlat,dlon,x) {
    if(elev2=="ground") {elev2=0}
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
  curl "http://www.heywhatsthat.com/api/upintheair.json?id=${hwt}&refraction=0.14&alts=$hwth,606,1212,1818,2424,3030,3636,4242,4848,5454,6060,6667,7273,7879,8485,9091,9697,10303,10909,11515,12121" > upintheair.json


fi


for i in {0..20}; do

        ring=$(jq --argjson i "$i" --raw-output '.rings | .[$i] | .alt' upintheair.json)
        nice -n 19 jq --argjson i "$i" --raw-output '.rings | .[$i] | .points | .[] | @csv' upintheair.json > $HWTDIR/$ring


done

for i in $(ls -1v $HWTDIR); do

nice -n 19 awk -i inplace -F "," -v rlat="$lat" -v rlon="$lon" -v rh="$rh" -v hwth="$i" 'function data(lat1,lon1,elev1,lat2,lon2,elev2,  lamda,a,c,dlat,dlon,x) {
                dlat = radians(lat2-lat1)
                dlon = radians(lon2-lon1)
                lat1 = radians(lat1)
                lat2 = radians(lat2)
                a = (sin(dlat/2))^2 + cos(lat1) * cos(lat2) * (sin(dlon/2))^2
                c = 2 * atan2(sqrt(a),sqrt(1-a))
                d = 6371000 * c
                x = atan2(sin(dlon * cos(lat2)), cos(lat1)*sin(lat2)-sin(lat1)*cos(lat2)*cos(dlon))
                phi = (x * (180 / 3.1415926) + 360) % 360
                lamda = (180 / 3.1415926) * atan2((elev2 - elev1) / d - d / (2 * 6371000),1)
                printf("%f,%f,%f,%.0f,%f,\n",lat2 * (180 / 3.1415926),lon2,d,phi,lamda)
                }
                function radians(degree) { # degrees to radians
                return degree * (3.1415926 / 180.)}
                {data(rlat,rlon,rh,$1,$2,hwth)}' $HWTDIR/$i
done

for i in $(ls -1v $HWTDIR); do

        max=$(sort -t',' -k3nr $HWTDIR/$i | head -1)
        max="$max$i"
        echo $max >> $HWTDIR/max

        min=$(sort -t',' -k3n $HWTDIR/$i | head -1)
        min="$min$i"
        echo $min >> $HWTDIR/min
done

mv $HWTDIR/$hwth ${HWTDIR}/horiz

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



nice -n 19 gnuplot -c /dev/stdin $lat $lon $date $low $high $rh $range $wdir $HWTDIR <<"EOF"
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
stats dir.'/heatmap' u ($3) noout
set cbrange [(STATS_mean - 2.5 * STATS_stddev):0]
set cblabel "RSSI" tc rgb "white"
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
plot dir.'/heatmap' u ($6):($5/1852):($3) with points pt 7 ps 0.5 lc palette
reset
set terminal pngcairo enhanced size 1920,1080
set datafile separator comma
set output 'elevation-'.date.'.png'
set object 1 rectangle from screen 0,0 to screen 1,1 fillcolor rgb "black" behind
set cbrange [(STATS_mean - 2.5 * STATS_stddev):0]
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
        hwt.'/12121' u ($4):($5) with lines lc rgb "white" notitle
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

set terminal pngcairo enhanced size 2000,2000
set title "Low altitude with map" tc rgb "white"
set output 'lowmap-'.date.'.png'
set xrange [-80:80]
set yrange [-80:80]
set xtics 5
set ytics 5
set mxtics
set mytics
set angles degrees
set colorbox user vertical origin 0.9, 0.80 size 0.02, 0.15
set label "" at 0,0 point pointtype 1 ps 2 lc rgb "green" front

print "Generating low heatmap with map overlay"

plot dir.'/heatmap_low' u (($5/1852) * cos (- $6 + 90)):(($5/1852) * sin (-$6 + 90)):($3) w dots lc palette, \
        'world_10m.txt' u ($3/1852):($4/1852) w lines lc rgb "green" notitle

set title "Heatmap with map overlay"
set output 'mapol-'.date.'.png'
set xrange [-range:range]
set yrange [-range:range]
set xtics 25
set ytics 25

plot dir.'/heatmap' u (($5/1852) * cos (- $6 + 90)):(($5/1852) * sin (-$6 + 90)):($3) w dots lc palette, \
        'world_10m.txt' u ($3/1852):($4/1852) w lines lc rgb "green" notitle, \
        hwt.'/12121' u  (($3/1852) * cos (- $4 +90)):(($3/1852) * sin (- $4 + 90)) with lines lc rgb "white" notitle, \
        hwt.'/12121' u (($3/1852) * cos (- $4 +90)):(($3/1852) * sin (- $4 + 90)) every 359::0::359 with lines lc rgb "white" notitle


EOF

if [ $keep == yes ]; then

mv $wdir/heatmap $PWD/polarheatmap-$date
rm $wdir/heatmap_low
rm $wdir/heatmap_high

else

rm $wdir/heatmap
rm $wdir/heatmap_low
rm $wdir/heatmap_high

fi

rm -r $TMPDIR
rm -r $HWTDIR
dumpdir=/usr/share/dump1090-fa/html/plots

if [ -d /usr/share/dump1090-fa ] && [ ! -d $dumpdir ]; then

sudo mkdir /usr/share/dump1090-fa/html/plots

fi

if [ -d "$dumpdir" ]; then

sudo cp polarheatmap-$date.png $dumpdir/heatmap.png
sudo cp polarheatmap_low-$date.png $dumpdir/heatmap_low.png
sudo cp polarheatmap_high-$date.png $dumpdir/heatmap_high.png
sudo cp elevation-$date.png $dumpdir/elevation.png
sudo cp altgraph-$date.png $dumpdir/altgraph.png
sudo cp closealt-$date.png $dumpdir/closealt.png
sudo cp closerange-$date.png $dumpdir/closerange.png
sudo cp lowmap-$date.png $dumpdir/lowmap.png
sudo cp mapol-$date.png $dumpdir/mapol.png

date2=$(date +%T)

if [[ $mlat == "yes" ]]; then
        mlatstat="ADS-B and MLAT positions."
elif [[ $mlat == "no" ]]; then
        mlatstat="ADS-B positions only."
elif [[ $mlat == "mlat" ]]; then
        mlatstat="MLAT positions only."
fi

sudo sh -c "cat > $dumpdir/index.html" <<EOF
<!DOCTYPE html>
<html>
<style>
img {
    max-width:100%;
    height:auto;
}
</style>
<body>
<h1>Heatmap plots created on $date at $date2 from $count samples.</h1>
<h2>Plots include $mlatstat</h2>
<p>Heatmap</p>
<img src="heatmap.png" alt="Heatmap">
<p>Aircraft below $low feet</p>
<img src="heatmap_low.png" alt="Low Altitude">
<p>Aircraft above $high feet</p>
<img src="heatmap_high.png" alt="High Altitude">
<p>Azimuth/Elevation plot</p>
<img src="elevation.png" alt="Elevation">
<p>Range/Altitude</p>
<img src="altgraph.png" alt="Altitude">
<p>Close Range Altitude</p>
<img src="closealt.png" alt="Close Range">
<p>Close Range</p>
<img src="closerange.png" alt="Close Range">
<p>Low altitude with map overlay</p>
<img src="lowmap.png" alt="Map">
<p>Plot with map overlay</p>
<img src="mapol.png" alt="Map">
</body>
</html>
EOF


echo "Graphs available at :"
echo "http://$pi/dump1090-fa/plots/"


fi

echo "Graphs rendered in $SECONDS seconds"
