<# ----- About: ----
    # N-able | Cove Data Protection Get Device Locations & Statistics 
    # Revision v02 - 2022-10-15
    # Author: Eric Harless, Head Backup Nerd - N-able 
    # Twitter @Backup_Nerd  Email:eric.harless@n-able.com
    # Reddit https://www.reddit.com/r/Nable/
# -----------------------------------------------------------#>  ## About

<# ----- Legal: ----
    # Sample scripts are not supported under any N-able support program or service.
    # The sample scripts are provided AS IS without warranty of any kind.
    # N-able expressly disclaims all implied warranties including, warranties
    # of merchantability or of fitness for a particular purpose. 
    # In no event shall N-able or any other party be liable for damages arising
    # out of the use of or inability to use the sample scripts.
# -----------------------------------------------------------#>  ## Legal

<# ----- Compatibility: ----
    # For use with the Standalone edition of N-able | Cove Data Protection
    # Sample scripts may contain non-public API calls which are subject to change without notification
# -----------------------------------------------------------#>  ## Compatibility

<# ----- Behavior: ----
    # Check/ Get/ Store secure credentials 
    # Authenticate to https://backup.management console
    # Check partner level/ Enumerate partners/ GUI select partner
    # Enumerate devices/ GUI select devices
    # Pull device sttistics and storage locations
    # Optionally export to XLS/CSV
    #
    # Use the -AllPartners switch parameter to skip GUI partner selection
    # Use the -AllDevices switch parameter to skip GUI device selection
    # Use the -DeviceCount ## (default=5000) parameter to define the maximum number of devices returned
    # Use the -Export switch parameter to export statistics to XLS/CSV files
    # Use the -ExportPath (?:\Folder) parameter to specify XLS/CSV file path
    # Use the -Launch switch parameter to launch the XLS/CSV file after completion
    # Use the -Delimiter (default=',') parameter to set the delimiter for XLS/CSV output (i.e. use ';' for The Netherland)
    # Use the -Mute switch parameter to silence voice prompts in the script
    # Use the -ClearCredentials parameter to remove stored API credentials at start of script
    #
    # https://documentation.n-able.com/covedataprotection/USERGUIDE/documentation/Content/service-management/json-api/home.htm
    # https://documentation.n-able.com/covedataprotection/USERGUIDE/documentation/Content/service-management/json-api/API-column-codes.htm

# -----------------------------------------------------------#>  ## Behavior

[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$False)] [switch]$AllPartners,                         ## Skip partner selection
        [Parameter(Mandatory=$False)] [switch]$AllDevices,                          ## Skip device selection
        [Parameter(Mandatory=$False)] [switch]$Export = $true,                      ## Generate CSV / XLS Output Files
        [Parameter(Mandatory=$False)] [switch]$Launch = $true,                      ## Launch XLS or CSV file 
        [Parameter(Mandatory=$False)] [int]$DeviceCount = 5000,                     ## Change Maximum Number of devices results to return
        [Parameter(Mandatory=$False)] [string]$Delimiter = ',',                     ## Specify ',' or ';' Delimiter for XLS & CSV file   
        [Parameter(Mandatory=$False)] $ExportPath = "$PSScriptRoot",                ## Export Path
        [Parameter(Mandatory=$False)][switch]$Mute,                                 ## Remove Voice from Script
        [Parameter(Mandatory=$False)] [switch]$ClearCredentials                     ## Remove Stored API Credentials at start of script
    )

#region ----- Environment, Variables, Names and Paths ----
    Clear-Host
    $ConsoleTitle = "Get Device Locations"
    $host.UI.RawUI.WindowTitle = $ConsoleTitle
    $scriptpath = $MyInvocation.MyCommand.Path
    Write-output "  $ConsoleTitle`n`n$ScriptPath"
    $Syntax = Get-Command $PSCommandPath -Syntax
    Write-Output "  Script Parameter Syntax:`n`n  $Syntax"

    $dir = Split-Path $scriptpath
    Push-Location $dir
    $CurrentDate = Get-Date -format "yyy-MM-dd_HH-mm-ss"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $Script:strLineSeparator = "  ---------"
    $urljson = "https://api.backup.management/jsonapi"

    Write-output "  Current Parameters:"
    Write-output "  -AllPartners = $AllPartners"
    Write-output "  -AllDevices  = $AllDevices"
    Write-output "  -DeviceCount = $DeviceCount"
    Write-output "  -Export      = $Export"
    Write-output "  -Launch      = $Launch"
    Write-output "  -ExportPath  = $ExportPath"
    Write-output "  -Delimiter   = $Delimiter"

