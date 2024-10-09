# Get-AzureResourceList
Get-AzureResourceList

Short manual how to grab Resource Data from Subscription - online version

1. Open PowerShell for your subscription.
   Easiest way is to open https://shell.azure.com website.
   
   **Remember to choose PowerShell version instead of Cli**

2. Go to Home Directory

```powershell
cd $HOME_DIR
```

3. Invoke download script from github and save it locally

```powershell
Invoke-WebRequest -Uri https://raw.githubusercontent.com/SiiPoland/azure-inventory/refs/heads/master/Get-AzureResourcesList.ps1 -OutFile 'Get-AzureResourceList.ps1'
```

4. Run script

```powershell
./Get-AzureResourceList.ps1
```

Additional parameters:
```powershell
   -s (--SubscriptionId) - create report only for selected Subscription
   -wt (--with_Tags) - include tags in report
   -sl (--SubscriptionLimit) - limit number of subscriptions in report
   -Debug - show debug information
```

5. Download your report in CSV format. You will found it on your Storage Account in File Share. Details about them will be reported.


