# backup_ps1
Powershell backup script for windows systems

0. Requirements
---
0.1 PSVersion - version 4.0 or later;

1. Installation
---
1.1 Download and extract 7-zip (https://www.7-zip.org/a/7z1900-extra.7z) or find exe in Program files (C:\Program Files\7-Zip\7z.exe);
1.2 Clone this repository;
1.3 Run backup.ps1 using "powershell -file <backup.ps1_location>" (remember about powershell execution policy https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7);

2. Configuration
---
2.1 settings.json - primary configuration file;
    settings.logging: true // Logging, if it equal true the script will be logging every action, if false no logging;
    settings.logpath: script // default log file full path, if equal script the log file will be defined by script;
    settings.zipper: // full path for 7zip binaries
    settings.light: (7z.exe file hash) // the default file-hash with SHA512 algorithm, to get file-hash use Get-FileHash cmdlet - Get-FileHash -Path <PATH_TO_FILE> -Algorithm SHA512).Hash
2.2 sources.json - backup soreces and defaul backup configuration