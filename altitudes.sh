#!/bin/bash

date=$(date -I)
PWD=$(pwd)

#set range of plot to 230nm if no value specified
if [ ! $2 ]
then
  range=230
else
  range=$2
fi

output=altmap-$(date -I)_$range.png

echo "Plotting altitude heatmap for datafile $1 with range $range"

nice -n 19 gnuplot -c /dev/stdin $1 $range <<"EOF"

data=ARG1
range=ARG2

set terminal pngcairo enhanced size 2000,2000
set datafile separator comma
set object 1 rectangle from screen 0,0 to screen 1,1 fillcolor rgb "black" behind
set output 'altmap.png'

set border lc rgb "white"

set cbrange [0:45000]
set cblabel "Altitude" tc rgb "white"
set palette negative rgb 33,13,10
set polar
set angles degrees
set theta clockwise top
set grid polar 45 linecolor rgb "white"
set colorbox user vertical origin 0.9, 0.80 size 0.02, 0.15


show angles
set size square
set title "Altitude Heatmap" tc rgb "white"
set xrange [-range:range]
set yrange [-range:range]
set rtics 50
set xtics 50
set ytics 50

print "Generating altitudes heatmap..."

plot '< sort -t"," -k4 -r '.data u ($6):($5/1852):($4) with dots lc palette

EOF

IP=$(ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')
sudo cp altmap.png $output
sudo mv altmap.png /usr/share/skyaware/html/plots/altmap.png
sudo mv $output $PWD/results/$date/$output

echo "Plot available at http://$IP/skyaware/plots/$output"


