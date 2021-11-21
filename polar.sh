#! /bin/bash
set -e

#Note - settings here are written to polar.conf on first run - values there will be used in preference to these for subsequent runs.

#Set receiver location and height above sea level here - only required if not using heywahtsthat data.
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

# Filter interval

filter=10

if [[ -f polar.conf ]]; then
echo "Config file found"
source polar.conf

else
echo "No config file found - a new one will be written"

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
filter=$filter
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

if [ -z "$hwt" ]; then
        echo "No HeyWhatsThat ID found"
        echo "0,0,0,0,0" > $HWTDIR/12121
        echo "0,0,0,0,0,0" > $HWTDIR/max
else
        echo "HWT OK"

echo "Processing heywhatsthat.com data:"

file=$PWD/upintheair.json

if [ -f $file ]; then

hwtfile=$(jq --raw-output '.id' $file)

if [  ! "$hwt" == "$hwtfile" ]; then
        echo "Heywhatsthat ID has changed - downloading new file"
        rm $PWD/upintheair.json

fi

fi

if [[ -f $file ]] && [[ ! -s $file ]]; then

echo "Removing empty upintheair.json"
rm $file

fi


if [ ! -f "$file" ]; then


  echo "Retrieving terrain profiles from heywhatsthat.com:"
  curl "http://www.heywhatsthat.com/api/upintheair.json?id=${hwt}&refraction=0.14&alts=606,1212,1818,2424,3030,3636,4242,4848,5454,6060,6667,7273,7879,8485,9091,9697,10303,10909,11515,12121,13716" > upintheair.json


fi

echo ""
echo "Setting receiver position from heywhatsthat data. If these values do not match what you are expecting, please check the heywhatsthat ID is correct and that it was generated with the correct location"

lat=$(jq --raw-output '.lat' $file)
lon=$(jq --raw-output '.lon' $file)
rh=$(jq --raw-output '.elev_amsl' $file)

echo "Latitude: " $lat
echo "Longitude: " $lon
echo "Height: " $rh
echo ""

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

