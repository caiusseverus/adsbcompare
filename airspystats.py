import os, io, subprocess, sys
import pandas as pd
import numpy as np
import time

if os.environ.get('DISPLAY') is None: # this variable will not be set when X Server is not running
    import matplotlib as mplib
 # set a  different display back-end to squash the error
    mplib.use('Agg')

from functools import reduce
import matplotlib.pyplot as plt
import seaborn as sns

# define parser to convert unix timestamp to datetime

def date_parser(string_list):
    return [time.ctime(float(x)) for x in string_list]

# Set output directory. The dump1090 html directory gives easy access via browser.

outdir = '/usr/local/share/tar1090/html/stats/'

# Check output directory exists and throw an error if not

if os.path.isdir(outdir):
    print("Output directory exists")
    if os.access(outdir, os.W_OK):
        print("Output directory writable")
    else:
        print("Please make the output directory writable:")
        print("sudo chmod o+rw " + outdir)
        sys.exit()
else:
    print("The specified output directory " + outdir + " does not exist. Please create it.")
    print("For example:")
    print("sudo mkdir " + outdir)
    print("sudo chmod o+rw " + outdir)
    sys.exit()

# get location of rrd data from graphs1090 config

with open("/etc/default/graphs1090") as file:
    for line in file:
        if line.startswith("DB="):
            rrdloc = line.replace("DB=",'').rstrip()
            break

# get data from rrd databases

print("Getting data...")

rrdmessages = subprocess.run(['rrdtool fetch ./localhost/dump1090-localhost/dump1090_messages-remote_accepted.rrd AVERAGE -s "now-2d" -a'], cwd=rrdloc, capture_output=True, text=True, shell=True)
messages = io.StringIO(rrdmessages.stdout.replace(':',''))

rrdrange = subprocess.run(['rrdtool fetch ./localhost/dump1090-localhost/dump1090_range-max_range.rrd MAX -s "now-2d" -a'], cwd=rrdloc, capture_output=True, text=True, shell=True)
range = io.StringIO(rrdrange.stdout.replace(':',''))

rrdaircraft = subprocess.run(['rrdtool fetch ./localhost/dump1090-localhost/dump1090_aircraft-recent.rrd AVERAGE -s "now-2d" -a'], cwd=rrdloc, capture_output=True, text=True, shell=True)
aircraft = io.StringIO(rrdaircraft.stdout.replace(':',''))

#rrdmlat = subprocess.run(['rrdtool fetch ./localhost/dump1090-localhost/dump1090_mlat-recent.rrd AVERAGE -s "now-2d" -a'], cwd=rrdloc, capture_output=True, text=True, shell=True)
#mlat = io.StringIO(rrdmlat.stdout.replace(':',''))

rrdgps = subprocess.run(['rrdtool fetch ./localhost/dump1090-localhost/dump1090_gps-recent.rrd AVERAGE -s "now-2d" -a'], cwd=rrdloc, capture_output=True, text=True, shell=True)
gps = io.StringIO(rrdgps.stdout.replace(':',''))

rrddf0 = subprocess.run(['rrdtool fetch ./localhost/dump1090-localhost/df_count_minute-0.rrd AVERAGE -s "now-2d" -a'], cwd=rrdloc, capture_output=True, text=True, shell=True)
df0 = io.StringIO(rrddf0.stdout.replace(':',''))

rrddf4 = subprocess.run(['rrdtool fetch ./localhost/dump1090-localhost/df_count_minute-4.rrd AVERAGE -s "now-2d" -a'], cwd=rrdloc, capture_output=True, text=True, shell=True)
df4 = io.StringIO(rrddf4.stdout.replace(':',''))

rrddf5 = subprocess.run(['rrdtool fetch ./localhost/dump1090-localhost/df_count_minute-5.rrd AVERAGE -s "now-2d" -a'], cwd=rrdloc, capture_output=True, text=True, shell=True)
df5 = io.StringIO(rrddf5.stdout.replace(':',''))

rrddf11 = subprocess.run(['rrdtool fetch ./localhost/dump1090-localhost/df_count_minute-11.rrd AVERAGE -s "now-2d" -a'], cwd=rrdloc, capture_output=True, text=True, shell=True)
df11 = io.StringIO(rrddf11.stdout.replace(':',''))

