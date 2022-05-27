

## プライベートキーをダウンロードしてフォルダに配置します。
## その他のパラメータは Developer コンソールより値を取得して記載してください

$PrivKeyPath = '.\private_2022012345678.key'
$ClientId = 'gRqxxxxxxxxxxxx'
$ClientSecret = 'Tqexxxxxxxx'
$SvcAccount = 'xxxxx.serviceaccount@yourcompanygroupname'


### 入力ファイル を指定します。
$groupMembershipDiffFile = ".\GroupMembershipDiff.csv"

### 出力ファイル を指定します。
$originalGroupInfo = ".\originalGroup.log"
$updateMembershipInfo = ".\updateMembership.log"
$newGroupInfo = ".\newGroup.log"


$csv = import-csv $groupMembershipDiffFile
$global:userIds = @{}
$global:getuserIdSleep = 0
$global:getGroupSleep = 0
$global:patchGroupSleep = 0


Import-Module powershell-jwt

$rsaPrivateKey = Get-Content $PrivKeyPath -AsByteStream

$iat = [int](Get-Date -UFormat %s)
$exp = $iat + 3600

$payload = @{
    sub = $SvcAccount
    iat = $iat
}

$jwt = New-JWT -Algorithm 'RS256' -SecretKey $rsaPrivateKey -PayloadClaims $payload -ExpiryTimestamp $exp -Issuer $ClientId

$requestHeader = @{
    'Content-Type' = 'application/x-www-form-urlencoded'
}

$requestBody = @{
    assertion     = $jwt
    grant_type    = 'urn:ietf:params:oauth:grant-type:jwt-bearer'
    client_id     = $ClientId
    client_secret = $ClientSecret
    scope         = 'user.read,group'
}

$url = 'https://auth.worksmobile.com/oauth2/v2.0/token'
$response = Invoke-RestMethod -Uri $url -Method POST -Headers $requestHeader -Body $requestBody

$header = @{
    Authorization  = "Bearer " + $response.access_token
    'Content-Type' = 'application/json'
    Accept         = 'application/json'
}

function Get-UserId($userId) {
    if (! $global:userIds.ContainsKey($userId)) {

        $urlEncodedUserId = [System.Web.HttpUtility]::UrlEncode($userId)
        $getUserAPI = "https://www.worksapis.com/v1.0/users/$urlEncodedUserId"

        start-sleep $global:getuserIdSleep
        $response = Invoke-WebRequest -Method GET -Uri $getUserAPI -Headers $Header 

        if ([int]$response.Headers["RateLimit-Remaining"][0] -eq 0) {
            $global:getuserIdSleep = [int]$response.Headers["RateLimit-Reset"][0] + 1
        }
        else {
            $global:getuserIdSleep = [int]0
        }

        $response = $response.Content | convertfrom-json
        $global:userIds[$userId] = $response.userId
    }
    return $global:userIds[$userId] 
}

function Get-Group($groupId) {
    $urlEncodedGroupId = [System.Web.HttpUtility]::UrlEncode($groupId)
    $getGrouAPI = "https://www.worksapis.com/v1.0/groups/$urlEncodedGroupId"

    start-sleep $global:getGroupSleep
    $response = Invoke-WebRequest -Method GET -Uri $getGrouAPI -Headers $Header
    $responseObj = $response.content | Convertfrom-Json
    if (![String]::isnullorempty($originalGroupInfo)) {
        $logMsg = (Get-Date  -Format G) + "  GroupId : " + $groupId + "`r`n" + ($responseObj | convertTo-Json) + "`r`n----------`r`n"
        Add-Content $originalGroupInfo $logMsg
    }

    if ([int]$response.Headers["RateLimit-Remaining"][0] -eq 0) {
        $global:getGroupSleep = [int]$response.Headers["RateLimit-Reset"][0] + 1
    }
    else {
        $global:getGroupSleep = [int]0
    }

    $responseObj = $response.content | Convertfrom-Json
    return $responseObj
}

function Patch-Group($groupId, $Members) {

    $urlEncodedGroupId = [System.Web.HttpUtility]::UrlEncode($groupId)
    $patchGrouAPI = "https://www.worksapis.com/v1.0/groups/$urlEncodedGroupId"

    $group = @{}
    foreach ($member in $Members) {
        $group.members += @($member)
    }
    $requestJson = $group | convertto-json 
    if (![String]::isnullorempty($updateMembershipInfo)) {
        $logMsg = (Get-Date  -Format G) + "  GroupId : " + $groupId + "`r`n" + $requestJson + "`r`n----------`r`n"
        Add-Content $updateMembershipInfo $logMsg
    }

    start-sleep $global:patchGroupSleep
    $response = invoke-WebRequest -Method PATCH -Uri $patchGrouAPI -Headers $Header -body $requestJson

    if (![String]::isnullorempty($newGroupInfo)) {
        $logMsg = (Get-Date  -Format G) + "  GroupId : " + $groupId + "`r`n" + ($response.content | convertfrom-json | convertto-json ) + "`r`n----------`r`n"
        Add-Content $newGroupInfo $logMsg
    }

    if ([int]$response.Headers["RateLimit-Remaining"][0] -eq 0) {
        $global:patchGroupSleep = [int]$response.Headers["RateLimit-Reset"][0] + 1
    }
    else {
        $global:patchGroupSleep = [int]0
    }
}

$allGroupIds = $csv | select groupid -Unique

foreach ($groupId in $allGroupIds.groupid) {

    $Group = Get-Group($groupId)
    $members = $group.members

    $addMembers = $csv | ? { (($_.operation -eq "ADD") -and ($_.groupid -eq $groupId)) } | select userid
    $removeMembers = $csv | ? { (($_.operation -eq "REMOVE") -and ($_.groupid -eq $groupId)) } | select userid

    ## User 追加
    foreach ($userId in $addMembers.userid) {
        $userGuid = get-userid($userId)
        if ($userGuid -notin $members.id) {
            $members += @(@{id = $userGuid; type = "USER" })
        }
    }

    ## User 削除
    $removeuserIds = @()
    foreach ($userId in $removeMembers.userid) {
        $removeuserIds += get-userId( $userId)
    }
    $members = $members | ? { $_.id -notin $removeuserIds }

    ## メンバシップ変更適用
    if ($members.count -eq 0) {
        write-host "empty group membership is not allowed"
    }
    else {
        Patch-Group $groupId $members
    }
}