jq_nocrud="select( (has(\"tisb\") | not) or (.tisb | contains([\"lat\"]) | not) ) | select(.rssi != -49.5)"
jq_base=".aircraft | .[] | select(.seen_pos != null) | select(.seen_pos <= $filter) | $jq_nocrud"
jq_end="[.lon,.lat,.rssi,.alt_baro] | @csv"
jq_both="$jq_base | $jq_end"
jq_adsb="$jq_base | select(any(.mlat[] ; .) | not) | $jq_end"
jq_mlat="$jq_base | select(any(.mlat[] ; .)) | $jq_end"

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
                zcat $i | jq -r ".files | .[] | $jq_both" >> $wdir/heatmap
                elif [[ $mlat == "no" ]]; then
                zcat $i | jq -r ".files | .[] | $jq_adsb" >> $wdir/heatmap
                elif [[ $mlat == "mlat" ]]; then
                zcat $i | jq -r ".files | .[] | $jq_mlat" >> $wdir/heatmap
                fi
        done

        echo ""
        echo "Retrieving recent history:"

        for i in $datadir/history_*.json; do
                echo -n "."
                if [[ $mlat == "yes" ]]; then
                sed -e '$d' $i | jq -r "$jq_both" >> $wdir/heatmap
                elif [[ $mlat == "no" ]]; then
                sed -e '$d' $i | jq -r "$jq_adsb" >> $wdir/heatmap
                elif [[ $mlat == "mlat" ]]; then
                sed -e '$d' $i | jq -r "$jq_mlat" >> $wdir/heatmap
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
        jq -r "$jq_both" $dump1090loc/aircraft.json >> $wdir/heatmap
        elif [[ $mlat == "no" ]]; then
        jq -r "$jq_adsb" $dump1090loc/aircraft.json >> $wdir/heatmap
        elif [[ $mlat == "mlat" ]]; then
        jq -r "$jq_mlat" $dump1090loc/aircraft.json >> $wdir/heatmap
        fi
        sleep $2
        done

        else

        STATUSCODE=$(curl --silent --output /dev/null --write-out "%{http_code}" http://${pi}${dump1090data}/aircraft.json)

         if [[ ${STATUSCODE} -ne '200' ]]; then
                echo -e "http://${pi}/${dump1090data}/aircraft.json - ERR .. EXITING ..."
                exit 1
         else
                secs=$(($1 *60))
                end=$(date --date=now+${1}mins)
                echo "Gathering data every $2 seconds until $end"

                while (( SECONDS < secs )); do
                if [[ $mlat == "yes" ]]; then
                curl -sS http://${pi}${dump1090data}/aircraft.json | jq -r '.aircraft | .[] | select(.seen_pos !=null) | select(.seen_pos <="$filter") | select(.rssi != -49.5) | select( (has("tisb") | not) or (.tisb | contains(["lat"]) | not) ) | [.lon,.lat,.rssi,.alt_baro] | @csv' >> $wdir/heatmap
                elif [[ $mlat == "no" ]]; then
                curl -sS http://${pi}${dump1090data}/aircraft.json | jq -r '.aircraft | .[] | select(.seen_pos !=null) | select(.seen_pos <="$filter") | select(.rssi != -49.5) | select( (has("tisb") | not) or (.tisb | contains(["lat"]) | not) ) | select(any(.mlat[] ; .) | not) | [.lon,.lat,.rssi,.alt_baro] | @csv' >> $wdir/heatmap
                elif [[ $mlat == "mlat" ]]; then
                curl -sS http://${pi}${dump1090data}/aircraft.json | jq -r '.aircraft | .[] | select(.seen_pos !=null) | select(.seen_pos <="$filter") | select(.rssi != -49.5) | select( (has("tisb") | not) or (.tisb | contains(["lat"]) | not) ) | select(any(.mlat[] ; .)) | [.lon,.lat,.rssi,.alt_baro] | @csv' >> $wdir/heatmap
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


world=$PWD/world_10m.txt

if [ ! -f "$world" ]; then

wget https://raw.githubusercontent.com/caiusseverus/adsbcompare/master/world_10m.txt
#cp borders_10m.txt world_10m.txt

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
nice -n 19 sed -i -e 's/^0.000000.*$//' world_10m.txt
nice -n 19 sed -i -e :a -e '/./,$!d;/^\n*$/{$d;N;};/\n$/ba' world_10m.txt
nice -n 19 sed -i 'N;/^\n$/D;P;D;' world_10m.txt

fi

ap=$PWD/airports.csv

if [ ! -f "$ap" ]; then

curl https://ourairports.com/data/airports.csv | cut -d "," -f2,3,5,6,7,14 | tr -d '"' > $PWD/airports.csv

sed -i '1d' $PWD/airports.csv

awk -F "," -i inplace -v rlat="$lat" -v rlon="$lon" 'function data(lat1,lon1,lat2,lon2,  a,c,dlat,dlon,x,t,y) {
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
    printf("%s,%s,%f,%f,%.0f,%s,%.0f,%0.2f,%.0f,%.0f\n",$1,$2,$3,$4,$5,$6,d,phi,x,y)
        }
    function radians(degree) { # degrees to radians
    return degree * (3.1415926 / 180.)}
        {data(rlat,rlon,$3,$4)}' $PWD/airports.csv

awk -i inplace -F "," '!($7 > (350*1852))' $PWD/airports.csv

fi

