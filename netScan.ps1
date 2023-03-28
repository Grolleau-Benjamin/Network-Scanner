
$subnetLenght = 24
$param = @{
    "network" = "192.168.0."
    "subnetLenght" = $subnetLenght
    "startRange" = 1
    "endRange" = [math]::Pow(2, (32 - $subnetLenght)) - 2
    "jobsLimit" = 25
    "timeout" = 75
}

$utilisation = @"

Utilisation : 
    .\netScan.ps1
        => Default param 
            network      : 192.168.0.0      | @IP network
            subnetLenght : 24               | mask lenght
            jobsLimit    : 25               | max thread
            startRange   : 1                | first IP
            endRange     : 254              | last IP
            timeout      : 75               | max latence for ping
    
    OR 

    .\netScan.ps1 -network <192.168.1.0> -subnetLenght <24> {-startRange <1> -endRange <254> -jobsLimit <25> -timeout <75>}

"@

if ($args.Count -gt 0){
    for($i = 0 ; $i -lt $args.Count; $i+=1){
        if ($args[$i] -match "^-(.*)" -and $param.Keys -contains $args[$i].Substring(1)){
            $param[$args[$i].Substring(1)] = $args[$args.IndexOf($args[$i]) + 1]
        }
        else {
            Write-Host $utilisation
            exit -1
        }
        $i += 1
    }
}

$jobs = @()

$pingScript = {
    param(
        $ip,
        $timeout
    )
    $ping = ping $ip -n 1 -w $timeout -l 16 2> $null
    if ($ping -and !$LASTEXITCODE){
        $ip
    }
    else {
        ""
    }
}

foreach($i in $param["startRange"]..$param["endRange"]){
    $ip = $param['network'] + "$i"
    
    Write-Host "`rIP =>" ([math]::Round(((100 / ($param["endRange"] - $param["startRange"])) * $i),2))"%" -NoNewline

    $jobs += Start-Job -ScriptBlock $pingScript -ArgumentList $ip, $param["timeout"]

    while($jobs.Count -ge $param["jobsLimit"]){
        $completedJobs = $jobs | Where-Object {$_.State -eq "Completed"}

        foreach ($job in $completedJobs){
            $result = Receive-Job -Job $job -Wait -AutoRemoveJob
            if ($result -ne ""){
                Write-Host "`r$result UP"
            }
            break
        }
        $jobs = $jobs | Where-Object { $_.InstanceId -ne $job.InstanceId }
    }
}
Write-Host "`r`r" -NoNewline

while ($jobs.Count -gt 0){
    $completedJobs = $jobs | Where-Object {$_.State -eq "Completed"}

    foreach ($job in $completedJobs){
        $result = Receive-Job -Job $job -Wait -AutoRemoveJob
        if ($result -ne ""){
            Write-Host "`r$result UP"
        }
        break
    }
    $jobs = $jobs | Where-Object { $_.InstanceId -ne $job.InstanceId }
    Start-Sleep -Milliseconds 10
}
