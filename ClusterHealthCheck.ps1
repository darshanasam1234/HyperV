# Define variables
$reportPath = "$env:TEMP\HyperVClusterHealth.html"
$smtpServer = "smtp.yourdomain.com"
$from = "hyperv-report@yourdomain.com"
$to = "admin@yourdomain.com"
$subject = "Hyper-V Cluster Health Report"

# Initialize HTML report
$html = @"
<html>
<head>
<style>
body { font-family: Arial; }
table { border-collapse: collapse; width: 100%; }
th, td { border: 1px solid #ddd; padding: 8px; }
th { background-color: #f2f2f2; }
.good { background-color: #c6efce; color: #006100; }
.bad { background-color: #ffc7ce; color: #9c0006; }
</style>
</head>
<body>
<h2>Hyper-V Cluster Health Report</h2>
<table>
<tr><th>Check</th><th>Status</th><th>Details</th></tr>
"@

# Check for unclustered VMs
$clusteredVMs = Get-ClusterGroup | Where-Object {$_.GroupType -eq 'VirtualMachine'} | Select-Object -ExpandProperty Name
$allVMs = Get-VM | Select-Object -ExpandProperty Name
$unclusteredVMs = $allVMs | Where-Object {$_ -notin $clusteredVMs}
if ($unclusteredVMs.Count -eq 0) {
    $html += "<tr><td>Unclustered VMs</td><td class='good'>Healthy</td><td>All VMs are clustered</td></tr>"
} else {
    $html += "<tr><td>Unclustered VMs</td><td class='bad'>Issue</td><td>$($unclusteredVMs -join ', ')</td></tr>"
}

# Check for processor compatibility not enabled
$incompatibleVMs = Get-VM | Where-Object { $_.ProcessorCompatibilityForMigrationEnabled -eq $false }
if ($incompatibleVMs.Count -eq 0) {
    $html += "<tr><td>Processor Compatibility</td><td class='good'>Healthy</td><td>All VMs have compatibility enabled</td></tr>"
} else {
    $html += "<tr><td>Processor Compatibility</td><td class='bad'>Issue</td><td>$($incompatibleVMs.Name -join ', ')</td></tr>"
}

# Check for errors in Failover Cluster roles
$clusterErrors = Get-ClusterGroup | Where-Object { $_.State -ne 'Online' }
if ($clusterErrors.Count -eq 0) {
    $html += "<tr><td>Cluster Role Status</td><td class='good'>Healthy</td><td>All roles are online</td></tr>"
} else {
    $html += "<tr><td>Cluster Role Status</td><td class='bad'>Issue</td><td>$($clusterErrors.Name -join ', ')</td></tr>"
}

# Check for Hyper-V related errors in Event Logs
$hypervErrors = Get-WinEvent -LogName "Microsoft-Windows-Hyper-V-VMMS/Admin" -MaxEvents 50 | Where-Object { $_.LevelDisplayName -eq "Error" }
if ($hypervErrors.Count -eq 0) {
    $html += "<tr><td>Hyper-V Event Log</td><td class='good'>Healthy</td><td>No recent errors</td></tr>"
} else {
    $html += "<tr><td>Hyper-V Event Log</td><td class='bad'>Issue</td><td>$($hypervErrors[0..4] | ForEach-Object { $_.Message } -join '<br>')</td></tr>"
}

# Close HTML
$html += "</table></body></html>"
$html | Out-File -FilePath $reportPath -Encoding UTF8

# Send email
Send-MailMessage -From $from -To $to -Subject $subject -BodyAsHtml -Body (Get-Content $reportPath -Raw) -SmtpServer $smtpServer