awk -F "," '$2 == "large_airport"' $PWD/airports.csv > $wdir/large
awk -F "," '$2 == "medium_airport"' $PWD/airports.csv > $wdir/medium
awk -F "," '$2 == "small_airport"' $PWD/airports.csv > $wdir/small
awk -F "," '$2 == "heliport"' $PWD/airports.csv >> $wdir/small

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
set xrange [-10:10]
set yrange [-10:10]
set rtics 1
set xtics 1
set ytics 1
plot dir.'/heatmap' u ($6):($5/1852):($3) with points pt 7 ps 0.5 lc palette, \
        dir.'/large' u ($8):($7/1852) with points pt 7 ps 1.5 lc rgb "green" notitle, \
        dir.'/large' u ($8):($7/1852):($1) with labels offset 1,-1 tc rgb "green", \
        dir.'/medium' u ($8):($7/1852) with points pt 7 ps 1.5 lc rgb "green" notitle, \
        dir.'/medium' u ($8):($7/1852):($1) with labels offset 1,-1 tc rgb "green", \
        dir.'/small' u ($8):($7/1852):($1) with labels offset 1,-1 tc rgb "green", \
        dir.'/small' u ($8):($7/1852) with points pt 7 ps 1.5 lc rgb "green" notitle

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
        hwt.'/12121' u ($4):($5) with lines lc rgb "white" notitle, \
        dir.'/large' u ($7/1852 <= 50 ? $8 : 1/0):(-1) with points pt 9 ps 2 lc rgb "white" notitle, \
        dir.'/large' u ($7/1852 <= 50 ? $8 : 1/0):(-1):($6) with labels offset 0,-1.5 tc rgb "white" font ",8", \
        dir.'/medium' u ($7/1852 <= 25 ? $8 : 1/0):(-1) with points pt 9 ps 2 lc rgb "white" notitle, \
        dir.'/medium' u ($7/1852 <= 25 ? $8 : 1/0):(-1):($6) with labels offset 0,-1.5 tc rgb "white" font ",8"

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
set yrange [-500:10000]
set xtics 5
set ytics 500
print "Generating Close Range altitude plot"
plot dir.'/heatmap' u ($5/1852 <= 50 ? $5/1852 : 1/0):($4 <= 10000 ? $4:1/0):($3) with dots lc palette, \
        dir.'/large' u ($7/1852 <= 50 ? $7/1852 : 1/0):($5) w points pt 9 ps 1 lc rgb "white", \
        dir.'/large' u ($7/1852 <= 50 ? $7/1852 : 1/0):($5-150):($6) with labels tc rgb "white" font ",8", \
        dir.'/medium' u ($7/1852 <= 40 ? $7/1852 : 1/0):($5) w points pt 9 ps 1 lc rgb "white", \
        dir.'/medium' u ($7/1852 <= 40 ? $7/1852 : 1/0):($5-150):($6) with labels tc rgb "white" font ",8", \
        dir.'/small' u ($7/1852 <= 10 ? $7/1852 : 1/0):($5) w points pt 9 ps 1 lc rgb "white", \
        dir.'/small' u ($7/1852 <= 10 ? $7/1852 : 1/0):($5-150):($6) with labels tc rgb "white" font ",8", \
        0 lc rgb "white"

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
        'world_10m.txt' u ($3/1852):($4/1852) w lines lc rgb "green" notitle, \
        dir.'/large' u ($9/1852):($10/1852) with points pt 7 ps 2 lc rgb "green" notitle, \
        dir.'/large' u ($9/1852):($10/1852):($6) with labels offset char 2,-1 tc rgb "green", \
        dir.'/medium' u ($9/1852):($10/1852) with points pt 7 ps 1 lc rgb "green" notitle, \
        dir.'/medium' u ($9/1852):($10/1852):($6) with labels offset char 2,-1 tc rgb "green", \
        dir.'/small' u ($9/1852):($10/1852) with points pt 7 ps 0.3 lc rgb "green" notitle

set title "Heatmap with map overlay"
set output 'mapol-'.date.'.png'
set xrange [-range:range]
set yrange [-range:range]
set xtics 25
set ytics 25

plot dir.'/heatmap' u (($5/1852) * cos (- $6 + 90)):(($5/1852) * sin (-$6 + 90)):($3) w dots lc palette, \
        'world_10m.txt' u ($3/1852):($4/1852) w lines lc rgb "green" notitle, \
        hwt.'/12121' u  (($3/1852) * cos (- $4 +90)):(($3/1852) * sin (- $4 + 90)) with lines lc rgb "white" notitle, \
        hwt.'/12121' u (($3/1852) * cos (- $4 +90)):(($3/1852) * sin (- $4 + 90)) every 359::0::359 with lines lc rgb "white" notitle, \
        dir.'/large' u ($9/1852):($10/1852) with points pt 7 ps 1 lc rgb "green" notitle, \
        dir.'/medium' u ($9/1852):($10/1852) with points pt 7 ps 0.75 lc rgb "green" notitle


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

