function Register-CriticalServices {
    <#
    .SYNOPSIS
    Collects the list of services from a remote machine and allows you to note register them as Critical
    
    .DESCRIPTION
    Collects the list of services from a remote machine and allows you to note register them as Critical. This exports the info to a 
    folder where it can be loaded by other functions for various checks.
    
    .PARAMETER Computer
    Name of remote computer

    .PARAMETER RunningOnly
    Displays only services that are currently running

    .PARAMETER OutputPath
    Where the output file will be stored
        
    .EXAMPLE
    Register-CriticalServices -Computer Server01 -OutputPath \\FILESERVER\RegisterLocation\
    Gets all services on Server01 and saves output to the remote file share

    .EXAMPLE
    Register-CriticalServices -Computer Server01 -RunningOnly -OutputPath \\FILESERVER\RegisterLocation\
    Gets all running services on Server01 and saves output to the remote file share

    #>
    [CmdletBinding(DefaultParameterSetName='Default')]
    param (
        [parameter(Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ParameterSetName='Default')]
        [string]$Computer,

        [parameter(Position=1,
        ValueFromPipeline=$true,
        ParameterSetName='Default')]
        [switch]$RunningOnly,

        [parameter(Position=2,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ParameterSetName='Default')]
        [string]$OutputPath

    )

    begin {

        if ($OutputPath -notmatch '.+?\\$') {
            $OutputPath = $OutputPath+"\"
        }
        if (!(Test-Connection $Computer -Count 2 -Quiet)) {
            throw "Machine may be offline"                        
        }
        if (!(Test-Path $OutputPath)) {
            throw "Output path not found"                        
        }
        $OutputFile = $OutputPath + $Computer + ".csv"

    }
    process {
        if ($RunningOnly.IsPresent) {
            $Services = Get-WmiObject Win32_Service -ComputerName $Computer | Select-Object SystemName,DisplayName,Name,State,StartMode,PathName,StartName | Where-Object {$_.State -eq "Running"}          
        } else {
            $Services = Get-WmiObject Win32_Service -ComputerName $Computer | Select-Object SystemName,DisplayName,Name,State,StartMode,PathName,StartName
        }

        $Critical_Services = $Services | Out-GridView -Title "Select Critical Services" -OutputMode Multiple

        $NonCritical_Services = $Services | Where-Object { $Critical_Services -notcontains $_ }

        $NonCritical_Services | Add-Member -MemberType NoteProperty -Name "CriticalService" -Value 0
        $Critical_Services | Add-Member -MemberType NoteProperty -Name "CriticalService" -Value 1
    }
    end {
        $Output = $Critical_Services
        $Output += $NonCritical_Services
        
        $Output | Sort-Object CriticalService -Descending | Export-Csv -Path $OutputFile -NoTypeInformation

    }
}