#endregion ----- Environment, Variables, Names and Paths ----

#region ----- Functions ----

#region ----- Authentication ----
    Function Set-APICredentials {

        Write-Output $Script:strLineSeparator 
        Write-Output "  Setting Backup API Credentials" 
        if (Test-Path $APIcredpath) {
            Write-Output $Script:strLineSeparator 
            Write-Output "  Backup API Credential Path Present" }else{ New-Item -ItemType Directory -Path $APIcredpath} 
 
            Write-Output "  Enter Exact, Case Sensitive Partner Name for the N-able Backup.Management API i.e. 'Acme, Inc (bob@acme.net)'"
        DO{ $Script:PartnerName = Read-Host "  Enter Login Partner Name" }
        WHILE ($PartnerName.length -eq 0)
        $PartnerName | out-file $APIcredfile

        $BackupCred = Get-Credential -UserName "" -Message 'Enter Login Email and Password for the N-able Backup.Management API'
        $BackupCred | Add-Member -MemberType NoteProperty -Name PartnerName -Value "$PartnerName" 

        $BackupCred.UserName | Out-file -append $APIcredfile
        $BackupCred.Password | ConvertFrom-SecureString | Out-file -append $APIcredfile
        
        Start-Sleep -milliseconds 300

        Send-APICredentialsCookie  ## Attempt API Authentication

    }  ## Set API credentials if not present

    Function Get-APICredentials {

        $Script:True_path = "C:\ProgramData\MXB\"
        $Script:APIcredfile = join-path -Path $True_Path -ChildPath "$env:computername API_Credentials.Secure.txt"
        $Script:APIcredpath = Split-path -path $APIcredfile
    
        if (($ClearCredentials) -and (Test-Path $APIcredfile)) { 
            Remove-Item -Path $Script:APIcredfile
            $ClearCredentials = $Null
            Write-Output $Script:strLineSeparator 
            Write-Output "  Backup API Credential File Cleared"
            Send-APICredentialsCookie  ## Retry Authentication
            
            }else{ 
                Write-Output $Script:strLineSeparator 
                Write-Output "  Getting Backup API Credentials" 
            
                if (Test-Path $APIcredfile) {
                    Write-Output    $Script:strLineSeparator        
                    "  Backup API Credential File Present"
                    $APIcredentials = get-content $APIcredfile
                    
                    $Script:cred0 = [string]$APIcredentials[0] 
                    $Script:cred1 = [string]$APIcredentials[1]
                    $Script:cred2 = $APIcredentials[2] | Convertto-SecureString 
                    $Script:cred2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Script:cred2))
    
                    Write-Output    $Script:strLineSeparator 
                    Write-output "  Stored Backup API Partner  = $Script:cred0"
                    Write-output "  Stored Backup API User     = $Script:cred1"
                    Write-output "  Stored Backup API Password = Encrypted"
                    
                    $script:UserFirstName = $($cred1.split(".")[0])
                    Speak "Hello $($cred1.split(".")[0]), Happy $((get-date).dayofweek)."

                }else{
                    Write-Output    $Script:strLineSeparator 
                    Write-Output "  Backup API Credential File Not Present"
    
                    Set-APICredentials  ## Create API Credential File if Not Found
                    }
                }
    
    }  ## Get API credentials if present

    Function Send-APICredentialsCookie {

    Get-APICredentials  ## Read API Credential File before Authentication

    $url = "https://api.backup.management/jsonapi"
    $data = @{}
    $data.jsonrpc = '2.0'
    $data.id = '2'
    $data.method = 'Login'
    $data.params = @{}
    $data.params.partner = $Script:cred0
    $data.params.username = $Script:cred1
    $data.params.password = $Script:cred2

    $webrequest = Invoke-WebRequest -Method POST `
        -ContentType 'application/json' `
        -Body (ConvertTo-Json $data) `
        -Uri $url `
        -SessionVariable Script:websession `
        -UseBasicParsing
        $Script:cookies = $websession.Cookies.GetCookies($url)
        $Script:websession = $websession
        $Script:Authenticate = $webrequest | convertfrom-json

    #Debug Write-output "$($Script:cookies[0].name) = $($cookies[0].value)"

    if ($authenticate.visa) { 

        $Script:visa = $authenticate.visa
        $script:UserId = $authenticate.result.result.id
        }else{
            Write-Output    $Script:strLineSeparator 
            Write-Output "  Authentication Failed: Please confirm your Backup.Management Partner Name and Credentials`n"
            Speak "Your Authentication failed, please check your credentials and try again."
            Write-Warning $authenticate.error.message
            Speak $authenticate.error.message
    
            Write-Output "  Please Note: Multiple failed authentication attempts could temporarily lockout your user account"
            Write-Output    $Script:strLineSeparator 
            
            Set-APICredentials  ## Create API Credential File if Authentication Fails
        }

    }  ## Use Backup.Management credentials to Authenticate

