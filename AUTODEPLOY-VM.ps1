

# Importing the Modules
        Try
        {

            if (Get-Module -Name "AZUREVMDEPLOYMODULE") 
                {
                    Write-Host "Removing the Deployment Module 'AZUREVMDEPLOYMODULE'"
                    Remove-Module -Name "AZUREVMDEPLOYMODULE" -ErrorAction Stop
                }

            if (-not (Get-Module -Name "AZUREVMDEPLOYMODULE")) 
                {
                    Write-Host "Importing the Deployment Module 'AZUREVMDEPLOYMODULE'"
                    Import-Module C:\SI\ModuleLib\AZUREVMDEPLOYMODULE.psm1 -DisableNameChecking -ErrorAction Stop
                }

        }
        Catch
        {
                Write-Error -Message $_.Exception
                Write-Host "Importing the Deployment Module is failed $($_.Exception)"
                Throw
        }


$Global:LogFolder = "D:\AzureDeployLog"
$Global:LogFile = "$LogFolder\NEWVMLog-$($dateTimeNow).txt"
$Global:dateTimeNow = Get-Date -UFormat "%d-%m-%Y-%h"


#    Login-AzureRmAccount
# Sign-in to Azure via Azure Resource Manager  

    $azureParentDomainUser = "harsha.chitti@tieto.com"
    $azureParentDomainUserPassword = 'Welc0me2si'

  
    $AZLoginDetails = (New-Object System.Management.Automation.PSCredential $azureParentDomainUser,(ConvertTo-SecureString $azureParentDomainUserPassword -AsPlainText -Force))
    Login-AzureRmAccount -Credential $AZLoginDetails | Out-Null


# Select the Windows Os According the Subscption
  
    $VMDeploymentTypes = ("VMDEPLOY-EXISTINGVLAN","VMDEPLOY-NEWVLAN","REDEPLOY-EXISTINGVM","RESTORE-COURSE")
    $VMDeploymentType = ($VMDeploymentTypes | Out-GridView -Title "Select an VM DeployMent Type ..." -PassThru)
    Write-Logging "You have Selected the VM DeployMent Type is "[$VMDeploymentType]" ...)"


