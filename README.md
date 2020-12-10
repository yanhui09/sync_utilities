# sync_utilities
The scripts to sync files between severs.

**Steps to deploy the system sync**

*Step 1: set up ssh connections between servers via RSA keys*<br>
This only has to be done for the first use. It can be easily set up using the `RSAconfig.sh` script. And you need to provide the password to transfer the RSA key.

**Note**<br>
You has to manually prepare the `ssh config file` first. It follows [ssh config file format](https://man7.org/linux/man-pages/man5/ssh_config.5.html). A simple demo can be found with `./RSAconfig.sh -h`.

```
Host server
User server
Hostname xx.xx.xx.xx
IdentityFile ~/.ssh/id_rsa
```
```
./RSAconfig.sh -r user@hostname
./RSAconfig.sh -r host
```
e.g.
```
./RSAconfig.sh -r server@xx.xx.xx.xx
```
You shall log in the `server` without password if you try
```
ssh server
```

<br>*Step 2: Deploy the sync system*<br>
**This script use `inotify-tools` to monitor file change.**
You may need `sudo` to install, for Ubuntu dsitribution
```
sudo apt-get update -y
sudo apt-get install -y inotify-tools
```

You need to specifiy the servers to backup the files. A demo is shown as below:
local path | Servers | files | remote path
--- | --- | --- | ---
/runx/fast5 | `kuserver` | fast5 | /raw/runx/fast5
/runx/fastq | `foodserver` | fastq | /data/runx/fastq
```
sync.sh --f5h kuserver --fqh foodserver -rf5d /raw/runx/fast5 --rfqd /data/runx/fastq --lf5d /runx/fast5 --lfqd /runx/fastq
```
To sync `runx` at KU FOOD
```
sync.sh -p -n runx
```
Or partially inherit -p
```
sync.sh -p -n runx -rfqd /data/runx/fastq_new
```
<br><br>**Live sync**<br><br>
Real-time sync when a new nanopore run is created.
`livesync.sh` will call one `sync.sh` when a new run is created at the monitor path.
```
livesync.sh -m /data_allruns
```
*This calls an infinite loop to monitor the input path. `sync.sh` accumulates in parallel if previous `sync.sh` hasn't exited.*


