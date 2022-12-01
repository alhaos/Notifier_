using namespace System.Data.SQLite
using namespace System.Data.SqlClient
using namespace System.IO

Set-StrictMode -Version 'Latest'
Write-Debug "<!-- -->"
Add-Type -Path $PSScriptRoot\System.Data.SQLite.dll 
Write-Debug "<!-- -->"

#region declarations
function InterpretResult ([string] $Result) {
    $ResultDict = @{
        'ND'  = 'Not Detected' 
        'ON'  = 'Ongoing' 
        'INV' = 'Invalid' 
        'D'   = 'Detected' 
        'IN'  = 'Indeterminate' 
    }
    return $ResultDict.Keys -contains $Result ? $ResultDict.$Result : "Error"
}

function Start-LoadData {
    Write-LogInfo "LoadData start"
    $c = [SqlConnection]::new()
    $c.ConnectionString = $Notifier.Config.ConnectionString
    $cm = $c.CreateCommand()
    $cm.CommandText = @"
        select
        l.Accession                                     [Accession]
        , TRY_CONVERT(datetime, l.[Final Report Date])  [Final Report Date]
        , RTRIM(l.[Patient First Name])                 [First Name]
        , RTRIM(l.[Patient Last Name])                  [Last Name]
        , l.MI                                          [Middle Name]
        , l.DOB                                         [DOB]
        , l.[Client ID]                                 [Client ID]
        , l.[Client Name]                               [Client Name]
        , l.[Phys  Name]                                [Phys Name]
        , l.[Test Code]                                 [Test Code]
        , l.[Test Name]                                 [Test Name]
        , RTRIM(LTRIM(l.Result))                        [Test Result]
        , l.[Patient Address]                           [Patient Address]
        , l.[Patient City]                              [Patient City]
        , l.[Patient State]                             [Patient State]
        , l.[Patient Zip]                               [Patient Zip]
        , l.[Patient Phone]                             [Patient Phone]
    from logtest l
        left join LTEDB.dbo.COVID_MAILOUT mo on l.Accession = mo.Accession and l.[Test Code] = mo.TestCode
    where CAST(l.[Final Report Date] as date) > getdate() - 2
        and l.[Test Code] in ('950Z', '960Z')
        and l.[Final Report Date] is not null
        and LTRIM(l.[Final Report Date]) != ''
        and LTRIM(l.[DOB]) != ''
        and mo.Accession is NULL
        and rtrim(l.result) not in ('ON', 'ND')
        and l.[Client ID] in (#ClinetIdTag#)
    order by [Final Report Date], [Client ID]
"@ -replace '#ClinetIdTag#', (Get-ClientList)
        
    $c.Open()
    $cmdDelete = $Notifier.LocalConnection.CreateCommand()
    $cmdDelete.CommandText = "delete from RAW_DATA;"
    $null = $cmdDelete.ExecuteNonQuery()
    $cmdInsert = $Notifier.LocalConnection.CreateCommand()
    $dr = $cm.ExecuteReader()
    $i = 0
    while ($dr.Read()) {
        $i++
        $commandTest = @'
insert into RAW_DATA (
    ACCESSION,"FINAL REPORT DATE","FIRST NAME","LAST NAME","MIDDLE NAME",DOB,"CLIENT ID","CLIENT NAME","PHYS NAME","TEST CODE","TEST NAME","TEST RESULT","PATIENT ADDRESS","PATIENT CITY","PATIENT STATE","PATIENT ZIP","PATIENT PHONE"
)
values (
'{0}','{1}','{2}','{3}','{4}','{5}','{6}','{7}','{8}','{9}','{10}','{11}','{12}','{13}','{14}','{15}','{16}'
);
'@
        $cmdInsert.CommandText = $commandTest -f (
            $dr[0], $dr[1].ToString("yyyy-MM-dd HH:mm:ss"),
            $dr[2], $dr[3], $dr[4], $dr[5], $dr[6], $dr[7],
            $dr[8], $dr[9], $dr[10], (InterpretResult $dr[11]), $dr[12], $dr[13], $dr[14], $dr[15], $dr[16])
            
        $null = $cmdInsert.ExecuteNonQuery()
    }
    $c.Close()
    Write-LogInfo "LoadData fatched $i records"
    Write-LogInfo "LoadData end"
}

function Get-ClientList {
    $res = @()
    $c = $Notifier.LocalConnection.CreateCommand()
    $c.CommandText = "select ID from CLIENT"
    $dr = $c.ExecuteReader()
    while ($dr.Read()) {
        $res += , "'{0}'" -f $dr[0]
    }
    $dr.Close()
    return $res -join ","
}

class Notifier {
    [hashtable]$Config
    [Rep[]]$Reps
    [Client[]]$Clients
    [SQLiteConnection]$LocalConnection = [SQLiteConnection]::new()
    [SqlConnection]$RemoteConnection = [SqlConnection]::new()

    
    Notifier([hashtable]$Config) {
        $this.Config = $Config
        $this.LocalConnection.ConnectionString = "Data source=$PSScriptRoot/database.db;Version=3"        
        $this.LocalConnection.Open()
        $this.RemoteConnection.ConnectionString = $this.Config.ConnectionString
    }
}

Class Test {
    [string] ${ACCESSION}
    [string] ${Final Report Date}
    [string] ${First Name}
    [string] ${Last Name}
    [string] ${Middle Name}
    [string] ${DOB}
    [string] ${Client ID}
    [string] ${Client Name}
    [string] ${Phys Name}
    [string] ${Test Code}
    [string] ${Test Name}
    [string] ${Test Result}
    [string] ${Patient Address}
    [string] ${Patient City}
    [string] ${Patient State}
    [string] ${Patient Zip}
    [string] ${Patient Phone}
}

class Client {
    [string]$Name
    [string[]]$To
    [string[]]$Cc
    [string[]]$Bcc
    [Test[]]$TestArray

    [string]$Header = @"
    <title>Client report</title>
    <style>
        td,
        th {
            border-style: solid;
            border-color: black;
            border-width: 3px;
        }
    </style>
"@

    [string] GetHtmlBody () {
        $table = $this.TestArray | ConvertTo-Html -Fragment 
        return ConvertTo-Html -Body "$table" -Head $this.Header
    }
}

class Rep {
    [string]$Name
    [string[]]$To
    [string[]]$Cc
    [string[]]$Bcc
    [Test[]]$TestArray
}
#endregion
Add-Type -Path $PSScriptRoot\System.Data.SQLite.dll 
$Notifier = [Notifier]::new($args[0])

Write-Verbose ($Notifier.Config | ConvertTo-Json)
Write-Verbose ("Connection to loacl db state is: $($Notifier.LocalConnection.State)")