rrddf16 = subprocess.run(['rrdtool fetch ./localhost/dump1090-localhost/df_count_minute-16.rrd AVERAGE -s "now-2d" -a'], cwd=rrdloc, capture_output=True, text=True, shell=True)
df16 = io.StringIO(rrddf16.stdout.replace(':',''))

rrddf17 = subprocess.run(['rrdtool fetch ./localhost/dump1090-localhost/df_count_minute-17.rrd AVERAGE -s "now-2d" -a'], cwd=rrdloc, capture_output=True, text=True, shell=True)
df17 = io.StringIO(rrddf17.stdout.replace(':',''))

rrddf18 = subprocess.run(['rrdtool fetch ./localhost/dump1090-localhost/df_count_minute-18.rrd AVERAGE -s "now-2d" -a'], cwd=rrdloc, capture_output=True, text=True, shell=True)
df18 = io.StringIO(rrddf18.stdout.replace(':',''))

rrddf19 = subprocess.run(['rrdtool fetch ./localhost/dump1090-localhost/df_count_minute-19.rrd AVERAGE -s "now-2d" -a'], cwd=rrdloc, capture_output=True, text=True, shell=True)
df19 = io.StringIO(rrddf19.stdout.replace(':',''))

rrddf20 = subprocess.run(['rrdtool fetch ./localhost/dump1090-localhost/df_count_minute-20.rrd AVERAGE -s "now-2d" -a'], cwd=rrdloc, capture_output=True, text=True, shell=True)
df20 = io.StringIO(rrddf20.stdout.replace(':',''))

rrddf21 = subprocess.run(['rrdtool fetch ./localhost/dump1090-localhost/df_count_minute-21.rrd AVERAGE -s "now-2d" -a'], cwd=rrdloc, capture_output=True, text=True, shell=True)
df21 = io.StringIO(rrddf21.stdout.replace(':',''))

rrdgain = subprocess.run(['rrdtool fetch ./localhost/dump1090-localhost/airspy_misc-gain.rrd AVERAGE -s "now-2d" -a'], cwd=rrdloc, capture_output=True, text=True, shell=True)
gain = io.StringIO(rrdgain.stdout.replace(':',''))

rrdpreamble = subprocess.run(['rrdtool fetch ./localhost/dump1090-localhost/airspy_misc-preamble_filter.rrd AVERAGE -s "now-2d" -a'], cwd=rrdloc, capture_output=True, text=True, shell=True)
preamble = io.StringIO(rrdpreamble.stdout.replace(':',''))

rrdsnrmin = subprocess.run(['rrdtool fetch ./localhost/dump1090-localhost/airspy_snr-min.rrd AVERAGE -s "now-2d" -a'], cwd=rrdloc, capture_output=True, text=True, shell=True)
snrmin = io.StringIO(rrdsnrmin.stdout.replace(':',''))

rrdsnrmax = subprocess.run(['rrdtool fetch ./localhost/dump1090-localhost/airspy_snr-max.rrd AVERAGE -s "now-2d" -a'], cwd=rrdloc, capture_output=True, text=True, shell=True)
snrmax = io.StringIO(rrdsnrmax.stdout.replace(':',''))

rrdsnrmedian = subprocess.run(['rrdtool fetch ./localhost/dump1090-localhost/airspy_snr-median.rrd AVERAGE -s "now-2d" -a'], cwd=rrdloc, capture_output=True, text=True, shell=True)
snrmedian = io.StringIO(rrdsnrmedian.stdout.replace(':',''))

rrdsnrq1 = subprocess.run(['rrdtool fetch ./localhost/dump1090-localhost/airspy_snr-q1.rrd AVERAGE -s "now-2d" -a'], cwd=rrdloc, capture_output=True, text=True, shell=True)
snrq1 = io.StringIO(rrdsnrq1.stdout.replace(':',''))

rrdsnrq3 = subprocess.run(['rrdtool fetch ./localhost/dump1090-localhost/airspy_snr-q3.rrd AVERAGE -s "now-2d" -a'], cwd=rrdloc, capture_output=True, text=True, shell=True)
snrq3 = io.StringIO(rrdsnrq3.stdout.replace(':',''))

