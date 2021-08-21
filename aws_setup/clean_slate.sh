# delete task definition & cluster
task_def=`aws ecs list-task-definitions | grep arn | sed s/\"//g | sed s/\ //g | sed s/,//g`
cluster_arn=`aws ecs list-clusters | grep arn | sed s/\"//g | sed s/\ //g`
for i in $task_def
do 
    aws ecs deregister-task-definition --task-definition $i > /dev/null
done
service_arn=`aws ecs list-services --cluster $cluster_arn | grep arn | sed s/\"//g | sed s/\ //g`
aws ecs update-service --cluster $cluster_arn --service $service_arn --desired-count 0 > /dev/null
aws ecs delete-service --cluster $cluster_arn --service $service_arn > /dev/null 

# delete ALB & Target groups
alb_arn=`aws elbv2 describe-load-balancers | grep MLServer | grep arn | awk '{print $2}' | sed s/\"//g | sed s/,//g`
aws elbv2 delete-load-balancer --load-balancer-arn $alb_arn
tg_arn=`aws elbv2 describe-target-groups | grep TargetGroupArn | awk '{print $2}' | sed s/\"//g | sed s/,//g`
aws elbv2 delete-target-group --target-group-arn $tg_arn

# delete Docker images & repo
repo_name=`aws ecr describe-repositories | grep repositoryName | awk '{print $2}' | sed s/\"//g | sed s/,//g`
aws ecr batch-delete-image \
    --repository-name $repo_name \
    --image-ids imageTag=latest > /dev/null
aws ecr delete-repository --repository-name $repo_name > /dev/null

# delete SG's
aws ec2 describe-security-groups > describe_security_group_output.json
cluster_sg=`python get_security_group_name.py --filepath describe_security_group_output.json --sg_group_name_search MLServer-FargateCluster`
aws ec2 delete-security-group --group-id $cluster_sg
alb_sg=`python get_security_group_name.py --filepath describe_security_group_output.json --sg_group_name_search MLServerALB`
aws ec2 delete-security-group --group-id $alb_sg

# delete IAM Role
iam_role=`aws iam list-roles | grep MLServer | grep RoleName | awk '{print $2}' | sed s/\"//g | sed s/,//g`
policy_arn=`aws iam list-attached-role-policies --role-name $iam_role | grep PolicyArn | awk '{print $2}' | sed s/\"//g`
aws iam detach-role-policy \
    --role-name $iam_role \
    --policy-arn $policy_arn
aws iam delete-role --role-name $iam_role

# re-associated subnets with default network ACL & delete Network ACL
aws ec2 describe-network-acls > describe_network_acl_output.json
nacl_id=`python -c 'import json;obj=json.load(open("describe_network_acl_output.json", "r"));[print( i["NetworkAclId"] ) for i in obj["NetworkAcls"] if i["IsDefault"] == False]'`
default_nacl_id=`python -c 'import json;obj=json.load(open("describe_network_acl_output.json", "r"));[print( i["NetworkAclId"] ) for i in obj["NetworkAcls"] if i["IsDefault"] == True]'`
subnet_1_id=`aws ec2 describe-network-acls --network-acl-id $nacl_id | grep SubnetId | awk '{print $2}' | sed s/\"//g | head -1`
subnet_2_id=`aws ec2 describe-network-acls --network-acl-id $nacl_id | grep SubnetId | awk '{print $2}' | sed s/\"//g | head -2 | tail -1`
declare -a subnets=($subnet_1_id $subnet_2_id)
for i in "${subnets[@]}"
do 
    nacl_association_id=`aws ec2 describe-network-acls \
        | grep $i -B 2 \
        | grep NetworkAclAssociationId \
        | awk '{print $2}' \
        | sed s/\"//g | sed s/,//g`
    aws ec2 replace-network-acl-association \
        --association-id $nacl_association_id \
        --network-acl-id $default_nacl_id > /dev/null
done
aws ec2 delete-network-acl \
    --network-acl-id $nacl_id

# detach & delete IGW
igw_ids=`aws ec2 describe-internet-gateways | grep InternetGatewayId | awk '{print $2}' | sed s/\"//g | sed s/,//g`
vpc_id=`aws ec2 describe-internet-gateways | grep VpcId | awk '{print $2}' | sed s/\"//g`
for i in $igw_ids
do 
    aws ec2 detach-internet-gateway \
        --internet-gateway-id $i \
        --vpc-id $vpc_id > /dev/null
    aws ec2 delete-internet-gateway \
        --internet-gateway-id $i > /dev/null
done

# delete route tables that are associated with 'blackhole' IGW
aws ec2 describe-route-tables > describe_route_tables_output.json
rtb_ids=`python get_route_table_id.py --filepath describe_route_tables_output.json`
for i in $rtb_ids
do
    association_ids=`cat describe_route_tables_output.json | grep $i -B 2 | grep RouteTableAssociationId | awk '{print $2}' | sed s/\"//g | sed s/,//g`
    for j in $association_ids
    do
        aws ec2 disassociate-route-table --association-id $j
    done
    aws ec2 delete-route-table --route-table-id $i
done

aws ecs delete-cluster --cluster $cluster_arn > /dev/null

echo 'Deleting unnecessary files...'
files_to_remove=`ls | grep output`
rm $files_to_remove
