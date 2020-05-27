# backup_ps1
Powershell backup script for windows system using 7zip as archive processor. 

### Installation
```sh
git clone https://github.com/dforge/backup_ps1.git backup_ps1
```
Rename example files for new usage or use your own settings.json/sources.json files.

### Update
```sh
git fetch --prune
```
```sh
git checkout
```
```sh
git pull
```

### VMware loginsight integration
```sh
[parser|backup_ps1_parser]
base_parser=csv
delimiter=|
fields=datetime,sevirity,log_message
debug=no
```

```sh
[filelog|backup_ps1_filelog]
directory=<backup_ps1 log file location>
include=*.txt
parser=backup_ps1_parser
```