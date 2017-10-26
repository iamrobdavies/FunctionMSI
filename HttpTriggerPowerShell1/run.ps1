# Variables
$requestBody = Get-Content $req -Raw | ConvertFrom-Json
$tenantId = $requestBody.tenantId
$appDisplayName = $requestBody.appName
$subscriptionId = $requestBody.subscriptionid

# Get Managed Service Identity info from Azure Functions Application Settings
$msiEndpoint = $env:MSI_ENDPOINT
$msiSecret = $env:MSI_SECRET

# Specify URI and Token AuthN Request Parameters
$apiVersion = "2017-09-01"
$resourceURI = "https://graph.windows.net"
$tokenAuthURI = $msiEndpoint + "?resource=$resourceURI&api-version=$apiVersion"

# Authenticate with MSI and get Token
$tokenResponse = Invoke-RestMethod -Method Get -Headers @{"Secret"="$msiSecret"} -Uri $tokenAuthURI

# This response should give us a Bearer Token for later use in Graph API calls
$accessToken = $tokenResponse.access_token

# Create Azure AD Application
$appURI = "https://graph.windows.net/{0}/applications?api-version=1.6" -f $tenantId 
$appBody = @{
        availableToOtherTenants = 'false'
        displayName = $appDisplayName
        homepage = "https://localhost/"
        identifierUris = "https://$($appDisplayName)/", "http://$($appDisplayName)/"
}
$appJsonBody = $appBody | ConvertTo-Json
$appInvoke = Invoke-RestMethod -Method POST -Body $appJsonBody -Uri $appURI -Headers @{"Authorization"="Bearer $accessToken"} -ContentType 'application/json'

#new Application AppId
$appId = $appInvoke.appId

# Create Service Principal for Application
$spnURI = "https://graph.windows.net/{0}/servicePrincipals?api-version=1.6" -f $tenantId 

$spnBody = @{
        accountEnabled = 'true'
        appId = $appId
}
$spnJsonBody = $spnBody | ConvertTo-Json
$spnInvoke = Invoke-RestMethod -Method POST -Body $spnJsonBody -Uri $spnURI -Headers @{"Authorization"="Bearer $accessToken"} -ContentType 'application/json'

# Specify URI and Token AuthN Request Parameters
$apiVersion = "2017-09-01"
$resourceURI = "https://management.azure.com/"
$tokenAuthURI = $msiEndpoint + "?resource=$resourceURI&api-version=$apiVersion"
# Authenticate with MSI and get Token
$tokenResponse = Invoke-RestMethod -Method Get -Headers @{"Secret"="$msiSecret"} -Uri $tokenAuthURI
# This response should give us a Bearer Token for later use in Graph API calls
$accessToken = $tokenResponse.access_token

$g = ([guid]::NewGuid()).Guid
$roleBody = @{
        properties = @{
            roleDefinitionId = "/subscriptions/{0}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c" -f $subscriptionId
            principalId = $spnInvoke.objectId
        }
}
$roleBodyJson = $roleBody | ConvertTo-Json
Start-Sleep -s 30
$roleURI = "https://management.azure.com/subscriptions/{0}/providers/Microsoft.Authorization/roleAssignments/{1}?api-version=2015-07-01" -f $subscriptionId, $g
Invoke-RestMethod -Method PUT -Body $roleBodyJson -Uri $roleURI -Headers @{"Authorization"="Bearer $accessToken"} -ContentType 'application/json'

Out-File -Encoding Ascii -FilePath $res -inputObject $appId
