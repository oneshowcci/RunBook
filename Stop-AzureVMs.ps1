<#
.SYNOPSIS
  Connects to Azure and stops of all VMs in the specified Azure subscription or cloud service

.DESCRIPTION
  This runbook connects to Azure and stops all classic VMs in an Azure subscription or cloud service.  
  You can attach a schedule to this runbook to run it at a specific time.  

  REQUIRED AUTOMATION ASSETS
  1. An Automation variable asset called "AzureSubscriptionId" that contains the GUID for this Azure subscription.  
     To use an asset with a different name you can pass the asset name as a runbook input parameter or change the default value for the input parameter.
  2. An Automation credential asset called "AzureCredential" that contains the Azure AD user credential with authorization for this subscription. 
     To use an asset with a different name you can pass the asset name as a runbook input parameter or change the default value for the input parameter.
  3. An ServiceName is required to STOP only one Service Name. ALL VMs in Service Name are affected.

.PARAMETER AzureCredentialAssetName
   Optional with default of "AzureCredential".
   The name of an Automation credential asset that contains the Azure AD user credential with authorization for this subscription. 
   To use an asset with a different name you can pass the asset name as a runbook input parameter or change the default value for the input parameter.

.PARAMETER AzureSubscriptionIdAssetName
   Optional with default of "AzureSubscriptionId".
   The name of An Automation variable asset that contains the GUID for this Azure subscription.
   To use an asset with a different name you can pass the asset name as a runbook input parameter or change the default value for the input parameter.

.PARAMETER ServiceName
   Mandatory
   Allows you to specify the cloud service containing the VMs to stop.  
   If this parameter is included, only VMs in the specified cloud service will be stopped, otherwise all VMs in the subscription will be stopped.  

.NOTES
   AUTHOR: System Center Automation Team 
   LASTEDIT: September 4, 2015
#>

workflow Stop-AzureVMs
{   
    param (
        [Parameter(Mandatory=$false)] 
        [String]  $AzureCredentialAssetName = 'Default Azure Admins',
        
        [Parameter(Mandatory=$false)]
        [String] $AzureSubscriptionIdAssetName = 'Default Azure SubId', 

        [Parameter(Mandatory=$true)] 
        [String] $ServiceName
    )

    # Returns strings with status messages
    [OutputType([String])]

	# Connect to Azure and select the subscription to work against
	#$Cred = Get-AutomationPSCredential -Name $AzureCredentialAssetName
	$Cred = Get-AutomationPSCredential -Name 'Default Azure Admins'
	$null = Add-AzureAccount -Credential $Cred -ErrorAction Stop
	$SubId = Get-AutomationVariable -Name $AzureSubscriptionIdAssetName
    $null = Select-AzureSubscription -SubscriptionId $SubId -ErrorAction Stop

	# If there is a specific cloud service, then get all VMs in the service,
    # otherwise get all VMs in the subscription.
	#Write-Output "run"
    if ($ServiceName) 
	{ 
		$VMs = Get-AzureVM -ServiceName $ServiceName
	}


    # Stop each of the started VMs
    foreach ($VM in $VMs)
    {
		if ($VM.PowerState -eq "Stopped")
		{
			# The VM is already stopped, so send notice
			Write-Output ($VM.InstanceName + " is already stopped")
		}
		else
		{
			# The VM needs to be stopped
        	$StopRtn = Stop-AzureVM -Name $VM.Name -ServiceName $VM.ServiceName -Force -ErrorAction Continue

	        if ($StopRtn.OperationStatus -ne 'Succeeded')
	        {
				# The VM failed to stop, so send notice
                Write-Output ($VM.InstanceName + " failed to stop")
	        }
			else
			{
				# The VM stopped, so send notice
				Write-Output ($VM.InstanceName + " has been stopped")
			}
		}
    }
}