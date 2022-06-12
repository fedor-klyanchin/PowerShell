function Test-AvailabilityExternalResource{
    $(Invoke-RestMethod -Method Get 'www.msftconnecttest.com/connecttest.txt' -ErrorAction Ignore) -or
    $(Invoke-RestMethod -Method Get 'www.google.com' -ErrorAction Ignore)
}
#Test-AvailabilityExternalResource

function Test-Proxy{
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [parameter(Mandatory=$false)]
        [switch]$Connect,
        [Parameter(ValueFromRemainingArguments)]
        [string[]]$Remaining
    )
    Process{
        $Proxy=Get-NetTCPConnection | #select *
            ? -FilterScript {
                $PID -eq $_.OwningProcess -and 
                $_.AppliedSetting -eq 'Internet' -and
                $_.RemoteAddress -ne '127.0.0.1' -and
                $_.RemoteAddress -ne '0.0.0.0' -and
                $_.RemotePort -ne '0' -and
                $_.RemotePort -ne '80' -and
                $_.RemotePort -ne '443'
            } | 
                Sort RemoteAddress |
                    Select -First 1 RemoteAddress,RemotePort #? RemotePort -eq 3128 #-ExpandProperty RemoteAddress 

        if($Proxy){
            $ProxyAddress="http://$(([System.Net.Dns]::GetHostByAddress($($Proxy.RemoteAddress))).HostName | Select -First 1):$($Proxy.RemotePort)"
            if($Connect){
                [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy($ProxyAddress)
                [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
                [System.Net.WebRequest]::DefaultWebProxy.BypassProxyOnLocal = $true
            }

            if(Test-Connection $Proxy.RemoteAddress  -Count 1 -Quiet){
                Write-Host -ForegroundColor Green "$((Get-Date).ToString()) - $env:COMPUTERNAME - $env:USERNAME - Proxy '$ProxyAddress' available"
            }
            else{
                Write-Host -ForegroundColor Red "$((Get-Date).ToString()) - $env:COMPUTERNAME - $env:USERNAME - Proxy '$ProxyAddress' not available"
            }
        }
    }
}
#Test-Proxy

function Test-NetworkConnection{
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [parameter(Mandatory=$false)]
        [string]$ProxyAddress,
        [parameter(Mandatory=$false)]
        [string]$PerimeterSwitch,
        [Parameter(ValueFromRemainingArguments)]
        [string[]]$Remaining
    )
    Process{
        $Win32_NetworkAdapterConfiguration=@()
        $Win32_NetworkAdapterConfiguration=@(
            Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ErrorAction Continue -Property * | #-Filter "IPEnabled=$true" 
                Select MACAddress,Description,DHCPServer,DNSDomainSuffixSearchOrder,DNSServerSearchOrder,IPAddress,IPEnabled,DefaultIPGateway,IPSubnet #| FT -AutoSize -Wrap
        )

        if($Win32_NetworkAdapterConfiguration.Count){
            if(($Win32_NetworkAdapterConfiguration.IPEnabled) -contains $true){
                Write-Host -ForegroundColor Green "$((Get-Date).ToString()) - $env:COMPUTERNAME - $env:USERNAME - Connected to the network"

                if($Win32_NetworkAdapterConfiguration.DefaultIPGateway){
                    if(
                        $(
                            foreach($DefaultIPGateway in $Win32_NetworkAdapterConfiguration.DefaultIPGateway){
                                try{
                                    if(Test-Connection -ComputerName $DefaultIPGateway -Quiet -Count 1 -ErrorAction Ignore){
                                        $true
                                    }
                                }
                                catch{
                                }
                            }
                        )
                    ){
                        Write-Host -ForegroundColor Green "$((Get-Date).ToString()) - $env:COMPUTERNAME - $env:USERNAME - Gateway available"
                    }
                    else{
                        Write-Host -ForegroundColor Red "$((Get-Date).ToString()) - $env:COMPUTERNAME - $env:USERNAME - Offline. Gateway not available"
                    }
                }

                if($env:USERDOMAIN -ne $env:COMPUTERNAME){
                    $TestConnectionDomain=Test-Connection $env:USERDNSDOMAIN -Count 1 -ErrorAction Ignore
                    if($TestConnectionDomain | Select -ExpandProperty ProtocolAddress){
                        Write-Host -ForegroundColor Green "$((Get-Date).ToString()) - $env:COMPUTERNAME - $env:USERNAME - Domain $($env:USERDNSDOMAIN) ($($TestConnectionDomain | Select -ExpandProperty ProtocolAddress)) available"
                    }
                    else{
                        Write-Host -ForegroundColor Red "$((Get-Date).ToString()) - $env:COMPUTERNAME - $env:USERNAME - Domain $($env:USERDNSDOMAIN) not available"
                    }
                }

                if(
                    (Test-Connection www.msftconnecttest.com  -Count 1 -Quiet) -or
                    (Test-Connection www.google.com  -Count 1 -Quiet)
                ){
                    Write-Host -ForegroundColor Green "$((Get-Date).ToString()) - $env:COMPUTERNAME - $env:USERNAME - Internet available"
                    if(Get-Command Invoke-RestMethod -ErrorAction Ignore){
                        if(
                            !$(
                                try{
                                    Test-AvailabilityExternalResource
                                    Test-Proxy
                                }
                                catch{
                                    Test-Proxy -Connect
                                    try{Test-AvailabilityExternalResource}catch{}
                                }
                            )
                        ){
                            Write-Host -ForegroundColor Red "$((Get-Date).ToString()) - $env:COMPUTERNAME - $env:USERNAME - External resources not available"
                        }
                        else{
                            Write-Host -ForegroundColor Green "$((Get-Date).ToString()) - $env:COMPUTERNAME - $env:USERNAME - External resources available"
                        }
                    }
                    else{
                        Write-Host "$((Get-Date).ToString()) - $env:COMPUTERNAME - $env:USERNAME - Failed to check availability of external resources"
                    }
                }
                else{
                    Write-Host -ForegroundColor Red "$((Get-Date).ToString()) - $env:COMPUTERNAME - $env:USERNAME - Internet not available"
                }

                if($PerimeterSwitch){
                    foreach($Provider in $(try{([System.Net.Dns]::GetHostByName($PerimeterSwitch)).AddressList | Sort IPAddressToString | Select -ExpandProperty IPAddressToString}catch{})){
                        if(Test-Connection $Provider -Count 1 -Quiet -ErrorAction Ignore){
                            Write-Host -ForegroundColor Green "$((Get-Date).ToString()) - $env:COMPUTERNAME - $env:USERNAME - Provider '$Provider' available"
                        }
                        else{
                            Write-Host -ForegroundColor Red "$((Get-Date).ToString()) - $env:COMPUTERNAME - $env:USERNAME - Provider '$Provider' not available"
                        }
                    }
                }
            }
            else{
                Write-Host -ForegroundColor Red "$((Get-Date).ToString()) - $env:COMPUTERNAME - $env:USERNAME - Offline. No network connection"
                $Win32_NetworkAdapterConfiguration | ? MACAddress -like '*:*' | Sort Description | Select Description,MACAddress
            }
        }
        else{
            Write-Host -ForegroundColor Red "$((Get-Date).ToString()) - $env:COMPUTERNAME - $env:USERNAME - Failed to get information about network adapters"
        }
    }
}
Test-NetworkConnection
#Test-NetworkConnection -PerimeterSwitch 'gate.companyname.com'
