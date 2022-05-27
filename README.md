# Maintain-LWGroupMembership

### 環境準備
[Import-LWUsers](https://github.com/msato-3/Import-LWUsers/) では、CSV ファイルに記載されたユーザー情報をもとに、LINE WORKS にユーザーを作成するスクリプトを書きました。  
今回は、LINE WORKS グループのメンバーシップをメンテナンスするスクリプトを書いてみました。


ユーザー情報を取得し、グループのメンバーシップ情報を変更するため、アプリの OAuth Scope に `user.read` と `group` が必要になります。
[Import-LWUsers / 1.1. アプリの作成](https://github.com/msato-3/Import-LWUsers#11-%E3%82%A2%E3%83%97%E3%83%AA%E3%81%AE%E4%BD%9C%E6%88%90) で作成したアプリの OAuth Scope を変更するか、`user.read` と `group` を割り当てた新しいアプリを作成します。


また、[Import-LWUsers / 1.2. External Key の指定](https://github.com/msato-3/Import-LWUsers#12-external-key-%E3%81%AE%E6%8C%87%E5%AE%9A) を参考に、グループにも externalKey を割り当てておきます。


スクリプトをダウンロードしたら、[Import-LWUser / 2.2. スクリプトの変更](https://github.com/msato-3/Import-LWUsers#22-%E3%82%B9%E3%82%AF%E3%83%AA%E3%83%97%E3%83%88%E3%81%AE%E5%A4%89%E6%9B%B4) と同様に、お使いの環境にあわせて以下を変更します。
```
$PrivKeyPath = '.\private_2022012345678.key'
$ClientId = 'gRqxxxxxxxxxxxx'
$ClientSecret = 'Tqexxxxxxxx'
$SvcAccount = 'xxxxx.serviceaccount@yourcompanygroupname'
```

入力ファイルと
```
### 入力ファイル を指定します。
$groupMembershipDiffFile = ".\GroupMembershipDiff.csv"
```
出力ファイルを指定します。出力ファイルは、不要であればコメントアウトしてください。
```
### 出力ファイル を指定します。
$originalGroupInfo = ".\originalGroup.log"
$updateMembershipInfo = ".\updateMembership.log"
$newGroupInfo = ".\newGroup.log"
```

黒い PowerShell で、[powershell-jwt](https://github.com/Nucleware/powershell-jwt) もインストールしておきます。

### グループ メンバーシップ情報の準備
グループのメンバーシップ情報を新しく指定するのではなく、グループの現在のメンバーシップ情報に対して、ユーザーを追加または削除します。
ユーザー (`email`、`userId` または `externalKey:{externalKey}` )、グループ(`externalKey:{externalKey}` または `resourceId` )、操作 (追加 `ADD` または削除 `REMOVE` ) を、1 行ずつ書いていきます。

|列名|内容|サンプル|
|-|-|-|
|userid| 変更したいユーザーの id <br> `email`、`userId` または `externalKey:{KeyValue}` | user@yourcompany|
|groupid| 変更先のグループ <br> `externalKey:{keyValue}` または `resourceId` |externalKey:groupKeyValue|
|operation| 追加 `ADD` または削除 `REMOVE` | ADD

>groupId としては `externalKey:{KeyValue}` または `resourceId (uuid)` が、userId としては `email`、 `userId (uuid)`、または `externalKey:{keyValue}` が利用できます。  
>userId として exterrnalKey を利用する場合には、Developer コンソールから externalKey を割り当てます。  
>組み合わせて使用することは可能ですが、同じ差分情報ファイルの中では、ユーザー、グループそれぞれに対しては同じ種類の値を使用することをおすすめします。(ユーザーの指定には email のみを、グループの指定には externalkey:{keyValue} のみを使用するなど)  