rrdsnrp5 = subprocess.run(['rrdtool fetch ./localhost/dump1090-localhost/airspy_snr-p5.rrd AVERAGE -s "now-2d" -a'], cwd=rrdloc, capture_output=True, text=True, shell=True)
snrp5 = io.StringIO(rrdsnrp5.stdout.replace(':',''))

rrdsnrp95 = subprocess.run(['rrdtool fetch ./localhost/dump1090-localhost/airspy_snr-p95.rrd AVERAGE -s "now-2d" -a'], cwd=rrdloc, capture_output=True, text=True, shell=True)
snrp95 = io.StringIO(rrdsnrp95.stdout.replace(':',''))

rrdnoisemin = subprocess.run(['rrdtool fetch ./localhost/dump1090-localhost/airspy_noise-min.rrd AVERAGE -s "now-2d" -a'], cwd=rrdloc, capture_output=True, text=True, shell=True)
noisemin = io.StringIO(rrdnoisemin.stdout.replace(':',''))

print("Processing...")

# import rrd data to dataframes
df_messages = pd.read_csv(messages, parse_dates=[0], sep='\s+', date_parser=date_parser, index_col='DateTime', names=['DateTime', 'messages'], header=None, skiprows=2)
df_range = pd.read_csv(range, parse_dates=[0], sep='\s+', date_parser=date_parser, index_col='DateTime', names=['DateTime', 'range'], header=None, skiprows=2)
df_aircraft = pd.read_csv(aircraft, parse_dates=[0], sep='\s+', date_parser=date_parser, index_col='DateTime', names=['DateTime', 'total', 'positions'], header=None, skiprows=2)
#df_mlat = pd.read_csv(mlat, parse_dates=[0], sep='\s+', date_parser=date_parser, index_col='DateTime', names=['DateTime', 'mlat'], header=None, skiprows=2)
df_gps = pd.read_csv(gps, parse_dates=[0], sep='\s+', date_parser=date_parser, index_col='DateTime', names=['DateTime', 'gps' ], header=None, skiprows=2)
df_df0 = pd.read_csv(df0, parse_dates=[0], sep='\s+', date_parser=date_parser, index_col='DateTime', names=['DateTime', 'df0' ], header=None, skiprows=2)
df_df4 = pd.read_csv(df4, parse_dates=[0], sep='\s+', date_parser=date_parser, index_col='DateTime', names=['DateTime', 'df4' ], header=None, skiprows=2)
df_df5 = pd.read_csv(df5, parse_dates=[0], sep='\s+', date_parser=date_parser, index_col='DateTime', names=['DateTime', 'df5' ], header=None, skiprows=2)
df_df11 = pd.read_csv(df11, parse_dates=[0], sep='\s+', date_parser=date_parser, index_col='DateTime', names=['DateTime', 'df11' ], header=None, skiprows=2)
df_df16 = pd.read_csv(df16, parse_dates=[0], sep='\s+', date_parser=date_parser, index_col='DateTime', names=['DateTime', 'df16' ], header=None, skiprows=2)
df_df17 = pd.read_csv(df17, parse_dates=[0], sep='\s+', date_parser=date_parser, index_col='DateTime', names=['DateTime', 'df17' ], header=None, skiprows=2)
df_df18 = pd.read_csv(df18, parse_dates=[0], sep='\s+', date_parser=date_parser, index_col='DateTime', names=['DateTime', 'df18' ], header=None, skiprows=2)
df_df19 = pd.read_csv(df19, parse_dates=[0], sep='\s+', date_parser=date_parser, index_col='DateTime', names=['DateTime', 'df19' ], header=None, skiprows=2)
df_df20 = pd.read_csv(df20, parse_dates=[0], sep='\s+', date_parser=date_parser, index_col='DateTime', names=['DateTime', 'df20' ], header=None, skiprows=2)
df_df21 = pd.read_csv(df21, parse_dates=[0], sep='\s+', date_parser=date_parser, index_col='DateTime', names=['DateTime', 'df21' ], header=None, skiprows=2)
df_gain = pd.read_csv(gain, parse_dates=[0], sep='\s+', date_parser=date_parser, index_col='DateTime', names=['DateTime', 'gain' ], header=None, skiprows=2)
df_preamble = pd.read_csv(preamble, parse_dates=[0], sep='\s+', date_parser=date_parser, index_col='DateTime', names=['DateTime', 'preamble' ], header=None, skiprows=2)
df_snrmin = pd.read_csv(snrmin, parse_dates=[0], sep='\s+', date_parser=date_parser, index_col='DateTime', names=['DateTime', 'snrmin' ], header=None, skiprows=2)
df_snrmax = pd.read_csv(snrmax, parse_dates=[0], sep='\s+', date_parser=date_parser, index_col='DateTime', names=['DateTime', 'snrmax' ], header=None, skiprows=2)
df_snrmedian = pd.read_csv(snrmedian, parse_dates=[0], sep='\s+', date_parser=date_parser, index_col='DateTime', names=['DateTime', 'snrmedian' ], header=None, skiprows=2)
df_snrq1 = pd.read_csv(snrq1, parse_dates=[0], sep='\s+', date_parser=date_parser, index_col='DateTime', names=['DateTime', 'snrq1' ], header=None, skiprows=2)
df_snrq3 = pd.read_csv(snrq3, parse_dates=[0], sep='\s+', date_parser=date_parser, index_col='DateTime', names=['DateTime', 'snrq3' ], header=None, skiprows=2)
df_snrp5 = pd.read_csv(snrp5, parse_dates=[0], sep='\s+', date_parser=date_parser, index_col='DateTime', names=['DateTime', 'snrp5' ], header=None, skiprows=2)
df_snrp95 = pd.read_csv(snrp95, parse_dates=[0], sep='\s+', date_parser=date_parser, index_col='DateTime', names=['DateTime', 'snrp95' ], header=None, skiprows=2)
df_noisemin = pd.read_csv(noisemin, parse_dates=[0], sep='\s+', date_parser=date_parser, index_col='DateTime', names=['DateTime', 'noisemin' ], header=None, skiprows=2)