foreach($VMDeploy in $VMDeploymentType)
  {  

        Try
        {
            If ($VMDeploy -eq "REDEPLOY-EXISTINGVM")
                {
                    Import-Module .\ModuleLib\REDEPLOY-EXISTINGVM.psm1 -DisableNameChecking
                    $subscription = (Get-AzureRmSubscription | Out-GridView -Title "Select an Azure Subscription ..." -PassThru)
                    $VMName = Read-Host -Prompt 'Input your Virtual Machine Name'
                    $VMResourceGroupName = Read-Host -Prompt 'Input your Resouce Group Name'  
                    Write-Logging "The Virtual Machine Redeployment is Started [$VMName] "
                    REDEPLOY-EXISTINGVM -VMName $VMName -VMResourceGroupName $VMResourceGroupName -subscriptionName $subscription.Name -LogFolder $LogFolder
    
                }
            
            If ($VMDeploy -eq "RESTORE-COURSE")
                {
                        Write-Logging "Course Restore is Started"
                        .\ModuleLib\COURSE-RESTORE.ps1 -Credential $AZLoginDetails
                          
                }

            If (($VMDeploy -eq "VMDEPLOY-EXISTINGVLAN") -or ($VMDeploy -eq "VMDEPLOY-NEWVLAN"))
                {                        
                            # Select Azure Subscription
                            $subscriptionNames = ("SI Production DK test dev","SI Production SE test dev","SI Production NO test dev","SI Service and Support","SI Tieto","Bidroom Dev")
                            $subscriptionName = ( $subscriptionNames | Out-GridView -Title "Select an Azure Subscription ..." -PassThru)
                            Write-Logging "Selected Subscription for Operation is [$subscriptionName]"
                            Select-AzureRmSubscription -SubscriptionName $subscriptionName
                            Import-Module .\ModuleLib\VALIDATE-OSTEMPLATETYPE.psm1 -DisableNameChecking
                            Import-Module .\ModuleLib\NEW-VM-CREATION.psm1 -DisableNameChecking        
   
                                do
                                {
                                    $VMName = Read-Host -Prompt 'Input your Virtual Machine Name'
            
                                    if($VMName.Length -gt 15)
                                    {
                                        Write-Logging "The VM name Should not be more than 15 Character"
                                
                                    }

                                    $VMName  = $VMName.ToLower()
                                }

                            until (($VMName.Length -le 15))
        
                        $VMResourceGroupName = Read-Host -Prompt 'Input your Resouce Group Name'   
                   
            
                        If($VMDeploy -eq "VMDEPLOY-NEWVLAN")
                            {
                                
                                $VNetName = Read-Host -Prompt 'Input your Virtaul Network Name "VLAN" '
                                $VNetResourceGroupName = Read-Host -Prompt 'Input your Virtaul Network Resouce Group Name'
                                $SubnetName = Read-Host -Prompt 'Input your Virtaul Netwrok Subnet Name'
                                $VnetAddressPrefix = Read-Host -Prompt 'Input your Virtaul Nework Address Prefix ...... Ex: "10.0.0.0/16"'
                                $SubnetAddressPrefix = Read-Host -Prompt 'Input your VirtaulNetwrok Subnet Address Prefix ...... Ex: "10.0.0.0/24"'
                            
                                Write-Logging "The VM Name is '$VMName' and Resource Group Name is'$VMResourceGroupName' "
                                Write-Logging "The VLAN Name is '$VNetName' and VLAN Resource Group Name is'$VNetResourceGroupName' and VLAN-Subnet Name in $SubnetName "
                                # Validate VM OS Template
                                VALIDATE-OSTEMPLATETYPE
                                $VMSize =  (Get-AzureRmLocation | Where-Object {$_.DisplayName -eq $VMPARAMETER[0].LocationName} | Get-AzureRmVMSize | Out-GridView -Title "Select an VM Size ..." -PassThru)
                                $VMSize = $VMSize.Name

                                If (($VMName -ne $null) -and ($VMResourceGroupName -ne $null) -and ($VMSize -ne $null))
                                {                                  
                                    NEW-VM-CERATION -VMName $VMName -VMResourceGroupName $VMResourceGroupName -VMSize $VMSize -VNetName $VNetName -VNetResourceGroupName $VNetResourceGroupName `
                                    -SubnetName $SubnetName -VnetAddressPrefix $VnetAddressPrefix -SubnetAddressPrefix $SubnetAddressPrefix -TemplatePath $VMPARAMETER[4].TemplatePath -OSTemplateType $VMPARAMETER[3].OSType `
                                    -StorageAccountName $VMPARAMETER[0].StorageAccountName -SAContainerName $VMPARAMETER[0].SAContainerName -StorageRG $VMPARAMETER[0].StorageRG -LocationName $VMPARAMETER[0].LocationName `
                                    -VMDepModel $VMDepModel -DomainName $VMPARAMETER[2].DomainName -DomainAdminUser $VMPARAMETER[2].DomainAdminUser -DomainadminPassword $VMPARAMETER[2].DomainadminPassword -subscriptionName $subscriptionName `
                                    -VMLocalAdminUser $VMPARAMETER[5].VMLocalAdminUser -VMLocalAdminSecurePassword $VMPARAMETER[5].VMLocalAdminSecurePassword

                                }
                                Else
                                {
                                    Write-Logging "Parameter is not Set to Process the Request -> Please Set the Parameter"
                                    Through "Please Set the Parameter"
                                }
                            }

                        If($VMDeploy -eq "VMDEPLOY-EXISTINGVLAN")
                            {
                                                               
                                $VMPARAMETER = VALIDATE-OSTEMPLATETYPE
                                $VMSize =  (Get-AzureRmLocation | Where-Object {$_.DisplayName -eq $VMPARAMETER[0].LocationName} | Get-AzureRmVMSize | Out-GridView -Title "Select an VM Size ..." -PassThru)
                                $VMSize = $VMSize.Name

                                #Create VM
                                If (($VMName -ne $null) -and ($VMResourceGroupName -ne $null) -and ($VMSize -ne $null))
                                {
                                    Write-Logging "The VM Name is '$VMName' and Resource Group Name is'$VMResourceGroupName' and VM Size in $VMSize "
                                    $NewVM = NEW-VM-CREATION -VMName $VMName -VMResourceGroupName $VMResourceGroupName -VMSize $VMSize -TemplatePath $VMPARAMETER[4].TemplatePath -OSTemplateType $VMPARAMETER[3].OSType `
                                    -StorageAccountName $VMPARAMETER[0].StorageAccountName -SAContainerName $VMPARAMETER[0].SAContainerName -StorageRG $VMPARAMETER[0].StorageRG -LocationName $VMPARAMETER[0].LocationName `
                                    -VNetName $VMPARAMETER[1].VirtualNetworkName -VNetResourceGroupName $VMPARAMETER[1].VNETResourceGroup -SubnetName $VMPARAMETER[1].SubnetName -VMDepModel $VMDepModel -DomainName $VMPARAMETER[2].DomainName `
                                    -DomainAdminUser $VMPARAMETER[2].DomainAdminUser -DomainadminPassword $VMPARAMETER[2].DomainadminPassword -subscriptionName $subscriptionName -VMLocalAdminUser $VMPARAMETER[5].VMLocalAdminUser `
                                    -VMLocalAdminSecurePassword $VMPARAMETER[5].VMLocalAdminSecurePassword

                                    <#
                                    $NewVM =  .\ModuleLib\NEWVM-JOBCREATION.ps1 -SubscriptionName $subscriptionName -$AZLoginDetails $AZLoginDetails -LogFolder $LogFolder -VMName $VMName -VMResourceGroupName $VMResourceGroupName -VMSize $VMSize -TemplatePath $VMPARAMETER[4].TemplatePath 
                                    -OSTemplateType $VMPARAMETER[3].OSType -StorageAccountName $VMPARAMETER[0].StorageAccountName -SAContainerName $VMPARAMETER[0].SAContainerName -StorageRG $VMPARAMETER[0].StorageRG -LocationName $VMPARAMETER[0].LocationName `
                                    -VNetName $VMPARAMETER[1].VirtualNetworkName -VNetResourceGroupName $VMPARAMETER[1].VNETResourceGroup -SubnetName $VMPARAMETER[1].SubnetName -VMDepModel $VMDepModel -DomainName $VMPARAMETER[2].DomainName `
                                    -DomainAdminUser $VMPARAMETER[2].DomainAdminUser -DomainadminPassword $VMPARAMETER[2].DomainadminPassword -subscriptionName $subscriptionName -VMLocalAdminUser $VMPARAMETER[5].VMLocalAdminUser `
                                    -VMLocalAdminSecurePassword $VMPARAMETER[5].VMLocalAdminSecurePassword

                                    #>


                                }
                                Else
                                {
                                    Write-Logging "Parameter is not Set to Process the Request -> Please Set the Parameter"
                                    Through "Error"
                                } 
                            }
                       
                }

        }
      Catch 
        { 
                Write-Error -Message $_.Exception
                Write-Logging "Processing Machine Cration is failed $($_.Exception)"                
        }

        Write-Logging "Bye For now :)" 
        Remove-Module -Name NEW-VM-CREATION -ErrorAction SilentlyContinue
        Remove-Module -Name AZUREVMDEPLOYMODULE -ErrorAction SilentlyContinue
        Remove-Module -Name VALIDATE-OSTEMPLATETYPE -ErrorAction SilentlyContinue
        Remove-Module -name GET-STORAGE-DOMAIN-DETAILS -ErrorAction SilentlyContinue
                
  }

