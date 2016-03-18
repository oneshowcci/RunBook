#Server side storage copy
$SourceStorageAccount = "raimostsaclassic"
$DestStorageAccount = "raimostsabck"
$SourceStorageContainer = 'vhds'
$DestStorageContainer = 'backup'
$refresh = 10 #secondi
$maxloops = 100


#Auth to Azure 
$Cred = Get-AutomationPSCredential -Name $AzureCredentialAssetName 
$null = Add-AzureAccount -Credential $Cred -ErrorAction Stop 
$SubId = Get-AutomationVariable -Name $AzureSubscriptionIdAssetName 
$null = Select-AzureSubscription -SubscriptionId $SubId -ErrorAction Stop 


$SourceStorageKey = (Get-AzureStorageKey -StorageAccountName $SourceStorageAccount).Primary
$DestStorageKey = (Get-AzureStorageKey -StorageAccountName $DestStorageAccount).Primary
$SourceStorageContext = New-AzureStorageContext –StorageAccountName $SourceStorageAccount -StorageAccountKey $SourceStorageKey
$DestStorageContext = New-AzureStorageContext –StorageAccountName $DestStorageAccount -StorageAccountKey $DestStorageKey

$Blobs = Get-AzureStorageBlob -Context $SourceStorageContext -Container $SourceStorageContainer
$BlobCpyAry = @()
$timeStamp = (get-date).ToString('ddd')

foreach ($Blob in $Blobs)
{
  
   $BlobName = $Blob.Name
   $destblobname = "$timestamp-$BlobName"
   Write-Output "Start Copy $BlobName"
   $BlobCopy = Start-CopyAzureStorageBlob -Context $SourceStorageContext -SrcContainer $SourceStorageContainer -SrcBlob $BlobName `
      -DestContext $DestStorageContext -DestContainer $DestStorageContainer -DestBlob $destblobname
   $BlobCpyAry += $BlobCopy
}

$loops = 0
Do
{
$loops++
$check = $true
Start-Sleep -Seconds $refresh
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
} until($check -or ($loops -ge $maxloops))


