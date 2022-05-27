# Azure Arc enabled servers のデプロイ

Azure Arcに関する基本事項は [こちら](https://docs.microsoft.com/en-us/azure/azure-arc/servers/overview) を参照してください。ここでは詳細省略します。

## シナリオ

ここでは、まず第一段階として、AWS、GCP上にデプロイした、Windows / Linux VMを、まずは Azure Portal上で確認する超基本シナリオを検証してみます。

以下を参考にしながら勧めていきます。

https://docs.microsoft.com/ja-jp/azure/cloud-adoption-framework/manage/hybrid/server/best-practices/gcp-terraform-ubuntu
https://docs.microsoft.com/ja-jp/azure/cloud-adoption-framework/manage/hybrid/server/best-practices/aws-terraform-ubuntu?toc=%2Fazure%2Fcloud-adoption-framework%2Fscenarios%2Fhybrid%2Ftoc.json


## ポイント

TerraformでVMをデプロイするという処理は特にArcとは関係なく日常的に利用される部分かと思います。Azure Arcに固有な部分は、VMにエージェントを導入してAzureリソースとして登録する部分です。この部分について内容を確認したいと思います。

GCPのmain.tfを見てみると、以下の箇所があります。これは、Azure Arcのエージェントを導入するためのシェルスクリプトのテンプレートファイルですね。これに、リソースグループとリージョン情報を渡してインスタンス化しています。

```terraform
resource "local_file" "install_arc_agent_sh" {
  content = templatefile("scripts/install_arc_agent.sh.tmpl", {
    resourceGroup = var.azure_resource_group
    location      = var.azure_location
    }
  )
  filename = "scripts/install_arc_agent.sh"
}
```

次に、[File provisioner](https://www.terraform.io/language/resources/provisioners/file#file-provisioner) を利用して以下の2つのファイルをリモートマシンにprovisionしています。環境変数の設定と、エージェント導入のスクリプトです。

```terraform
provisioner "file" {
    source      = "scripts/vars.sh"
    destination = "/tmp/vars.sh"

    connection {
      type        = "ssh"
      host        = google_compute_instance.ubuntu.network_interface.0.access_config.0.nat_ip
      user        = var.admin_username
      private_key = file("~/.ssh/id_rsa")
      timeout     = "2m"
    }
  }
  provisioner "file" {
    source      = "scripts/install_arc_agent.sh"
    destination = "/tmp/install_arc_agent.sh"

    connection {
      type        = "ssh"
      host        = google_compute_instance.ubuntu.network_interface.0.access_config.0.nat_ip
      user        = var.admin_username
      private_key = file("~/.ssh/id_rsa")
      timeout     = "2m"
    }
  }
```

エージェント導入のスクリプトの中身を確認してみると、[azcmagent](https://docs.microsoft.com/ja-jp/azure/azure-arc/servers/manage-agent) のコマンドで導入を行っているの側わかります。

```sh
# Run connect command
sudo azcmagent connect \
  --service-principal-id $TF_VAR_client_id \
  --service-principal-secret $TF_VAR_client_secret \
  --tenant-id $TF_VAR_tenant_id \
  --subscription-id $TF_VAR_subscription_id \
  --location "japaneast" \
  --resource-group "rg-arcdemo" \
  --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"
```


そして、[remote-exec Provisioner](https://www.terraform.io/language/resources/provisioners/remote-exec#remote-exec-provisioner) を利用してファイルをリモートのVMで実行する、という流れになっています。

```terraform
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get install -y python-ctypes",
      "sudo chmod +x /tmp/install_arc_agent.sh",
      "/tmp/install_arc_agent.sh",
    ]

    connection {
      type        = "ssh"
      host        = google_compute_instance.ubuntu.network_interface.0.access_config.0.nat_ip
      user        = var.admin_username
      private_key = file("~/.ssh/id_rsa")
      timeout     = "2m"
    }
  }
```

## 前提条件

まずは、AWS、GCP それぞれにTerraformを使用してVMをデプロイします。
以下が用意されている事を前提とします。

* Azure CLI 2.25~ の導入

    ```sh
    az --version
    ```

* [SSHキーの用意](https://docs.github.com/ja/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)
* [GCPのアカウント](https://cloud.google.com/free)
* [AWSのアカウント](https://aws.amazon.com/jp/premiumsupport/knowledge-center/create-and-activate-aws-account/)
* [Terraformの導入](https://learn.hashicorp.com/tutorials/terraform/install-cli)
* [https://docs.microsoft.com/ja-jp/cli/azure/ad/sp?view=azure-cli-latest#az-ad-sp-create-for-rbacリソース管理用のサービスプリンシパル](https://docs.microsoft.com/ja-jp/cli/azure/ad/sp?view=azure-cli-latest#az-ad-sp-create-for-rbac)
  
もし、Values of identifierUris property must use a verified domain of the organization or its subdomain: の様なエラーが出た場合、[こちら](https://jpazureid.github.io/blog/azure-active-directory/aad-changes-impacting-azurecli-azureps/)参照ください。

## GCPでの作業

### プロジェクトを作成

予めGCPログインしてプロジェクトを作成しておきます。
今回は、Azure Arc という名前で作成しました。割り振られたプロジェクトIDをメモしておきます。

<img src="images\GCPProjectCreated.png" width="30%">

併せて、Compute Engine API を有効化しておきます。

<img src="images\enablecomputeapi.png" width="30%">

### サービスアカウントキーを作成

次に、TerraformからGCPのプロジェクトのリソースを作成・管理するために使用するサービスアカウントキーを作成します。

<img src="images\createGCPServiceAccount.png" width="30%">

名前を指定してから、プロジェクト、ロールとしての所有者、キーの種類を指定して、JSON形式で出力します。
出力されたjsonファイルは、servers/gcp/ubuntu+windows/terraform に配置しておきます。

### GCPにArc enabled のVMをデプロイ

#### 環境変数の設定

servers/gcp/vm/scripts の下の vars.sh ファイルを編集します。
スクリプトは、Terraform プラン実行時に、Azure、GCPそれぞれに接続する際に必要となる情報を環境変数に設定するスクリプトです。
/servers/gcp/vm にて以下のコマンドを実行して環境変数をセットします。

```sh
source ./scripts/vars.sh
```

#### Terraformでデプロイ

Terraform init を実行して、バックエンド、プラグインの初期化を行います。

```sh
terraform init

Initializing the backend...

Initializing provider plugins...
- Reusing previous version of hashicorp/google from the dependency lock file
- Reusing previous version of hashicorp/local from the dependency lock file
- Reusing previous version of hashicorp/azurerm from the dependency lock file
- Using previously-installed hashicorp/google v3.90.1
- Using previously-installed hashicorp/local v1.4.0
- Using previously-installed hashicorp/azurerm v2.9.0

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

terraform apply --auto-approve を実行して、プランの実行完了を待ちます。完了すると、GCP上に2つのVMが作成されている筈です。

```sh
~略~
sources: 5 added, 0 changed, 0 destroyed.

Outputs:

ip_ubuntu = "34.168.111.AAA"
ip_windows = "35.233.179.BBB"
```

GCPコンソールからも確認できます。

<img src="images\ArcServersonGCP.png" width="70%">

Azure Portalにも反映されてます。

<img src="images\GCPserversonAzurePortal.png" width="70%">

## AWSでの作業

では、次にAWSにVMを構築します。awsでは都合によりubuntu 1VMのみ作成します。

### IAMロールを作成

GCPの場合と同様に、Terraformからリソースの操作を行うためのシステムユーザーを作成します。
[こちらの手順](https://docs.microsoft.com/ja-jp/azure/cloud-adoption-framework/manage/hybrid/server/best-practices/aws-terraform-ubuntu?toc=%2Fazure%2Fcloud-adoption-framework%2Fscenarios%2Fhybrid%2Ftoc.json#create-an-aws-identity)を参考に、生成されたアクセス キー ID とシークレット アクセス キーを記録しておきます。

### GCPにArc enabled のVMをデプロイ

#### 環境変数の設定

GCP と同様に、servers/aws/vm/scripts の下の vars.sh ファイルを編集します。
/servers/aws/vm にて、以下のコマンドを実行して環境変数をセットします。

```sh
source ./scripts/vars.sh
```

#### Terraformでデプロイ

/servers/aws/terraformディレクトリ下でTerraform init を実行して、バックエンド、プラグインの初期化を行います。

```sh
terraform init
```

terraform apply --auto-approve を実行して、プランの実行完了を待ちます。完了すると、AWS上にVMが作成されます。
 
<img src="images\ArcServersonAWS.png" width="70%">

Azure Portal上にも作成されました。
 
<img src="images\ArcServersonAzurePortal.png" width="70%">
