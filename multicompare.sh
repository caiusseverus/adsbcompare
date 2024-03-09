#!/bin/bash

starta=$1
durationa=$2
let "dura = $2-1"

sshhosta="adsbpi"
sshhostb="adsbpi"

echo > /tmp/first
for i in $(eval echo "{0..$dura}"); do ssh $sshhosta "cat /var/lib/graphs1090/scatter/`date -I --date=$starta+${i}days`" >> /tmp/first; done

wc -l /tmp/first

startb=$3
durationb=$4
let "durb = $4-1"

echo > /tmp/second
for i in $(eval echo "{0..$durb}"); do ssh $sshhostb "cat /var/lib/graphs1090/scatter/`date -I --date=$startb+${i}days`" >> /tmp/second; done

enda=$(date -I --date=$starta+${dura}days)
endb=$(date -I --date=$startb+${durb}days)

wc -l /tmp/second

gnuplot -c /dev/stdin $starta $enda $startb $endb $sshhosta $sshhostb <<"EOF"

set terminal pngcairo enhanced size 1900,900 background rgb 'gray80'
set output '/tmp/compare.png'

set datafile missing "NaN"

set multiplot layout 2,4

set size 0.5,1
set origin 0,0
set xlabel "Aircraft"
set ylabel "Messages"
set grid xtics ytics
set xtics 50
set ytics 100
set mxtics
set mytics
set pointsize 0.5
set title "Comparison of ".ARG1." to ".ARG2."(".ARG6.") and ".ARG3." to ".ARG4." (".ARG6.")"

set fit prescale
set fit logfile '/tmp/fit'
FIT_LIMIT = 1.e-10
FIT_MAXITER = 100

stats   '/tmp/first' using ($4) name "AircraftA"
stats   '/tmp/second' using ($4) name "AircraftB"
stats   '/tmp/first' using ($1/1852) name "RangeA"
stats   '/tmp/second' using ($1/1852) name "RangeB"
stats   '/tmp/first' using ($2+$3) name "MessagesA"
stats   '/tmp/second' using ($2+$3) name "MessagesB"


f(x) = a - b * exp(-c*x)

a=3000
b=3000
c=0.01

fit f(x) '/tmp/first' using ($4):($2+$3) via a,b,c

g(x) = j - k * exp(-l*x)
j=3000
k=3000
l=0.01
fit g(x) '/tmp/second' using ($4):($2+$3) via j,k,l

plot    '/tmp/first' using ($4):($2+$3) with points lt rgb "red" pt 7 title ARG1." to ".ARG2." (".ARG5.")", [0:AircraftA_max] f(x) lt rgb "black" notitle, \
        '/tmp/second' using ($4):($2+$3) with point lt rgb "blue" pt 7 title ARG3." to ".ARG4." (".ARG6.")",  [0:AircraftB_max] g(x) lt rgb "black" notitle


unset title

set size 0.5,0.6
set origin 0.5,0
set xlabel "Aircraft"
set ylabel "Range"
set grid xtics ytics
set ytics 50
set xtics 50
set pointsize 0.5
unset title


if (RangeA_min < RangeB_min) ymin = RangeA_min-5; else ymin = RangeB_min-5
if (AircraftA_max > AircraftB_max) xmax = AircraftA_max + 10 ; else xmax = AircraftB_max + 10

set xrange [0:xmax]
set yrange [ymin:300]

f(x) = a1*x**2 + b1*x + c1
a1 = 1
b1 = 1
c1 = 1

g(x) = a2*x**2 + b2*x + c2
a2 = 1
b2 = 1
c2 = 1

fit f(x) '/tmp/first' using ($4):($1/1852) via a1,b1,c1
fit g(x) '/tmp/second' using ($4):($1/1852) via a2,b2,c2

plot    '/tmp/first' using ($4):($1/1852) with points lt rgb "red" pt 7 title ARG1." to ".ARG2." (".ARG5.")", f(x) lt rgb "black" notitle, \
        '/tmp/second' using ($4):($1/1852) with points lt rgb "blue" pt 7 title ARG3." to ".ARG4." (".ARG6.")", g(x) lt rgb "black" notitle


set xrange [*:*]
unset yrange
set size 0.1667,0.4
set origin 0.5,0.6
set ylabel "Range"
unset xlabel
unset xtics
set style fill solid 0.5 border -1
set ytics auto


plot    '/tmp/first' using (1):($1/1852) w boxplot lc "red" notitle, \
        '/tmp/second' using (2):($1/1852) w boxplot lc "blue" notitle


set size 0.1667,0.4
set origin 0.6667,0.6
set ylabel "Aircraft"
set style fill solid 0.5 border -1
set ytics auto

plot    '/tmp/first' using (1):($4) w boxplot lc "red" notitle, \
        '/tmp/second' using (2):($4) w boxplot lc "blue" notitle


set size 0.1667,0.4
set origin 0.8334, 0.6
set ylabel "Messages"
set style fill solid 0.5 border -1
set ytics auto

plot    '/tmp/first' u (1):($2+$3) w boxplot lc "red" notitle, \
        '/tmp/second' u (2):($2+$3) w boxplot lc "blue" notitle


EOF