# round gain to integers to allow use as categories

df_gain.gain = df_gain.gain.round()

# calculate range in nm and add column to dataframe

df_range['rangenm'] = df_range['range'] / 1852

# calculate DF frames per second
df_df0['df0rate'] = df_df0['df0']/60
df_df4['df4rate'] = df_df4['df4']/60
df_df5['df5rate'] = df_df5['df5']/60
df_df11['df11rate'] = df_df11['df11']/60
df_df16['df16rate'] = df_df16['df16']/60
df_df17['df17rate'] = df_df17['df17']/60
df_df18['df18rate'] = df_df18['df18']/60
df_df19['df19rate'] = df_df19['df19']/60
df_df20['df20rate'] = df_df20['df20']/60
df_df21['df21rate'] = df_df21['df21']/60

# merge dataframes

dfs = [df_messages, df_range, df_aircraft, df_gps, df_df0, df_df4, df_df5, df_df11, df_df16, df_df17, df_df18, df_df19, df_df20, df_df21, df_gain, df_preamble, df_snrmin, df_snrmax, df_snrmedian, df_snrq1, df_snrq3, df_snrp5, df_snrp95, df_noisemin]
df_airspy = reduce(lambda left,right: pd.merge(left,right,on='DateTime'), dfs)

# calculate snr range

df_airspy['snrrange'] = df_airspy['snrmax'] - df_airspy['snrmin']
df_airspy['snr90range'] = df_airspy['snrp95'] - df_airspy['snrp5']

# calculate DF17 rate per ads-b aircraft

df_airspy['df17ac'] = df_airspy['df17rate'] / df_airspy['gps']

# graph stuff

sns.set_theme(style="darkgrid")

# Range/Total aircraft scatter plot with range density

filename = 'rangeac.png'
f, axs = plt.subplots(1,2,figsize=(10,8),sharey=True,gridspec_kw=dict(width_ratios=[3,0.5]))
sns.scatterplot(data=df_airspy, x='total', y='rangenm', hue='gain', ax=axs[0], alpha=0.4, palette="Set1")
sns.kdeplot(data=df_airspy, y='rangenm', hue='gain', legend=False, palette="Set1", warn_singular=False)
axs[0].set_ylabel("Range (nm)")
axs[0].set_xlabel("Total Aircraft")
plt.tight_layout()
plt.savefig(os.path.join(outdir,filename))

