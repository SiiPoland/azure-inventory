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
Invoke-WebRequest -Uri https://raw.githubusercontent.com/SiiPoland/azure-inventory/refs/heads/master/Export-AzureResources.ps1 -OutFile 'Export-AzureResources.ps1'
```

4. Run script

```powershell
./Export-AzureResources.ps1
```

Additional parameters:
```powershell
   -SubscriptionId     - create report only for selected Subscription
   -SubscriptionLimit  - limit number of subscriptions in report
   -with_Tags (switch) - include tags in report
   -DebugMode (switch) - show debug information
   -Continue (switch)  - continue processing if error occurs, all processed subscriptions will be saved in directory `./.tmpdir

   For example:
   ./Export-AzureResources.ps1 -SubscriptionId '00000000-0000-0000-0000-000000000000' -with_Tags -Continue
```

5. Download your report in CSV format. You will found it on your Storage Account in File Share. Details about them will be reported.


