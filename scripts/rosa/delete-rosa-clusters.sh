#!/bin/bash

# Description: This script retrieves cluster information in JSON format and checks for the existence
# of the "konflux-ci" tag. It then evaluates the creation date of clusters
# to determine if they are older than 4 hours and, if so, deletes the cluster including related subnet tags and load balancers.

TIME_THRESHOLD_SECONDS=${TIME_THRESHOLD_SECONDS:-172800} ## rhopp temporarily increased to 2 days due to https://issues.redhat.com/browse/OHSS-41374
MAX_RETRIES=5
LB_TAG_KEY="api.openshift.com/id"

check_env_vars() {
    if [[ -z "$ROSA_TOKEN" ]]; then
        echo "[ERROR] ROSA_TOKEN env is not exported. Exiting."
        exit 1
    fi

    if [[ -z "$AWS_DEFAULT_REGION" || -z "$AWS_ACCESS_KEY_ID" || -z "$AWS_SECRET_ACCESS_KEY" || -z "$AWS_SUBNET_IDS" ]]; then
        echo "[ERROR] Required AWS env vars are not exported. Be sure to export \$AWS_DEFAULT_REGION, \$AWS_ACCESS_KEY_ID, \$AWS_SECRET_ACCESS_KEY, \$AWS_SUBNET_IDS"
        exit 1
    fi
}

check_required_tools() {
    if ! command -v rosa &> /dev/null; then
        echo "Error: rosa command not found. Please install the rosa CLI tool."
        exit 1
    fi
    if ! command -v aws &> /dev/null; then
        echo "Error: aws command not found. Please install the aws CLI tool."
        exit 1
    fi
}

delete_cluster() {
    local cluster_id=$1

    for ((i=1; i<=MAX_RETRIES; i++)); do
        if rosa delete cluster --cluster="$cluster_id" -y; then
            echo "[SUCCESS] Cluster with id: ${cluster_id} deleted successfully."
            return 0
        else
            echo "[WARNING] Attempt $i failed to delete cluster with id: ${cluster_id}."
            if [[ $i -eq $MAX_RETRIES ]]; then
                echo "[ERROR] Failed to delete cluster with id: ${cluster_id} after $MAX_RETRIES attempts."
                return 1
            fi
            sleep 2
        fi
    done
}

delete_subnet_tags() {
    local cluster_id=$1
    local subnet_ids="${AWS_SUBNET_IDS//,/ }"

    echo "[INFO] Removing tag from subnets [$AWS_SUBNET_IDS]..."
    aws --region "$AWS_DEFAULT_REGION" ec2 delete-tags --resources $subnet_ids --tags Key="kubernetes.io/cluster/${cluster_id}"
}

delete_load_balancers() {
    local lb_tag_value=$1
    local load_balancers
    local lb_arn

    load_balancers=$(aws --region "$AWS_DEFAULT_REGION" elbv2 describe-load-balancers --query "LoadBalancers[*].LoadBalancerArn" --output text)

    for lb_arn in $load_balancers; do
        local tags
        tags=$(aws --region "$AWS_DEFAULT_REGION" elbv2 describe-tags --resource-arns "$lb_arn" --query "TagDescriptions[*].Tags[?Key=='$LB_TAG_KEY'&&Value=='$lb_tag_value'].Value" --output text)
        
        if [[ "$tags" == "$lb_tag_value" ]]; then
            echo "[INFO] Deleting ELBv2 Load Balancer with ARN: $lb_arn"
            aws --region "$AWS_DEFAULT_REGION" elbv2 delete-load-balancer --load-balancer-arn "$lb_arn"
        fi
    done
}

delete_target_groups() {
    TODAY=$(date -u -d '24 hours ago' +"%Y-%m-%dT%H:%M:%SZ")

    ALL_TARGET_GROUPS=$(aws elbv2 describe-target-groups --region "$AWS_DEFAULT_REGION" --query 'TargetGroups[*].TargetGroupArn' --output text)

    TODAYS_TARGET_GROUPS=$(aws cloudtrail lookup-events \
        --region "$AWS_DEFAULT_REGION" \
        --lookup-attributes AttributeKey=EventName,AttributeValue=CreateTargetGroup \
        --start-time "$TODAY" \
        --query 'Events[*].Resources[?ResourceType==`AWS::ElasticLoadBalancingV2::TargetGroup`].ResourceName' \
        --output text)

    TODAYS_TARGET_GROUP_ARRAY=($TODAYS_TARGET_GROUPS)

    # Loop through all target groups
    for TG_ARN in $ALL_TARGET_GROUPS; do
        # Fetch tags for the current target group
        IS_KONFLUX_CI_TAG=$(aws elbv2 describe-tags --region "$AWS_DEFAULT_REGION" --resource-arns "$TG_ARN" \
            --query "TagDescriptions[0].Tags[?Key=='konflux-ci'&&Value=='true'].Value" --output text)

        if [[ "$IS_KONFLUX_CI_TAG" == "true" ]]; then
            # Check if the target group was created today
            if [[ ! " ${TODAYS_TARGET_GROUP_ARRAY[@]} " =~ " ${TG_ARN} " ]]; then
                echo "Deleting target group: $TG_ARN (tagged 'konflux-ci=true' and not created today)"
                aws elbv2 delete-target-group --target-group-arn "$TG_ARN" --region "$AWS_DEFAULT_REGION"
            else
                echo "Skipping target group: $TG_ARN (created today)"
            fi
        else
            echo "Skipping target group: $TG_ARN (does not have the tag 'konflux-ci=true')"
        fi
    done
}

delete_old_clusters() {
    local cluster_list=$1

    echo "$cluster_list" | jq -c '.[] | select(.aws.tags."konflux-ci" != null)' | while IFS= read -r cluster; do
        local cluster_id
        local creation_date
        local creation_seconds
        local current_seconds

        cluster_id=$(echo "$cluster" | jq -r '.id')
        creation_date=$(echo "$cluster" | jq -r '.creation_timestamp')
        creation_seconds=$(date -d "$creation_date" +"%s")
        current_seconds=$(date -u +"%s")
        local diff_seconds=$((current_seconds - creation_seconds))

        if [[ "$diff_seconds" -ge "${TIME_THRESHOLD_SECONDS}" ]]; then
            echo "[INFO] Cluster with id: ${cluster_id} is older than 4 hours. Attempting to delete..."

            if delete_cluster "$cluster_id"; then
                delete_subnet_tags "$cluster_id"
                delete_load_balancers "$cluster_id"
            else
                echo "[ERROR] Cluster deletion failed for cluster id: ${cluster_id}. Skipping further steps."
            fi
        fi
    done
}

main() {
    check_env_vars
    check_required_tools
    rosa login --token="${ROSA_TOKEN}"

    delete_target_groups

    local cluster_list
    cluster_list=$(rosa list clusters --all -o json)
    if [[ -n "$cluster_list" ]]; then
        delete_old_clusters "$cluster_list"
    else
        echo "[INFO] No clusters for cleanup found."
    fi
}

main