plt.clf()

filename = 'snraircraft.png'
f, ax = plt.subplots(figsize=(10,8), sharey=True)
sns.scatterplot(x="total", y="snrmin", data=df_airspy, hue="gain", alpha=0.15, palette='Set1')
sns.scatterplot(x="total", y="snrp5", data=df_airspy, hue="gain", alpha=0.15, legend=False, palette='Set1')
sns.scatterplot(x="total", y="snrq1", data=df_airspy, hue="gain", alpha=0.15, legend=False, palette='Set1')
sns.scatterplot(x="total", y="snrmedian", data=df_airspy, hue="gain", alpha=0.15, legend=False, palette='Set1')
sns.scatterplot(x="total", y="snrq3", data=df_airspy, hue="gain", alpha=0.15, legend=False, palette='Set1')
sns.scatterplot(x="total", y="snrp95", data=df_airspy, hue="gain", alpha=0.15, legend=False, palette='Set1')
sns.scatterplot(x="total", y="snrmax", data=df_airspy, hue="gain", alpha=0.15, legend=False, palette='Set1')
ax.set_ylabel("Signal to Noise Ratio")
ax.set_xlabel("Total Aircraft")
plt.tight_layout()
plt.savefig(os.path.join(outdir,filename))

plt.clf()

filename = 'snrgain.png'
fig, ax = plt.subplots(figsize=(10,8), sharey=True)
sns.stripplot(x=df_airspy['gain'], y=df_airspy['snrmin'], color="#29a7e6", jitter=0.25, alpha=0.10)
sns.stripplot(x=df_airspy['gain'], y=df_airspy['snrp5'], color="#4f59e3", jitter=0.25, alpha=0.10)
sns.stripplot(x=df_airspy['gain'], y=df_airspy['snrq1'], color="#45d945", jitter=0.25, alpha=0.10)
sns.stripplot(x=df_airspy['gain'], y=df_airspy['snrmedian'], color="black", jitter=0.25, alpha=0.10)
sns.stripplot(x=df_airspy['gain'], y=df_airspy['snrq3'], color="#45d945", jitter=0.25, alpha=0.10)
sns.stripplot(x=df_airspy['gain'], y=df_airspy['snrp95'], color="#4f59e3", jitter=0.25, alpha=0.10)
sns.stripplot(x=df_airspy['gain'], y=df_airspy['snrmax'], color="#29a7e6", jitter=0.25, alpha=0.10)
ax.set_ylabel("Signal to Noise Ratio")
ax.set_xlabel("Gain")
plt.tight_layout()
plt.savefig(os.path.join(outdir,filename))

plt.clf()

filename = 'snrrange.png'
f, ax = plt.subplots(figsize=(10,8))
sns.stripplot(x="gain", y="snrrange", data=df_airspy, jitter=0.20, alpha=0.25)
sns.boxplot(showmeans=True,
            meanline=True,
            meanprops={'color': 'k', 'ls': '-', 'lw': 2},
            medianprops={'visible': False},
            whiskerprops={'visible': False},
            zorder=10,
            x='gain',
            y='snrrange',
            data=df_airspy,
            showfliers=False,
            showbox=False,
            showcaps=False,
            ax = ax)
ax.set_ylabel("Signal to Noise Ratio Range")
ax.set_xlabel("Gain")
plt.tight_layout()
plt.savefig(os.path.join(outdir,filename))

plt.clf()

filename = 'noisemin.png'
f, ax = plt.subplots(figsize=(10,8))
sns.stripplot(x='gain', y='noisemin', data=df_airspy, jitter=0.20, alpha=0.25)
sns.boxplot(showmeans=True,
            meanline=True,
            meanprops={'color': 'k', 'ls': '-', 'lw': 2},
            medianprops={'visible': False},
            whiskerprops={'visible': False},
            zorder=10,
            x='gain',
            y='noisemin',
            data=df_airspy,
            showfliers=False,
            showbox=False,
            showcaps=False,
            ax = ax)
