# delete ALB & Target groups
alb_arn=`aws elbv2 describe-load-balancers | grep MLServer | grep arn | awk '{print $2}' | sed s/\"//g | sed s/,//g`
aws elbv2 delete-load-balancer --load-balancer-arn $alb_arn
tg_arn=`aws elbv2 describe-target-groups | grep TargetGroupArn | awk '{print $2}' | sed s/\"//g | sed s/,//g`
aws elbv2 delete-target-group --target-group-arn $tg_arn

# detach & delete IGW
igw_id=`aws ec2 describe-internet-gateways | grep InternetGatewayId | awk '{print $2}' | sed s/\"//g | sed s/,//g`
vpc_id=`aws ec2 describe-internet-gateways | grep VpcId | awk '{print $2}' | sed s/\"//g`
aws ec2 detach-internet-gateway \
    --internet-gateway-id $igw_id \
    --vpc-id $vpc_id > /dev/null
aws ec2 delete-internet-gateway \
    --internet-gateway-id $igw_id > /dev/null

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

# delete route tables that are associated with 'blackhole' IGW
aws ec2 describe-route-tables > describe_route_tables_output.json
rtb_id=`python get_route_table_id.py --filepath describe_route_tables_output.json`
association_ids=`cat describe_route_tables_output.json | grep $rtb_id -B 2 | grep RouteTableAssociationId | awk '{print $2}' | sed s/\"//g | sed s/,//g`
for i in $association_ids
do 
    aws ec2 disassociate-route-table --association-id $i
done
aws ec2 delete-route-table --route-table-id $rtb_id

# delete task definition & cluster
task_def=`aws ecs list-task-definitions | grep arn | sed s/\"//g | sed s/\ //g | sed s/,//g`
cluster_arn=`aws ecs list-clusters | grep arn | sed s/\"//g | sed s/\ //g`
echo $task_def
for i in $task_def
do 
    aws ecs deregister-task-definition --task-definition $i > /dev/null
done
aws ecs delete-cluster --cluster $cluster_arn > /dev/null
