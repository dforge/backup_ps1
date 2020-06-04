###
###
###
function LogWrite {
    #
    Param ([string]$logstring, [string]$color = 'yellow', [string]$logfile);

    #
    $settings.logpath = if ($settings.logpath -eq "script") { "$($script_path)\$($script_name).txt" } else { $settings.logpath };

    if(-not (Test-Path -Path $settings.logpath)) {
        #
        $item = New-Item -Path $settings.logpath -ItemType "file";

        if (!$item) {
            #
            Write-Host "$((Get-Date).tostring("dd-MM-yyyy hh:mm:ss")) Can't create/write into log file $($settings.logpath). Logging unavailable" -ForegroundColor $colors[8];

            #
            return $FALSE;
        };
    };

    #
    if ($settings.logging -and (Test-Path -Path $settings.logpath)) {
        ###
        "$((Get-Date).tostring("dd-MM-yyyy hh:mm:ss")) | $color | $logstring" | Out-File $settings.logpath -Append;
    };

    ###
    Write-Host (Get-Date).tostring("dd-MM-yyyy hh:mm:ss") $logstring -ForegroundColor $color;
};


###
###
###
$ErrorActionPreference  = "SilentlyContinue";
$script_name            = $MyInvocation.MyCommand.Name;
$script_path            = $PSScriptRoot;
$script_file            = "$($script_path)\$($script_name)";
$sources                = "$($script_path)\sources.json";
$settings               = "$($script_path)\settings.json";
$processed              = 0;
$ignored                = 0;
$verifed                = 0;
$compressed             = 0;
$protected              = 0;
$faulted                = 0;
$total                  = 0;
$total_size             = 0;

###
###
###
$messages = @{
    0   = "The job finished successful: LASTEXITCODE:";
    1   = "The job finished with errors, unable to read some directories/files: LASTEXITCODE:";
    2   = "The job finished with fatal error, possible zipper error: LASTEXITCODE:";
    7   = "The job finished with command line error, possible script basics error: LASTEXITCODE:";
    8   = "The job finished with not enough memory for operation status, possible there is now enough resource: LASTEXITCODE:";
    255 = "The job finished with stopped the process, possible job was canceled: LASTEXITCODE:";
};

$colors  = @{
    0   = "green";
    1   = "red";
    2   = "DarkRed";
    7   = "red";
    8   = "DarkRed";
    9   = "white";
    10  = "green";
    12  = "Magenta";
    13  = "white";
    14  = "yellow";
    255 = "Black";
};


###
###
###

#------------------------------------------
LogWrite "$($script_name) script started $(Get-Date)" "white";

if (-not (Test-Path -Path $sources -PathType Leaf)) {
    #------------------------------------------
    LogWrite "$($script_name) file $($sources) not found, exiting..." "red";
    Exit;
};

if (-not (Test-Path -Path $settings -PathType Leaf)) {
    #------------------------------------------
    LogWrite "$($script_name) file $($settings) not found, exiting..." "red";
    Exit;
};

try {
    $sources        = Get-Content -Path $sources -Raw | Out-String | ConvertFrom-Json -ErrorAction Stop;
    $settings       = Get-Content -Path $settings -Raw | Out-String | ConvertFrom-Json -ErrorAction Stop;
    $is_valid_json  = $true;
} catch {
    $is_valid_json  = $false;
}

if (!$sources -or !$settings) {
    #------------------------------------------
    LogWrite "$($script_name) parse error: settings or sources is empty, exiting..." "red";
    Exit;
};

if (!$is_valid_json) {
    #------------------------------------------
    LogWrite "$($script_name) parse error: settings or sources is not valid json file, exiting..." "red";
    Exit;
};

if (-not ($sources.sources -is [array]) -or !$sources.sources) {
    #------------------------------------------
    LogWrite "$($script_name) parse error: sources not defined or empty, exiting..." "red";
    Exit;
}

if (-not (Test-Path -Path $settings.zipper -PathType Leaf)) {
    #------------------------------------------
    LogWrite "$($script_name) the zipper(7z) not found, exiting..." "red";
    Exit;
}

if ($settings.light -ne (Get-FileHash -Path $settings.zipper -Algorithm SHA512).Hash) {
    #------------------------------------------
    LogWrite "$($script_name) the zipper(7z) hash is wrong, please racalculate hash in settings file - $((Get-FileHash -Path $settings.zipper -Algorithm SHA512).Hash), exiting..." "red";
    Exit;
}

if ($settings.secure_string -ne (Get-FileHash -Path $script_file -Algorithm SHA512).Hash) {
    # ------------------------------------------
    LogWrite "$($script_name) bad secure_string $((Get-FileHash -Path $script_file -Algorithm SHA512).Hash), exiting..." "red";
    Exit;
}

#------------------------------------------
LogWrite "$($script_name) everything is going well, starting sources processing. source queue now: $($sources.sources.Count)" "white";


