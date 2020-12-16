# sync_utilities
The scripts to sync files between servers.

**To use these shell scripts, clone this repository and append this directory to your `PATH`.**
```
git clone https://github.com/yanhui09/sync_utilities.git
TMP=$(readlink -f sync_utilities)
export PATH="$TMP:$PATH"
```
To make these commands permanently accessible, in the path where you can see the direcotry 
```
TMP=$(readlink -f sync_utilities)
echo 'export PATH="$TMP:$PATH"' >> ~/.bashrc
 ```

<br>**Steps to deploy the system sync**<br>

*Step 1: set up ssh connections between servers via RSA keys*<br>
This only has to be done for the first use. It can be easily set up using the `RSAconfig.sh` script. And you need to provide the password to transfer the RSA key.

**Note**<br>
You has to manually prepare the `ssh config file` first. It follows [ssh config file format](https://man7.org/linux/man-pages/man5/ssh_config.5.html). A simple demo can be found with `RSAconfig.sh -h`.

The `ssh config file` is usually placed at `~/.ssh/config`. And it looks like
```
Host server
User server
Hostname xx.xx.xx.xx
IdentityFile ~/.ssh/id_rsa
```
To set the RSA configuration, you need to specify the remote host using `user@hostname` or `host`.
```
RSAconfig.sh -r user@hostname
RSAconfig.sh -r host
```
E.g.
```
RSAconfig.sh -r server@xx.xx.xx.xx
```
You shall log in the `server` without password if you try
```
ssh server
```
*The file transfer is through `ssh` protocol. You also have to set up the RSA configuration if you've mounted one network disk via `samba`.* Normally you don't have to edit the `ssh config file` since `localhost` is preset in linux. You can configure the local host through
```
RSAconfig.sh -r localhost
```
Test it and you shall in the `local host` without password
```
ssh localhost
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
sync.sh -t 900 --f5h kuserver --fqh foodserver --rf5d /raw/runx/fast5 --rfqd /data/runx/fastq --lf5d /runx/fast5 --lfqd /runx/fastq
```
To sync `runx` at KU FOOD
```
sync.sh -p -n runx
```
Or partially inherit -p
```
sync.sh -p -n runx --rfqd /data/runx/fastq_new -t 1800
```
<br><br>**Live sync**<br><br>
Real-time sync when a new nanopore run is created.
`livesync.sh` will call one `sync.sh` when a new run is created at the monitor path.
```
livesync.sh -m /path2dir_runs
```
*This calls an infinite loop to monitor the input path. `sync.sh` accumulates if previous `sync.sh` hasn't exited.*


