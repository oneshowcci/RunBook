workflow CopyStorageBlobContainer
{
    Param
    (
        [Parameter(Mandatory=$false)] 
        [String]  $AzureCredentialAssetName = 'Default Azure Admins',
        
        [Parameter(Mandatory=$false)]
        [String] $AzureSubscriptionIdAssetName = 'Default Azure SubId',
		
		[Parameter(Mandatory=$false)] 
        [String]  $SourceStorageAccount = 'raimostsaclassic', #Source storage account (classic)

        [Parameter(Mandatory=$false)] 
        [String]  $DestStorageAccount = 'raimostsabck', #Source storage account (classic)
		
		[Parameter(Mandatory=$false)] 
        [String]  $SourceStorageContainer = 'vhds', #destination container 
		
        [Parameter(Mandatory=$false)] 
        [String]  $DestStorageContainer = 'backup', #destination container 
		
		[Parameter(Mandatory=$false)] 
        [int]  $refresh = 30, #cloud service name
		
		[Parameter(Mandatory=$false)] 
        [int]  $maxloops = 100 #VM name
    )

    #Auth to Azure
    $Cred = Get-AutomationPSCredential -Name $AzureCredentialAssetName
   	$null = Add-AzureAccount -Credential $Cred -ErrorAction Stop
    $SubId = Get-AutomationVariable -Name $AzureSubscriptionIdAssetName
    $null = Select-AzureSubscription -SubscriptionId $SubId -ErrorAction Stop
	Write-Output "Auth OK"
	Inlinescript
	{
    #Create Context
    $SourceStorageKey = (Get-AzureStorageKey -StorageAccountName $Using:SourceStorageAccount).Primary
    $DestStorageKey = (Get-AzureStorageKey -StorageAccountName $Using:DestStorageAccount).Primary
    $SourceStorageContext = New-AzureStorageContext –StorageAccountName $using:SourceStorageAccount -StorageAccountKey $SourceStorageKey
    $DestStorageContext = New-AzureStorageContext –StorageAccountName $using:DestStorageAccount -StorageAccountKey $DestStorageKey
	Write-Output "Context OK"
		
    #Get all Blob List
    $Blobs = Get-AzureStorageBlob -Context $SourceStorageContext -Container $using:SourceStorageContainer
    $BlobCpyAry = @()
    $timeStamp = (get-date).ToString('ddd')
	
    Write-Output "Blobs"
    foreach ($Blob in $Blobs)
    {
  
        $BlobName = $Blob.Name
        $destblobname = "$timestamp-$BlobName"
        Write-Output "Start Copy $BlobName"
        $BlobCopy = Start-CopyAzureStorageBlob -Context $SourceStorageContext -SrcContainer $using:SourceStorageContainer -SrcBlob $BlobName `
            -DestContext $DestStorageContext -DestContainer $using:DestStorageContainer -DestBlob $destblobname
        $BlobCpyAry += $BlobCopy
    }

    $loops = 0
    Do
    {
        $loops++
        $check = $true
        Start-Sleep -Seconds $using:refresh
        foreach ($BlobCopy in $BlobCpyAry)
        {
            $CopyState = $BlobCopy | Get-AzureStorageBlobCopyState
            $Message = $CopyState.Source.AbsolutePath + " " + $CopyState.Status + " {0:N2}%" -f (($CopyState.BytesCopied/$CopyState.TotalBytes)*100) 
            Write-Output $Message
            if ($CopyState.Status -ne "Success")
            {
                $check = $false #se anche solo 1 non ha finito loop
            }
        }
    } until($check -or ($using:loops -ge $using:maxloops))

	}
}