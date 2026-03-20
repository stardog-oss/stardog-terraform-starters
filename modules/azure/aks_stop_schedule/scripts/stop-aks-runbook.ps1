param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$ClusterName
)

Write-Output "Checking AKS cluster '$ClusterName' in '$ResourceGroupName'..."

Connect-AzAccount -Identity -ErrorAction Stop | Out-Null

$cluster = Get-AzAksCluster -ResourceGroupName $ResourceGroupName -Name $ClusterName -ErrorAction Stop

if ($null -eq $cluster) {
    Write-Output "Cluster not found; nothing to stop."
    return
}

if ($cluster.PowerState.Code -eq "Stopped") {
    Write-Output "Cluster is already stopped."
    return
}

Write-Output "Stopping AKS cluster '$ClusterName'..."
try {
    Stop-AzAksCluster -ResourceGroupName $ResourceGroupName -Name $ClusterName -Force -ErrorAction Stop
} catch {
    if ($_.Exception -and $_.Exception.Message -match "parameter name 'Force'") {
        Write-Output "Force switch not supported by the installed Az.Aks module; retrying without -Force."
        Stop-AzAksCluster -ResourceGroupName $ResourceGroupName -Name $ClusterName -ErrorAction Stop
    } else {
        throw
    }
}
Write-Output "Stop request submitted."