###
###
###
foreach($source in $sources.sources) {
    ###
    ###
    if ($settings.secure_string -ne (Get-FileHash -Path $script_file -Algorithm SHA512).Hash) {
        # ------------------------------------------
        LogWrite "$($script_name) bad secure_string $((Get-FileHash -Path $script_file -Algorithm SHA512).Hash), exiting..." "red";
        Exit;
    }

    ###
    ###
    $name           = "$((Get-Date).tostring("yyyy-MM-dd_hh-mm-ss"))";
    $accepted       = $TRUE;
    $invalidChars   = [io.path]::GetInvalidFileNamechars();
    $compress       = if ($source.compress) { $source.compress } else { $sources.compress };
    $destination    = if ($source.destination) { $source.destination } else { ($settings.providers | Where-Object {$_.name -eq "local"}).path };
    $password       = if ($source.password) { $source.password } else { $sources.password };
    $verify         = if ($source.verify) { $source.verify } else { $sources.verify };
    $switches       = "a";
    $executed       = $FALSE;
    $status         = "`n---`nThe job not running: LASTEXITCODE: $($LASTEXITCODE)";
    $total          = $total + 1;

    ###
    ###
    if (-not $source.path) {
        #------------------------------------------
        LogWrite "$($script_name) path not exists, the backup will not be created..." "yellow";

        #
        $accepted = $FALSE;
        $ignored  = $ignored + 1;
    };

    if ($accepted -eq $TRUE -and -not $destination) {
        #------------------------------------------
        LogWrite "$($script_name) destination path not defined for $($name): $($source.path): backup will not be created..." "yellow";

        #
        $accepted = $FALSE;
        $ignored  = $ignored + 1;
    };

    if ($accepted -eq $TRUE -and -not (Test-Path -Path $source.path)) {
        #------------------------------------------
        LogWrite "$($script_name) $($source.path) not found: backup will not be created..." "yellow";

        #
        $accepted = $FALSE;
        $ignored  = $ignored + 1;
    };

    if (-not (Test-Path -Path $destination)) {
        #------------------------------------------
        LogWrite "$($script_name) $($destination) path not found or access denied: backup will not be created..." "yellow";

        #
        $accepted = $FALSE;
        $ignored  = $ignored + 1;
    };

    ###
    ###
    if(-not $source.name -and $accepted -eq $TRUE) {
        $name = "$($name)_$((Split-Path $source.path -leaf))_$(Get-Random -Minimum 1 -Maximum 99999999)";
        $name = ($name.ToString() -replace "[$invalidChars]","_");
    };

    if($source.name -and $accepted -eq $TRUE) {
        $name = "$($name)_$($source.name)_$(Get-Random -Minimum 1 -Maximum 99999999)";
        $name = ($name.ToString() -replace "[$invalidChars]","_");
    };

    ###
    ###
    if ($compress) {
        # #------------------------------------------
        LogWrite "Compress required" $colors[13];

        #
        $compress       = "-mx5";
        $compressed     = $compressed + 1;
    }

    if (-not $compress) {
        $compress = "";
    }

    if ($password) {
        # #------------------------------------------
        LogWrite "Password protection required" $colors[13];

        #
        $password   = "-p$($password)";
        $protected  = $protected + 1;
    }

    if (!$password) {
        $password   = "";
    }

    ###
    ###
    if ($accepted) {
        # #------------------------------------------
        LogWrite "$($destination) validation passed. Running zipper" $colors[13];
        
        #
        $source_size    =   (Get-ChildItem $source.path | Measure-Object -Property Length -sum).Sum;
        $total_size     =   $total_size + $source_size;
        $processed      =   $processed + 1;
        $destination    =   "$($destination)\$($name).7z";
        $result         = & $settings.zipper $switches $compress $password $destination $source.path;

        # #------------------------------------------
        LogWrite "$($destination) archive size is $([math]::Round(($source_size / 1Mb),2)) Mb. Starting zipper" "white";

        #
        $status         = $result + $messages[$LASTEXITCODE] + $LASTEXITCODE;
        $color          = $colors[$LASTEXITCODE];
        $executed       = $TRUE;
    
        #
        if ($LASTEXITCODE -ne 0) {
            $faulted    = $faulted + 1;
            $processed  = $processed - 1;
        };
    };

    ###
    ###
    if ($accepted -and $executed) {
        # #------------------------------------------
        LogWrite $status $color;

        # #------------------------------------------
        LogWrite "Destination archive size is $([math]::Round((((Get-ChildItem $destination| Measure-Object -Property Length -sum).Sum) / 1Mb),2)) Mb" $color;
    };

    ###
    ###
    if($accepted -and $executed -and $verify) {
        # #------------------------------------------
        LogWrite "$($destination) verification requested" $colors[13];

        #
        $switches       = "t";
        $result         = & $settings.zipper $switches $password $destination;
        $status         = $result + $messages[$LASTEXITCODE] + $LASTEXITCODE;
        $color          = $colors[$LASTEXITCODE];
        $verifed        = $verifed + 1;

        # #------------------------------------------
        LogWrite $status $color;
    };
};

#------------------------------------------
LogWrite "$($script_name) Operation complited. Total backup jobs: $($total). Total size $([math]::Round(($total_size / 1Mb),2)) Mb. Processed: $($processed). Faulted: $($faulted). Ignored: $($ignored). Exiting..." $colors[12];

Exit;