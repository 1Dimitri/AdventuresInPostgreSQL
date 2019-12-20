templ
function New-PgBaseBackup {
    param (
        # Root folder for backups
        [Parameter(Mandatory)]
        [string]
        $RootFolder,
        # TODO: not used yet
        [string]
        $HostName = $Env:COMPUTERNAME,

        [int]
        $port = 5432,
    
        # Optional location of the Postgres bin folder
        [string]
        $PgBin
    )
    
    if ([string]::IsNullOrEmpty($PgBin)) {
        $PgBin = Join-Path $env:ProgramFiles 'PostgreSQL'
        $PgBin = Join-Path $PgBin '11'
        $PgBin = Join-Path $PgBin 'bin'
        
    }

    $PgBasebackupExe = Join-Path $PgBin 'pg_basebackup.exe'

    if (!(Test-Path $PgBasebackupExe)) {
        throw "[$PgBasebackupExe] doesn't contain the pg_basebackup utility, please fix using the -PgBin parameter"
        exit
    }

    $PgBackupOptions = @(
        '-X','stream',
        '-R',
        '-c','fast',
         '-F','t',
         '-Z','9',
         '-p',$port
    )

    if (!(Test-Path $RootFolder)) {
        New-Item -ItemType Directory $RootFolder -Force -ErrorAction Continue | Out-Null
    }
    # Check it has been created

    if (!(Test-Path $RootFolder)) {
        throw "[$RootFolder] doesn't exist and could not be created"
        Exit
    }

    

    $timestamp = (Get-Date).ToUniversalTime().GetDateTimeFormats('u').Replace(':','').Replace('-','').Replace(' ','_')



    $foldername = "$($HostName)_$($Port)_$($timestamp)"

    $bkpfolder = Join-Path $RootFolder $foldername

    
    New-Item -ItemType Directory -Path $bkpfolder | Out-Null

    if (!(Test-Path $bkpfolder))  {
        throw "Could not create $bkpfolder"
        exit
    }
    if ((Get-ChildItem $bkpfolder).Count -ne 0) {
        throw "$bkpfolder is not empty"
        exit
    }

    $PgBackupOptions += @('-D',$bkpfolder)
    
    $result = Start-Process $PgBasebackupExe -ArgumentList $PgBackupOptions -WorkingDirectory $bkpfolder -Wait -PassThru

    return $result.ExitCode
}


#
function Remove-PgBaseBackup {
    param (
        # Root folder for backups
        [Parameter(Mandatory)]
        [string]
        $RootFolder,
        # TODO: not used yet
        [string]
        $HostName = $Env:COMPUTERNAME,

        [int]
        $port = 5432,

        [timespan]
        $Duration
    
 
    )

  
    if (!(Test-Path $RootFolder)) {
        throw "[$RootFolder] doesn't exist and could not be created"
        Exit
    }

    
    #TODO: Extract TimeStamp from folder names
    # if older than timespan -> erase


    #$timestamp = (Get-Date).ToUniversalTime().GetDateTimeFormats('u').Replace(':','').Replace('-','').Replace(' ','_')
    $now = Get-Date
    $timestampMax = $now.Subtract($Duration)

    [System.Globalization.CultureInfo]$InvariantCulture = [System.Globalization.CultureInfo]::InvariantCulture
    $dtStyleNone = [System.Globalization.DateTimeStyles]::None
    $datetimefileformat = 'yyyyMMdd_HHmmssK'

    Get-ChildItem -Path $RootFolder -Directory | ForEach-Object {

# SERVER
# 5432
# 20191219
# 134840Z

        #TODO Test Hostname and port

        Write-Verbose "Assessing $($_.BaseName)"
        $dirnamecomponents = $_.BaseName.split('_',3)
        $hostnamepart=$dirnamecomponents[0]

        if ($hostnamepart -ine $HostName) {
            Write-Verbose "$hostnamepart doesn't match $HostName"
            continue
        }
        
        $portpart=$dirnamecomponents[1]
        [ref]$portresult = [int] 0
        #todo typecast
        if ([int]::TryParse($portpart,$portresult)) {
            if ($portresult.Value -ne $port) {
                Write-Verbose "$portresult doesn't match $port"
                continue
            }
        }
        
        


        $dateString=$dirnamecomponents[2]
        [ref]$resultDate = [datetime]::new(0)
        if ([DateTime]::TryParseExact($dateString, $datetimefileformat,$InvariantCulture,$dtStyleNone,$resultDate)) {
            #resultDate valid
            if ($resultDate.Value -le $timestampMax) {
                Write-Verbose "Removing $($_.FullName)"
                Remove-Item -Path $_.FullName -Force  -Recurse
            }
        } 
    }

}
