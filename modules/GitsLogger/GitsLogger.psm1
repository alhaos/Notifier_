using namespace system.IO

class LogSettings {
    static $Directory = ".\logs"
    static $Format = "{0:yyyy-MM-dd}.log"

    static [string] GetFileName () {
        return [Path]::Join([LogSettings]::Directory, [LogSettings]::Format -f [datetime]::Now)
    }

    static Write ([string]$Message, [string]$Level) {
        $Message = "{0:yyyy-MM-dd HH:mm:ss} | {1} | {2}" -f [datetime]::Now, $Level.PadRight(5),  $Message
        Write-Host $Message
        $file = [LogSettings]::GetFileName()
        $Message | Out-File $file -Append -Encoding utf8        
    }
}

function Write-LogInfo () {
    param($Message)
    [LogSettings]::Write($Message, "Info")
}

function Write-LogError {
    param($Message)
    [LogSettings]::Write($Message, "Error")
}

function Write-LogFatal {
    param($Message)
    [LogSettings]::Write($Message, "Fatal")
    Exit(1)
}