rm $wdir/large
rm $wdir/medium
rm $wdir/small
rm -r $TMPDIR
rm -r $HWTDIR
dumpdir=/usr/share/skyaware/html/plots

if [[ ! -d "$PWD/results/$date" ]]; then
   mkdir -p $PWD/results/$date
   sudo mv polarheatmap-$date.png $PWD/results/$date/heatmap-$date.png
   sudo mv polarheatmap_low-$date.png $PWD/results/$date/heatmap_low-$date.png
   sudo mv polarheatmap_high-$date.png $PWD/results/$date/heatmap_high-$date.png
   sudo mv elevation-$date.png $PWD/results/$date/elevation-$date.png
   sudo mv altgraph-$date.png $PWD/results/$date/altgraph-$date.png
   sudo mv closealt-$date.png $PWD/results/$date/closealt-$date.png
   sudo mv closerange-$date.png $PWD/results/$date/closerange-$date.png
   sudo mv lowmap-$date.png $PWD/results/$date/lowmap-$date.png
   sudo mv mapol-$date.png $PWD/results/$date/mapol-$date.png
fi

if [ -d /usr/share/skyaware ] && [ ! -d $dumpdir ]; then

sudo mkdir /usr/share/skyaware/html/plots

fi

if [ -d "$dumpdir" ]; then

sudo cp $PWD/results/$date/heatmap-$date.png $dumpdir/heatmap.png
sudo cp $PWD/results/$date/heatmap_low-$date.png $dumpdir/heatmap_low.png
sudo cp $PWD/results/$date/heatmap_high-$date.png $dumpdir/heatmap_high.png
sudo cp $PWD/results/$date/elevation-$date.png $dumpdir/elevation.png
sudo cp $PWD/results/$date/altgraph-$date.png $dumpdir/altgraph.png
sudo cp $PWD/results/$date/closealt-$date.png $dumpdir/closealt.png
sudo cp $PWD/results/$date/closerange-$date.png $dumpdir/closerange.png
sudo cp $PWD/results/$date/lowmap-$date.png $dumpdir/lowmap.png
sudo cp $PWD/results/$date/mapol-$date.png $dumpdir/mapol.png

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
body {
    background-image: url(data:image/png;base64,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)!important;
    color:cornflowerblue;
    font-family:monospace;
}
</style>
<body>
<h1>Heatmap plots created on $date at $date2 from $count samples.</h1>
<h2>Plots include $mlatstat</h2>
<p><h3>Heatmap</h3></p>
<img src="heatmap.png" alt="Heatmap">
<p><h3>Aircraft below $low feet</h3></p>
<img src="heatmap_low.png" alt="Low Altitude">
<p><h3>Aircraft above $high feet</h3></p>
<img src="heatmap_high.png" alt="High Altitude">
<p><h3>Azimuth/Elevation plot</h3></p>
<img src="elevation.png" alt="Elevation">
<p><h3>Range/Altitude</h3></p>
<img src="altgraph.png" alt="Altitude">
<p><h3>Close Range Altitude</h3></p>
<img src="closealt.png" alt="Close Range">
<p><h3>Close Range</h3></p>
<img src="closerange.png" alt="Close Range">
<p><h3>Low altitude with map overlay</h3></p>
<img src="lowmap.png" alt="Map">
<p><h3>Plot with map overlay</h3></p>
<img src="mapol.png" alt="Map">
<p><h3>Altitude Heatmap</h3></p>
<img src="altmap.png" alt="Altitude Map">
</body>
</html>
EOF


echo "Graphs available at :"
echo "http://$pi/skyaware/plots/"


fi

echo "Graphs rendered in $SECONDS seconds"
