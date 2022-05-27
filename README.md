# tryAzureArc

Azure Arc の検証ログを記録していきます。

Azure Arc は、Azure 外部のリソースをAzureのリソースとして管理できるようにするもの。
2022/05では、以下のリソースが管理対象

* **Servers**: Manage Windows and Linux physical servers and virtual machines hosted outside of Azure.
* **Kubernetes clusters**: Attach and configure Kubernetes clusters running anywhere, with multiple supported distributions.
* **Azure data services**: Run Azure data services on-premises, at the edge, and in public clouds using Kubernetes and the infrastructure of your choice. SQL Managed Instance and PostgreSQL Hyperscale (preview) services are currently available.
* **SQL Server**: Extend Azure services to SQL Server instances hosted outside of Azure.
* **Virtual machines (preview)**: Provision, resize, delete and manage virtual machines based on VMware vSphere or Azure Stack HCI and enable VM self-service through role-based access.

[Azure Arc のドキュメント](https://docs.microsoft.com/ja-jp/azure/azure-arc/overview)

各リソース毎に検証していきたい。

## Azure Arc enabled Servers

まずは基本のservers、[こちら](./servers/README.md) に。


## Azure Arc enabled Services