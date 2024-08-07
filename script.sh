#!/usr/bin/env bash

source log.sh


argocd_apps_yaml_filepath="$1"
argocd_projects_yaml_filepath="$2"
export TMPDIR=$(mktemp -d)
export TMPDIR_INSTANCE="$TMPDIR/$ARGO_INSTANCE_FOLDER_NAME"
export TMPDIR_INSTANCE_PROJECTS="$TMPDIR_INSTANCE/_projects"
mkdir -p "$TMPDIR_INSTANCE"
mkdir -p "$TMPDIR_INSTANCE_PROJECTS"

# export TMPDIR_INSTANCE="."
log_info "created temp directory: $TMPDIR"


#### -------- Do the Cluster Root Argo App --------- #### 


log_info "argocd_apps_yaml_filepath: $(wc -l $argocd_apps_yaml_filepath)"
neat_argocd_apps_filepath="${TMPDIR_INSTANCE}/neat.yaml"  # TODO: mktmpdir_INSTANCE

# remove unnecessary data (like .status)
kubectl neat -f "$argocd_apps_yaml_filepath" > "$neat_argocd_apps_filepath"
log_info "neat_argocd_apps_filepath: $(wc -l $neat_argocd_apps_filepath)"



multidoc_argocd_apps_filepath="$TMPDIR_INSTANCE/multidoc.yaml"
yq '.items[] | split_doc'  "$neat_argocd_apps_filepath" > "$multidoc_argocd_apps_filepath"


export dir_apps_with_server="$TMPDIR_INSTANCE/_server_destined_apps"
export dir_apps_with_name="$TMPDIR_INSTANCE/_name_destined_apps"
mkdir -p "$dir_apps_with_server"
mkdir -p "$dir_apps_with_name"



# .destination.server -> put into separate directory
yq -s 'select(.spec.destination.server) | env(dir_apps_with_server) + "/" + .metadata.name' "$multidoc_argocd_apps_filepath" > /dev/null

# .destination.name -> we need
yq -s 'select(.spec.destination.name) | env(dir_apps_with_name) + "/" + .metadata.name' "$multidoc_argocd_apps_filepath"  > /dev/null


for filepath in "$dir_apps_with_name"/*; do
    if [ -f "$filepath" ]; then
        cluster_name=$(yq '.spec.destination.name' "$filepath") 
        mkdir -p "$TMPDIR_INSTANCE/$cluster_name/apps"
        mv "$filepath" "$TMPDIR_INSTANCE/$cluster_name/apps"
        # log_info "$cluster_name/ app is designated to cluster: $cluster_name"
        cur_app_root_yaml_filepath="$TMPDIR_INSTANCE/$cluster_name/clusterRootArgoApp.yaml"
        cp templates/clusterRootArgoApp.yaml "$cur_app_root_yaml_filepath"
        # patch cur_app_root_yaml_filepath with yq
        export CLUSTER_ROOT_APP_NAME="root-$cluster_name"
        yq --inplace ".metadata.name = env(CLUSTER_ROOT_APP_NAME)" "$cur_app_root_yaml_filepath"
        yq --inplace ".metadata.namespace = env(CLUSTER_ROOT_APP_NAMESPACE)" "$cur_app_root_yaml_filepath"
        yq --inplace ".spec.project = env(CLUSTER_ROOT_APP_PROJECT)" "$cur_app_root_yaml_filepath"
        yq --inplace ".spec.source.repoURL = env(REPO_URL)" "$cur_app_root_yaml_filepath"
        
        export CLUSTER_ROOT_APP_PATH="$ARGO_INSTANCE_FOLDER_NAME/$cluster_name/apps"
        yq --inplace ".spec.source.path = env(CLUSTER_ROOT_APP_PATH)" "$cur_app_root_yaml_filepath"

        yq --inplace ".spec.destination.name = env(CLUSTER_ROOT_APP_DESTINATION_CLUSTER_NAME)" "$cur_app_root_yaml_filepath"
        yq --inplace ".spec.destination.namespace = env(CLUSTER_ROOT_APP_DESTINATION_NAMESPACE)" "$cur_app_root_yaml_filepath"
    fi
done

#### -------- Do the Argo Instance Root App --------- #### 

# Copy and patch the ArgoInstanceRootofRootApp
argo_instance_root_app_filepath="$TMPDIR_INSTANCE/argoInstanceRootApp.yaml"
cp templates/argoInstanceRootApp.yaml "$argo_instance_root_app_filepath"


export ARGO_INSTANCE_APP_NAME="root-of-root-$ARGO_INSTANCE_FOLDER_NAME-instance"
yq --inplace ".metadata.name = env(ARGO_INSTANCE_APP_NAME)" "$argo_instance_root_app_filepath"
yq --inplace ".metadata.namespace = env(CLUSTER_ROOT_APP_NAMESPACE)" "$argo_instance_root_app_filepath"
yq --inplace ".spec.project = env(CLUSTER_ROOT_APP_PROJECT)" "$argo_instance_root_app_filepath"
yq --inplace ".spec.source.repoURL = env(REPO_URL)" "$argo_instance_root_app_filepath"
yq --inplace ".spec.destination.name = env(CLUSTER_ROOT_APP_DESTINATION_CLUSTER_NAME)" "$argo_instance_root_app_filepath"
yq --inplace ".spec.destination.namespace = env(CLUSTER_ROOT_APP_DESTINATION_NAMESPACE)" "$argo_instance_root_app_filepath"

export ARGO_INSTANCE_ROOT_PATH="${ARGO_INSTANCE_FOLDER_NAME}/"
yq --inplace ".spec.source.path = env(ARGO_INSTANCE_ROOT_PATH)" "$argo_instance_root_app_filepath"

#### -------- Do the Argo Projects --------- #### 

log_info "argocd_projects_yaml_filepath: $(wc -l $argocd_projects_yaml_filepath)"

neat_argocd_projects_filepath="$TMPDIR_INSTANCE/projects-neat.yaml"
kubectl neat -f "$argocd_projects_yaml_filepath" > "$neat_argocd_projects_filepath"
multidoc_argocd_projects_filepath="$TMPDIR_INSTANCE/projects-multidoc.yaml"
yq '.items[] | split_doc'  "$neat_argocd_projects_filepath" > "$multidoc_argocd_projects_filepath"

# split the files
yq -s 'env(TMPDIR_INSTANCE_PROJECTS) + "/" + .metadata.name' "$multidoc_argocd_projects_filepath"  > /dev/null

# # --- Clean Up ---
rm -r "$dir_apps_with_name"
rm -r "$neat_argocd_apps_filepath"
rm -r "$multidoc_argocd_apps_filepath"
rm -r "$neat_argocd_projects_filepath"
rm -r "$multidoc_argocd_projects_filepath"