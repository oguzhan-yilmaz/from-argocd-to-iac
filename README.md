# from-argocd-to-iac


```bash
export ARGO_INSTANCE_FOLDER_NAME="argo-prod"

export REPO_URL=""
export CLUSTER_ROOT_APP_PROJECT="default"
export CLUSTER_ROOT_APP_NAMESPACE="openshift-gitops"

export CLUSTER_ROOT_APP_DESTINATION_CLUSTER_NAME="in-cluster"
export CLUSTER_ROOT_APP_DESTINATION_NAMESPACE="openshift-gitops"

bash script.sh _data/openshift-prod-cluster.yaml _data/openshift-prod-projects.yaml


```
