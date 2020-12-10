# sync_utilities
The scripts to sync files between severs.

**Steps to deploy the system sync**

*Step 1: set up ssh connections between servers via RSA keys*<br>
This only has to be done for the first use. It can be easily set up using the *RSAconfig.sh* script. And you need to provide the password to transfer the RSA key.

**Note**<br>
You has to manually prepare the ssh config file first. It follows [ssh config file format](https://man7.org/linux/man-pages/man5/ssh_config.5.html). A simple demo can be found with *./RSAconfig.sh -h*

```
./RSAconfig.sh -r user@hostname
./RSAconfig.sh -r host
```
e.g.
```
./RSAconfig.sh -r server@10.61.11.11
```
You shall log in the server without password if you try
```
ssh server
```

*Step 2: Deploy the sync system*<br>
**This script use inotify-tools to monitor file change.**You may need *sudo* to install, for Ubuntu dsitribution
```
sudo apt-get update -y
sudo apt-get install -y inotify-tools
```

You need to specifiy the servers to backup the files. A demo is shown as below:
local path | Servers | files | remote path
--- | --- | --- | ---
/runx/fast5 | `Kuserver` | fast5 | /raw/runx/fast5
/runx/fastq | `Foodserver` | fastq | /data/runx/fastq

TO sync `run_30` at KU FOOD
```
sync.sh -p -n run_30
```
<br><br>**Live sync**<br><br>
*To real-time sync when a new nanopore run is created
*livesync.sh* will call one `sync.sh` when a new run is created at the monitor path.
```
livesync.sh -m /data_allruns
```
*This calls an infinite loop to monitor the input path. `Sync.sh` accumulates in parallel if previous sync.sh hasn't exited*