#endregion ----- Authentication ----

#region ----- Data Conversion ----
Function Convert-UnixTimeToDateTime($inputUnixTime){
    if ($inputUnixTime -gt 0 ) {
    $epoch = Get-Date -Date "1970-01-01 00:00:00Z"
    $epoch = $epoch.ToUniversalTime()
    $epoch = $epoch.AddSeconds($inputUnixTime)
    return $epoch
    }else{ return ""}
}  ## Convert epoch time to date time 

Function Speak {
    param (
        [parameter(Mandatory=$true)] [string]$message,
        [parameter(Mandatory=$false)] [switch]$async,
        [parameter(Mandatory=$false)] [switch]$MaleVoice
    )
    if ($mute) {
        Return
    }else{
    Add-Type -AssemblyName System.speech
    $Vocalize = New-Object System.Speech.Synthesis.SpeechSynthesizer
    #$Vocalize | Get-Member Speak
    if ($MaleVoice) {$Vocalize.SelectVoice('Microsoft David Desktop')} else {$Vocalize.SelectVoice('Microsoft Zira Desktop')}
    if ($async) {$Vocalize.Speakasync($message) | Out-Null} else {$Vocalize.Speak($message) | Out-Null}
    }
}  ## Convert text to speach 

Function Get-VisaTime {
    if ($Script:visa) {
        $VisaTime = (Convert-UnixTimeToDateTime ([int]$Script:visa.split("-")[3]))
        If ($VisaTime -lt (Get-Date).ToUniversalTime().AddMinutes(-10)){
            Send-APICredentialsCookie
        }
    }
}

Function Save-CSVasExcel {
    param (
        [string]$CSVFile = $(Throw 'No file provided.')
    )
    
    BEGIN {
        function Resolve-FullPath ([string]$Path) {    
            if ( -not ([System.IO.Path]::IsPathRooted($Path)) ) {
                # $Path = Join-Path (Get-Location) $Path
                $Path = "$PWD\$Path"
            }
            [IO.Path]::GetFullPath($Path)
        }

        function Release-Ref ($ref) {
            ([System.Runtime.InteropServices.Marshal]::ReleaseComObject([System.__ComObject]$ref) -gt 0)
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
        }
        
        $CSVFile = Resolve-FullPath $CSVFile
        $xl = New-Object -ComObject Excel.Application
    }

    PROCESS {
        $wb = $xl.workbooks.open($CSVFile)
        $xlOut = $CSVFile -replace '\.csv$', '.xlsx'
        
        # can comment out this part if you don't care to have the columns autosized
        $ws = $wb.Worksheets.Item(1)
        $range = $ws.UsedRange
        [void]$range.AutoFilter()
        [void]$range.EntireColumn.Autofit()

        $num = 1
        $dir = Split-Path $xlOut
        $base = $(Split-Path $xlOut -Leaf) -replace '\.xlsx$'
        $nextname = $xlOut
        while (Test-Path $nextname) {
            $nextname = Join-Path $dir $($base + "-$num" + '.xlsx')
            $num++
        }

        $wb.SaveAs($nextname, 51)
    }

    END {
        $xl.Quit()
    
        $null = $ws, $wb, $xl | ForEach-Object {Release-Ref $_}

        # del $CSVFile
    }
} ## Save as output XLS Routine

#endregion ----- Data Conversion ----

