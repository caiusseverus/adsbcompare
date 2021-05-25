import os, io, subprocess
import pandas as pd
import csv, time
import matplotlib.pyplot as plt
import seaborn as sns

# define parser to convert unix timestamp to datetime

def date_parser(string_list):
    return [time.ctime(float(x)) for x in string_list]

# Set output directory. This should be in the dump1090 html directory for easy access via browser. Needs permissions set to enable writing, or run the script with sudo.

outdir = '/usr/share/skyaware/html/plots/'

# get location of rrd data from graphs1090 config

with open("/etc/default/graphs1090") as file:
    for line in file:
        if line.startswith("DB="):
            rrdloc = line.replace("DB=",'').rstrip()
            break

# get data from rrd databases

print("Getting data...")

rrdremote = subprocess.run(['rrdtool fetch ./localhost/dump1090-localhost/dump1090_messages-remote_accepted.rrd AVERAGE -s "end-30d-23h45min" -e "23:30 yesterday" -a'], cwd=rrdloc, capture_output=True, text=True, shell=True)
remote_messages = io.StringIO(rrdremote.stdout.replace(':',''))

rrdlocal = subprocess.run(['rrdtool fetch ./localhost/dump1090-localhost/dump1090_messages-local_accepted.rrd AVERAGE -s "end-30d-23h45min" -e "23:30 yesterday" -a'], cwd=rrdloc, capture_output=True, text=True, shell=True)
local_messages = io.StringIO(rrdlocal.stdout.replace(':',''))

rrdrange = subprocess.run(['rrdtool fetch ./localhost/dump1090-localhost/dump1090_range-max_range.rrd MAX -s "end-30d-23h45min" -e "23:30 yesterday" -a'], cwd=rrdloc, capture_output=True, text=True, shell=True)
range = io.StringIO(rrdrange.stdout.replace(':',''))

rrdaircraft = subprocess.run(['rrdtool fetch ./localhost/dump1090-localhost/dump1090_aircraft-recent.rrd AVERAGE -s "end-30d-23h45min" -e "23:30 yesterday" -a'], cwd=rrdloc, capture_output=True, text=True, shell=True)
aircraft = io.StringIO(rrdaircraft.stdout.replace(':',''))

rrdmlat = subprocess.run(['rrdtool fetch ./localhost/dump1090-localhost/dump1090_mlat-recent.rrd AVERAGE -s "end-30d-23h45min" -e "23:30 yesterday" -a'], cwd=rrdloc, capture_output=True, text=True, shell=True)
mlat = io.StringIO(rrdmlat.stdout.replace(':',''))

print("Processing...")

# import rrd data to dataframes
df_remote = pd.read_csv(remote_messages, parse_dates=[0], sep='\s+', date_parser=date_parser, index_col='DateTime', names=['DateTime', 'remote'], header=None, skiprows=2)
df_local = pd.read_csv(local_messages, parse_dates=[0], sep='\s+', date_parser=date_parser, index_col='DateTime', names=['DateTime', 'local'], header=None, skiprows=2)
df_range = pd.read_csv(range, parse_dates=[0], sep='\s+', date_parser=date_parser, index_col='DateTime', names=['DateTime', 'range'], header=None, skiprows=2)
df_aircraft = pd.read_csv(aircraft, parse_dates=[0], sep='\s+', date_parser=date_parser, index_col='DateTime', names=['DateTime', 'total', 'positions'], header=None, skiprows=2)
df_mlat = pd.read_csv(mlat, parse_dates=[0], sep='\s+', date_parser=date_parser, index_col='DateTime', names=['DateTime', 'mlat'], header=None, skiprows=2)

# sum remote and local messages

df_messages = pd.merge_asof(df_remote, df_local, on='DateTime')
df_messages = df_messages.set_index('DateTime')
df_messages['messages'] = df_remote['remote'] + df_local['local']

# calculate range in nm and add column to dataframe

df_range['rangenm'] = df_range['range'] / 1852

# get range stats to set colour bar

range_min = df_range['rangenm'].min()
range_max = df_range['rangenm'].max()
range_mean = df_range['rangenm'].mean()
range_median = df_range['rangenm'].median()

# replace NaN with zeros so seaborn doesn't complain
df_messages = df_messages.fillna(0)
df_range = df_range.fillna(0)
df_aircraft = df_aircraft.fillna(0)
df_mlat = df_mlat.fillna(0)

# add date and time columns from index
df_messages['date'] = df_messages.index.date
df_messages['time'] = df_messages.index.time
df_range['date'] = df_range.index.date
df_range['time'] = df_range.index.time
df_aircraft['date'] = df_aircraft.index.date
df_aircraft['time'] = df_aircraft.index.time
df_mlat['date'] = df_mlat.index.date
df_mlat['time'] = df_mlat.index.time

# convert dataframe to wideformat for plotting
messages_w = df_messages.pivot(index='date', columns='time', values='messages')
range_w = df_range.pivot(index='date', columns='time', values='rangenm')
aircraft_w = df_aircraft.pivot(index='date', columns='time', values='total')
mlat_w = df_mlat.pivot(index='date', columns='time', values='mlat')

print("Generating Plots...")

# generate plots
fig, ax = plt.subplots(figsize=(30,12), dpi=80)
sns.heatmap(messages_w, cmap="magma", cbar_kws={"shrink": 0.5})

filename = 'messages.png'
plt.title("Messages per second")
plt.xlabel("Time")
plt.ylabel("Date")
plt.savefig(os.path.join(outdir, filename), bbox_inches="tight")

plt.clf()

filename = 'range.png'
sns.heatmap(range_w, vmin=range_min, vmax=range_max, cmap='seismic', center=range_mean, cbar_kws={"shrink":0.5})
plt.title("Maximum Range")
plt.xlabel("Time")
plt.ylabel("Date")
plt.savefig(os.path.join(outdir, filename), bbox_inches="tight")

plt.clf()

filename = 'aircraft.png'
sns.heatmap(aircraft_w, cmap="magma", cbar_kws={"shrink": 0.5})
plt.title("Total Aircraft")
plt.xlabel("Time")
plt.ylabel("Date")
plt.savefig(os.path.join(outdir,filename), bbox_inches="tight")

plt.clf()

filename = 'mlat.png'
sns.heatmap(mlat_w, cmap='magma', cbar_kws={"shrink": 0.5})
plt.title("MLAT Aircraft")
plt.xlabel("Time")
plt.ylabel("Date")
plt.savefig(os.path.join(outdir, filename), bbox_inches="tight")

# write basic webpage for easy access to plots.

html = """
<!DOCTYPE html>
<html>
<style>
img {
    max-width:100%;
    height:auto;
}
</style>
<body>
<h1>Month Heatmaps</h1>
<h2>Data taken from Graphs1090 with 15 minute resolution. Messages and Aircraft plots are 15 minute averages, Range is the 15 minute peak.</h2>
<img src="messages.png" alt="Messages">
<img src="aircraft.png" alt="All aircraft">
<img src="mlat.png" alt="MLAT Aircraft">
<img src="range.png" alt="Range">
</body>
</html>"""

file = open(os.path.join(outdir,"heatmaps.html"), "w")
file.write(html)
file.close()

print("Plots can be found in " + outdir + " or via browser at <your-pi-address>/skyaware/plots/heatmaps.html")