ax.set_label("Noise (dB)")
ax.set_xlabel("Gain")
plt.tight_layout()
plt.savefig(os.path.join(outdir,filename))

plt.clf()

filename = 'df17ac.png'
f, axs = plt.subplots(1,2,figsize=(10,8),sharey=True,gridspec_kw=dict(width_ratios=[3,0.5]))
sns.scatterplot(data=df_airspy, x='total', y='df17ac', hue='gain', ax=axs[0], alpha=0.4, palette="Set1")
sns.kdeplot(data=df_airspy, y='df17ac', hue='gain', legend=False, palette="Set1", warn_singular=False)
axs[0].set_ylabel('DF17 messages per ads-b aircraft')
axs[0].set_xlabel('Total aircraft')
plt.tight_layout()
plt.savefig(os.path.join(outdir,filename))

plt.clf()

filename = 'messagespreamble.png'
f, ax = plt.subplots(figsize=(10,8))
sns.scatterplot(x="messages", y="preamble", data=df_airspy, hue="gain", palette="Set1", alpha=0.3)
ax.set_ylabel("Preamble Filter")
ax.set_xlabel("Messages per Second")
plt.tight_layout()
plt.savefig(os.path.join(outdir,filename))

plt.clf()

filename = 'messagetypes.png'
f, ax = plt.subplots(5,2,figsize=(12,15), sharex=True)
sns.scatterplot(ax = ax[0,0], x="total", y="df0rate", hue="gain", data=df_airspy, alpha=0.25, palette="Set1")
sns.scatterplot(ax = ax[0,1], x="total", y="df4rate", hue="gain",data=df_airspy, alpha=0.25, palette="Set1")
sns.scatterplot(ax = ax[1,0], x="total", y="df5rate", hue="gain",data=df_airspy, alpha=0.25, palette="Set1")
sns.scatterplot(ax = ax[1,1], x="total", y="df11rate", hue="gain",data=df_airspy, alpha=0.25, palette="Set1")
sns.scatterplot(ax = ax[2,0], x="total", y="df16rate", hue="gain",data=df_airspy, alpha=0.25, palette="Set1")
sns.scatterplot(ax = ax[2,1], x="total", y="df17rate", hue="gain",data=df_airspy, alpha=0.25, palette="Set1")
sns.scatterplot(ax = ax[3,0], x="total", y="df18rate", hue="gain",data=df_airspy, alpha=0.25, palette="Set1")
sns.scatterplot(ax = ax[3,1], x="total", y="df19rate", hue="gain",data=df_airspy, alpha=0.25, palette="Set1")
sns.scatterplot(ax = ax[4,0], x="total", y="df20rate", hue="gain",data=df_airspy, alpha=0.25, palette="Set1")
sns.scatterplot(ax = ax[4,1], x="total", y="df21rate", hue="gain",data=df_airspy, alpha=0.25, palette="Set1")
ax[0,0].set_ylabel("DF0")
ax[0,1].set_ylabel("DF4")
ax[1,0].set_ylabel("DF5")
ax[1,1].set_ylabel("DF11")
ax[2,0].set_ylabel("DF16")
ax[2,1].set_ylabel("DF17")
ax[3,0].set_ylabel("DF18")
ax[3,1].set_ylabel("DF19")
ax[4,0].set_ylabel("DF20")
ax[4,1].set_ylabel("DF21")
ax[4,0].set_xlabel("Total Aircraft")
ax[4,1].set_xlabel("Total Aircraft")
plt.tight_layout()
plt.savefig(os.path.join(outdir,filename))

# creates stats

df_stats = []
df_stats = df_airspy.groupby(['gain'])['messages'].mean().round(1).reset_index()
df_stats['noisemin'] = df_airspy.groupby(['gain'])['noisemin'].mean().round(2).values
df_stats['snrrange'] = df_airspy.groupby(['gain'])['snrrange'].mean().round(2).values
df_stats['rangenm'] = df_airspy.groupby(['gain'])['rangenm'].mean().round(2).values
df_stats['samples'] = df_airspy.groupby(['gain'])['gain'].count().values

table = df_stats.to_html(classes='mystyle', index=False)