#region ----- Backup.Management JSON Calls ----

    Function Send-GetPartnerInfo ($PartnerName) { 
                    
        $url = "https://api.backup.management/jsonapi"
        $data = @{}
        $data.jsonrpc = '2.0'
        $data.id = '2'
        $data.visa = $Script:visa
        $data.method = 'GetPartnerInfo'
        $data.params = @{}
        $data.params.name = [String]$PartnerName

        $webrequest = Invoke-WebRequest -Method POST `
            -ContentType 'application/json' `
            -Body (ConvertTo-Json $data -depth 5) `
            -Uri $url `
            -SessionVariable Script:websession `
            -UseBasicParsing
            #$Script:cookies = $websession.Cookies.GetCookies($url)
            $Script:websession = $websession
            $Script:Partner = $webrequest | convertfrom-json

        $RestrictedPartnerLevel = @("Root","Sub-root","Distributor")

        if ($Partner.result.result.Level -notin $RestrictedPartnerLevel) {
            [String]$Script:Uid = $Partner.result.result.Uid
            [int]$Script:PartnerId = [int]$Partner.result.result.Id
            [String]$script:Level = $Partner.result.result.Level
            [String]$Script:PartnerName = $Partner.result.result.Name

            Write-Output $Script:strLineSeparator
            Write-output "  $PartnerName - $partnerId - $Uid"
            Write-Output $Script:strLineSeparator
            }else{
            Write-Output $Script:strLineSeparator
            Write-Host "  Lookup for $($Partner.result.result.Level) Partner Level Not Allowed"
            Write-Output $Script:strLineSeparator
            $Script:PartnerName = Read-Host "  Enter EXACT Case Sensitive Customer/ Partner displayed name to lookup i.e. 'Acme, Inc (bob@acme.net)'"
            Send-GetPartnerInfo $Script:partnername
            }

        if ($partner.error) {
            write-output "  $($partner.error.message)"
            $Script:PartnerName = Read-Host "  Enter EXACT Case Sensitive Customer/ Partner displayed name to lookup i.e. 'Acme, Inc (bob@acme.net)'"
            Send-GetPartnerInfo $Script:partnername

        }

    } ## get PartnerID and Partner Level    

    Function CallJSON($url,$object) {

        $bytes = [System.Text.Encoding]::UTF8.GetBytes($object)
        $web = [System.Net.WebRequest]::Create($url)
        $web.Method = "POST"
        $web.ContentLength = $bytes.Length
        $web.ContentType = "application/json"
        $stream = $web.GetRequestStream()
        $stream.Write($bytes,0,$bytes.Length)
        $stream.close()
        $reader = New-Object System.IO.Streamreader -ArgumentList $web.GetResponse().GetResponseStream()
        return $reader.ReadToEnd()| ConvertFrom-Json
        $reader.Close()
    }

    Function Send-EnumeratePartners {
        # ----- Get Partners via EnumeratePartners -----
        
        # (Create the JSON object to call the EnumeratePartners function)
            $objEnumeratePartners = (New-Object PSObject | Add-Member -PassThru NoteProperty jsonrpc '2.0' |
                Add-Member -PassThru NoteProperty visa $Script:visa |
                Add-Member -PassThru NoteProperty method 'EnumeratePartners' |
                Add-Member -PassThru NoteProperty params @{
                                                            parentPartnerId = $PartnerId 
                                                            fetchRecursively = "true"
                                                            fields = (0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22) 
                                                            } |
                Add-Member -PassThru NoteProperty id '1')| ConvertTo-Json -Depth 5
        
        # (Call the JSON Web Request Function to get the EnumeratePartners Object)
                [array]$Script:EnumeratePartnersSession = CallJSON $urlJSON $objEnumeratePartners
        
                $Script:visa = $EnumeratePartnersSession.visa
        
                #Write-Output    $Script:strLineSeparator
                #Write-Output    "  Using Visa:" $Script:visa
                #Write-Output    $Script:strLineSeparator
        
        # (Added Delay in case command takes a bit to respond)
                Start-Sleep -Milliseconds 100
        
        # (Get Result Status of EnumerateAccountProfiles)
                $EnumeratePartnersSessionErrorCode = $EnumeratePartnersSession.error.code
                $EnumeratePartnersSessionErrorMsg = $EnumeratePartnersSession.error.message
        
        # (Check for Errors with EnumeratePartners - Check if ErrorCode has a value)
                if ($EnumeratePartnersSessionErrorCode) {
                    Write-Output    $Script:strLineSeparator
                    Write-Output    "  EnumeratePartnersSession Error Code:  $EnumeratePartnersSessionErrorCode"
                    Write-Output    "  EnumeratePartnersSession Message:  $EnumeratePartnersSessionErrorMsg"
                    Write-Output    $Script:strLineSeparator
                    Write-Output    "  Exiting Script"
        # (Exit Script if there is a problem)
        
                    #Break Script
                }
                    Else {
        # (No error)
        
                $Script:EnumeratePartnersSessionResults = $EnumeratePartnersSession.result.result | select-object Name,@{l='Id';e={($_.Id).tostring()}},Level,ExternalCode,ParentId,LocationId,* -ExcludeProperty Company -ErrorAction Ignore
                
                $Script:EnumeratePartnersSessionResults | ForEach-Object {$_.CreationTime = [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($_.CreationTime))}
                $Script:EnumeratePartnersSessionResults | ForEach-Object { if ($_.TrialExpirationTime  -ne "0") { $_.TrialExpirationTime = [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($_.TrialExpirationTime))}}
                $Script:EnumeratePartnersSessionResults | ForEach-Object { if ($_.TrialRegistrationTime -ne "0") {$_.TrialRegistrationTime = [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($_.TrialRegistrationTime))}}
            
                $Script:SelectedPartners = $EnumeratePartnersSessionResults | Select-object * | Where-object {$_.name -notlike "001???????????????- Recycle Bin"} | Where-object {$_.Externalcode -notlike '`[??????????`]* - ????????-????-????-????-????????????'}
                        
                $Script:SelectedPartner = $Script:SelectedPartners += @( [pscustomobject]@{Name=$PartnerName;Id=[string]$PartnerId;Level='<ParentPartner>'} ) 
                
                
                if ($AllPartners) {
                    $script:Selection = $Script:SelectedPartners |Select-object id,Name,Level,CreationTime,State,TrialRegistrationTime,TrialExpirationTime,Uid | sort-object Level,name
                    Write-Output    $Script:strLineSeparator
                    Write-Output    "  All Partners Selected"
                }else{
                    $script:Selection = $Script:SelectedPartners |Select-object id,Name,Level,CreationTime,State,TrialRegistrationTime,TrialExpirationTime,Uid | sort-object Level,name | out-gridview -Title "Current Partner | $partnername" -OutputMode Single
            
                    if($null -eq $Selection) {
                        # Cancel was pressed
                        # Run cancel script
                        Write-Output    $Script:strLineSeparator
                        Write-Output    "  No Partners Selected"
                        Break
                    }
                    else {
                        # OK was pressed, $Selection contains what was chosen
                        # Run OK script
                        [int]$script:PartnerId = $script:Selection.Id
                        [String]$script:PartnerName = $script:Selection.Name
                    }
                }

        }
        
    }  ## EnumeratePartners API Call

    Function Send-GetStorageNodes ($device) {

        $url = "https://cloudbackup.management/jsonapi"
        $method = 'POST'
        $data = @{}
        $data.jsonrpc = '2.0'
        $data.id = '2'
        $data.visa = $Script:visa
        $data.method = 'EnumerateStorageNodesByAccountId'
        $data.params = @{}
        $data.params.accounts = @($device)

        $jsondata = (ConvertTo-Json $data -depth 6)
    
        $params = @{
            Uri         = $url
            Method      = $method
            Headers     = @{ 'Authorization' = "Bearer $Script:visa" }
            Body        = ([System.Text.Encoding]::UTF8.GetBytes($jsondata))
            ContentType = 'application/json; charset=utf-8'
        }  

        $Script:StorageNodes = Invoke-RestMethod @params 

        $StorageNodes.result.result.storagenodes.commoninfo.name -join ' '

    }

    Function Send-GetDevices {

        $url = "https://api.backup.management/jsonapi"
        $method = 'POST'
        $data = @{}
        $data.jsonrpc = '2.0'
        $data.id = '2'
        $data.visa = $Script:visa
        $data.method = 'EnumerateAccountStatistics'
        $data.params = @{}
        $data.params.query = @{}
        $data.params.query.PartnerId = [int]$PartnerId
        $data.params.query.Filter = $Filter1
        $data.params.query.Columns = @("AU","AR","AN","MN","AL","LN","OP","OI","OS","OT","PD","AP","PF","PN","CD","TS","TL","T3","US","TB","I81","AA843","AA77","AA2048","EI","IP","MF","MO")
        $data.params.query.OrderBy = "CD DESC"
        $data.params.query.StartRecordNumber = 0
        $data.params.query.RecordsCount = $devicecount
        $data.params.query.Totals = @("COUNT(AT==1)","SUM(T3)","SUM(US)")

        $jsondata = (ConvertTo-Json $data -depth 6)
    
        $params = @{
            Uri         = $url
            Method      = $method
            Headers     = @{ 'Authorization' = "Bearer $Script:visa" }
            Body        = ([System.Text.Encoding]::UTF8.GetBytes($jsondata))
            ContentType = 'application/json; charset=utf-8'
        }  

        $Script:DeviceResponse = Invoke-RestMethod @params 

        $Script:DeviceDetail = @()
    
        ForEach ( $DeviceResult in $DeviceResponse.result.result ) {

        $Script:DeviceDetail += New-Object -TypeName PSObject -Property @{ AccountID = [Int]$DeviceResult.AccountId;
                                                                    PartnerID        = [string]$DeviceResult.PartnerId;
                                                                    DeviceName       = $DeviceResult.Settings.AN -join '' ;
                                                                    ComputerName     = $DeviceResult.Settings.MN -join '' ;
                                                                    DeviceAlias      = $DeviceResult.Settings.AL -join '' ;
                                                                    PartnerName      = $DeviceResult.Settings.AR -join '' ;
                                                                    Reference        = $DeviceResult.Settings.PF -join '' ;
                                                                    Creation         = Convert-UnixTimeToDateTime ($DeviceResult.Settings.CD -join '') ;
                                                                    TimeStamp        = Convert-UnixTimeToDateTime ($DeviceResult.Settings.TS -join '') ;
                                                                    LastSuccess      = Convert-UnixTimeToDateTime ($DeviceResult.Settings.TL -join '') ;
                                                                    Last28Days       = (($DeviceResult.Settings.TB -join '')[-1..-28] -join '') -replace("8",[char]0x26a0) -replace("7",[char]0x23f9) -replace("6",[char]0x23f9) -replace("5",[char]0x2611) -replace("2",[char]0x2612) -replace("1",[char]0x2BC8) -replace("0",[char]0x2610) ;
                                                                    Last28           = (($DeviceResult.Settings.TB -join '')[-1..-28] -join '') -replace("8","!") -replace("7","!") -replace("6","?") -replace("5","+") -replace("2","-") -replace("1",">") -replace("0","X") ;
                                                                    SelectedGB       = (($DeviceResult.Settings.T3 -join '') /1GB) ;
                                                                    UsedGB           = (($DeviceResult.Settings.US -join '') /1GB) ;
                                                                    DataSources      = $DeviceResult.Settings.AP -join '' ;                                                                
                                                                    Account          = $DeviceResult.Settings.AU -join '' ;
                                                                    Location         = $DeviceResult.Settings.LN -join '' ;
                                                                    Notes            = $DeviceResult.Settings.AA843 -join '' ;
                                                                    GUIPassword      = $DeviceResult.Settings.AA2048 -join '' ;                                                                    
                                                                    TempInfo         = $DeviceResult.Settings.AA77 -join '' ;
                                                                    Product          = $DeviceResult.Settings.PN -join '' ;
                                                                    ProductID        = $DeviceResult.Settings.PD -join '' ;
                                                                    Profile          = $DeviceResult.Settings.OP -join '' ;
                                                                    ProfileID        = $DeviceResult.Settings.OI -join '' ;
                                                                    Physicality      = $DeviceResult.Settings.I81 -join '';
                                                                    OS               = $DeviceResult.Settings.OS -join '' ;                                                                
                                                                    OSType           = $DeviceResult.Settings.OT -join '' ;
                                                                    IP               = $DeviceResult.Settings.IP -join '' ;
                                                                    EXTIP            = $DeviceResult.Settings.EI -join '' ;
                                                                    MFG              = $DeviceResult.Settings.MF -join '' ;
                                                                    MODEL            = $DeviceResult.Settings.MO -join '' ;
                                                                    Storage          = Send-GetStorageNodes $DeviceResult.AccountId   
                                                                }
        }

    } ## EnumerateAccountStatistics API Call

    Function Send-GetUserViews ($PartnerName) { 
                    
        $url = "https://api.backup.management/jsonapi"
        $data = @{}
        $data.jsonrpc = '2.0'
        $data.id = '2'
        $data.visa = $Script:visa
        $data.method = 'EnumerateUserSettings'
        $data.params = @{}
        $data.params.userId = [int]$UserId

        $webrequest = Invoke-WebRequest -Method POST `
            -ContentType 'application/json' `
            -Body (ConvertTo-Json $data -depth 5) `
            -Uri $url `
            -SessionVariable Script:websession `
            -UseBasicParsing
            #$Script:cookies = $websession.Cookies.GetCookies($url)
            $Script:websession = $websession
            $Script:UserViews = $webrequest | convertfrom-json

    $userviews.result.result.view | format-table
    $userviews.result.result | Select-Object name,id,type,@{N="StatisticsFilter";E={$_.view.StatisticsFilter}},@{N="Columns";E={$_.view.Columns -join ','}}| Out-GridView
    $userviews.result.result | Select-Object name,id,type,@{N="StatisticsFilter";E={$_.view.StatisticsFilter}},@{N="Columns";E={$_.view.Columns -join ','}}| Format-table -AutoSize
    }
            

#endregion ----- Backup.Management JSON Calls ----

#endregion ----- Functions ----

    $switch = $PSCmdlet.ParameterSetName

    Send-APICredentialsCookie

    Write-Output $Script:strLineSeparator
    Write-Output "" 

    Send-GetPartnerInfo $Script:cred0

    if ($AllPartners) {}else{Send-EnumeratePartners}

    Send-GetDevices $partnerId

    #Send-GetStorageNodes

    if ($AllDevices) {
        $script:SelectedDevices = $DeviceDetail | Select-Object PartnerId,PartnerName,Reference,AccountID,DeviceName,ComputerName,Creation,TimeStamp,LastSuccess,Last28Days,ProductId,Product,ProfileId,Profile,DataSources,SelectedGB,UsedGB,OS,OSType,IP,EXTIP,MFG,MODEL,Physicality,Location,Storage
    }else{
        $script:SelectedDevices = $DeviceDetail | Select-Object PartnerId,PartnerName,Reference,AccountID,DeviceName,ComputerName,Creation,TimeStamp,LastSuccess,Last28Days,ProductId,Product,ProfileId,Profile,DataSources,SelectedGB,UsedGB,OS,OSType,IP,EXTIP,MFG,MODEL,Physicality,Location,Storage | Out-GridView -title "Current Partner | $partnername" -OutputMode Multiple}

    if($null -eq $SelectedDevices) {
        # Cancel was pressed
        # Run cancel script
        Write-Output    $Script:strLineSeparator
        Write-Output    "  No Devices Selected"
        Break
    }else{
        # OK was pressed, $Selection contains what was chosen
        # Run OK script
        $DeviceDetail | Select-Object PartnerName,AccountID,DeviceName,ComputerName,Creation,TimeStamp,LastSuccess,Last28,Product,Profile,DataSources,SelectedGB,UsedGB,OS,OSType,IP,EXTIP,MFG,MODEL,Physicality,Location,Storage  | Sort-object PartnerName,AccountId | format-table

        If ($Script:Export) {
            $Script:csvoutputfile = "$ExportPath\$($CurrentDate)_Statistics_$($Partnername -replace(`" \(.*\)`",`"`") -replace(`"[^a-zA-Z_0-9]`",`"`"))_$($PartnerId).csv"
            $Script:SelectedDevices | Select-object * | Export-CSV -path "$csvoutputfile" -delimiter "$Delimiter" -NoTypeInformation -Encoding UTF8}
            
    }

    ## Generate XLS from CSV
    
    if ($csvoutputfile) {
        $xlsoutputfile = $csvoutputfile.Replace("csv","xlsx")
        Save-CSVasExcel $csvoutputfile
    }
    Write-output $Script:strLineSeparator

    ## Launch CSV or XLS if Excel is installed  (Required -Launch Parameter)
        
    if ($Launch) {
        If (test-path HKLM:SOFTWARE\Classes\Excel.Application) { 
            Start-Process "$xlsoutputfile"
            Write-output $Script:strLineSeparator
            Write-Output "  Opening XLS file"
            }else{
            Start-Process "$csvoutputfile"
            Write-output $Script:strLineSeparator
            Write-Output "  Opening CSV file"
            Write-output $Script:strLineSeparator            
            }
        }
    Write-output $Script:strLineSeparator
    Write-Output "  CSV Path = $Script:csvoutputfile"
    Write-Output "  XLS Path = $Script:xlsoutputfile"
    Write-Output ""

    Speak "Bye $script:UserFirstName, Thank you for being an N-able | Cove Data Protection Partner"
    Start-Sleep -seconds 10