css = """
/* includes alternating gray and white with on-hover color */

.mystyle {
    font-size: 11pt;
    font-family: Arial;
    border-collapse: collapse;
    border: 1px solid silver;

}

.mystyle td, th {
    padding: 5px;
}

.mystyle tr:nth-child(even) {
    background: #E0E0E0;
}

.mystyle tr:hover {
    background: silver;
    cursor: pointer;
}"""

# Write css file if it doesn't exist.

if not os.path.exists(outdir + "df_style.css"):
    with open(outdir + "df_style.css", "w") as file:
        file.write(css)

htmlstart = """
<!DOCTYPE html>
<html>
<style>
img {
    max-width:100%;
    height:auto;
}
</style>
<link rel="stylesheet" type="text/css" href="df_style.css"/>
<body>
<h1>Airspy ADS-B Decoder Stats.</h1>
Data from graphs1090 covers the previous 48 hours at one minute resolution.
<h2>Mean Values per gain setting</h2>
"""

htmlend = """
<h2>Range/Total Aircraft</h2>
<img src="rangeac.png" alt="Range/Aircraft"><br>
Average maximum reception range tends to decrease slightly with increasing traffic.<br>
This graph should highlight any gain settings that are limiting reception range.<br>
<br>
<h2>Signal to Noise Ratio / Total Aircraft</h2>
<img src="snraircraft.png" alt="SNR/Aircraft"><br>
Traces are minimum, 5%, 25%, 50%, 75%, 95% and maximum.<br>
Signal to noise ratio ideally should remain constant with changing gain settings.<br>
Gain set too high may reduce SNR, which should show up as outliers on this graph.<br>
<br>
<h2>Signal to Noise Ratio per Gain setting</h2>
<img src="snrgain.png" alt="SNR/Gain"><br>
Data is similar to above, but grouped by gain setting.<br>
Colours are the same as those used on the Graphs1090 SNR plot.<br>
<br>
<h2>Signal to Noise Ratio Range</h2>
<img src="snrrange.png" alt="SNR/Range"><br>
This plot shows the difference between the maximum and minimum SNR for each gain setting.<br>
Mean values indicated by the line.<br>
It should highlight a reduction in SNR due to a too high gain setting, either due to increased minimum or compressed maximum.<br>
<br>
<h2>Minimum Noise</h2>
<img src="noisemin.png" alt="Noise Floor"><br>
Approximates the system noise floor for each gain setting.<br>
The difference between each gain step should be approximately linear.<br>
<br>
<h2>DF17 messages per ADS-B aircraft / Total Aircraft</h2>
<img src="df17ac.png" alt="DF17 per Aircraft"><br>
Number of DF17 messages received per second from each ADS-B aircraft plotted against all aircraft.<br>
This number will decrease with increasing traffic due to message garbling.<br>
<br>
<h2>Preamble filter / Total Message Rate</h2>
<img src="messagespreamble.png" alt="Preamble/Messages"><br>
This plot show the relationship between total received messages and the preamble filter.<br>
It will be highly sensitive to individual receiver configuration and local traffic.<br>
Note that it does not imply a causal relationship either way, especially if using CPU target.<br>
<br>
<h2>Message Type Summary</h2>
<img src="messagetypes.png" alt="Message Types"><br>
Overview of relationship for different message types to total traffic.<br>
Useful to show how increasing traffic affects each message type:<br>
<br>
DF 0 - ACAS/TCAS Air to Air anti collision.<br>
DF 4 - Altitude Response<br>
DF 5 - IDENT response<br>
DF11 - Mode S All-Call reply/ADS-B Acquisition Squitter<br>
DF16 - Long ACAS/TCAS Air to Air anti collision<br>
DF17 - ADS-B Extended Squitter<br>
DF18 - ADS-B Supplemenatary - non-transponder devices, TIS-B and ADS-R.<br>
DF19 - Military Extended Squitter<br>
DF20 - Comm B - Various navigation and status messages<br>
DF21 - Comm B - Various navigation and status messages<br>

</body>
</html>"""

html = htmlstart + table + htmlend

file = open(os.path.join(outdir,"index.html"), "w")
file.write(html)
file.close()