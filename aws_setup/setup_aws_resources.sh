################################################################################
# Configure Networking & Setup ALB
################################################################################
# create & attach IGW to VPC to allow public access
echo 'Creating IGW and attaching to VPC...'
igw_id=`aws ec2 create-internet-gateway | grep InternetGatewayId | sed s/^.*\://g | sed s/\"//g | sed s/,//g`
vpc_id=`aws ec2 describe-vpcs | grep VpcId | sed s/^.*\://g | sed s/\"//g | sed s/,//g`
aws ec2 attach-internet-gateway \
    --vpc-id $vpc_id \
    --internet-gateway-id $igw_id

# all outgoing public destined traffic goes through IGW
echo 'Routing all public internet bound traffic to flow through IGW...'
route_table_id=`aws ec2 create-route-table --vpc-id $vpc_id | grep RouteTableId | awk '{print $2}' | awk 'gsub("\"", "", $1)' | awk 'gsub(",", "", $1)'`
# IPv4
aws ec2 create-route \
    --route-table-id $route_table_id \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $igw_id > /dev/null
# IPv6
aws ec2 create-route \
    --route-table-id $route_table_id \
    --destination-ipv6-cidr-block ::/0 \
    --gateway-id $igw_id > /dev/null

# choose two subnets/AZ's for the application to reside in
aws ec2 describe-subnets > describe_subnets_output.json
subnet_1_id=`python -c 'import json; obj=json.load(open("describe_subnets_output.json","r"));print(obj["Subnets"][0]["SubnetId"])'`
az_1_id=`python -c 'import json; obj=json.load(open("describe_subnets_output.json","r"));print(obj["Subnets"][0]["AvailabilityZone"])'`
subnet_2_id=`python -c 'import json; obj=json.load(open("describe_subnets_output.json","r"));print(obj["Subnets"][1]["SubnetId"])'`
az_2_id=`python -c 'import json; obj=json.load(open("describe_subnets_output.json","r"));print(obj["Subnets"][1]["AvailabilityZone"])'`

# setup network acl
echo 'Configuring Network ACL...'
aws ec2 create-network-acl \
    --vpc-id $vpc_id > create_network_acl_output.json
nacl_id=`cat create_network_acl_output.json | grep NetworkAclId | awk '{print $2}' | sed s/\"//g | sed s/,//g`
vpc_cidr_block=`aws ec2 describe-vpcs | grep CidrBlock | grep [0-9] | head -1 | awk '{print $2}' | sed s/\"//g | sed s/,//g`
aws ec2 create-network-acl-entry \
    --network-acl-id $nacl_id \
    --ingress \
    --rule-number 100 \
    --cidr-block 0.0.0.0/0 \
    --protocol tcp \
    --port-range From=80,To=80 \
    --rule-action allow
aws ec2 create-network-acl-entry \
    --network-acl-id $nacl_id \
    --egress \
    --rule-number 100 \
    --cidr-block 0.0.0.0/0 \
    --protocol tcp \
    --port-range From=80,To=80 \
    --rule-action allow
aws ec2 create-network-acl-entry \
    --network-acl-id $nacl_id \
    --ingress \
    --rule-number 200 \
    --cidr-block 0.0.0.0/0 \
    --protocol tcp \
    --port-range From=443,To=443 \
    --rule-action allow
aws ec2 create-network-acl-entry \
    --network-acl-id $nacl_id \
    --egress \
    --rule-number 200 \
    --cidr-block 0.0.0.0/0 \
    --protocol tcp \
    --port-range From=443,To=443 \
    --rule-action allow
aws ec2 create-network-acl-entry \
    --network-acl-id $nacl_id \
    --ingress \
    --rule-number 300 \
    --cidr-block 0.0.0.0/0 \
    --protocol tcp \
    --port-range From=1024,To=65535 \
    --rule-action allow
aws ec2 create-network-acl-entry \
    --network-acl-id $nacl_id \
    --egress \
    --rule-number 300 \
    --cidr-block 0.0.0.0/0 \
    --protocol tcp \
    --port-range From=1024,To=65535 \
    --rule-action allow

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
        --network-acl-id $nacl_id > /dev/null # don't need to save the new association ID
done

aws ec2 associate-route-table \
    --route-table-id $route_table_id \
    --subnet-id $subnet_1_id > /dev/null
aws ec2 associate-route-table \
    --route-table-id $route_table_id \
    --subnet-id $subnet_2_id > /dev/null

# allow all incoming traffic to go to ALB
echo 'Configuring security group for ALB...'
aws ec2 create-security-group \
    --group-name MLServerALB-SecurityGroup \
    --description "Security group for the MLServerALB" > create_alb_security_group_output.json
load_balancer_security_group_id=`python -c 'import json; obj=json.load(open("create_alb_security_group_output.json","r"));print(obj["GroupId"])'`
aws ec2 authorize-security-group-ingress \
    --group-id $load_balancer_security_group_id \
    --ip-permissions IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges=[{CidrIp=0.0.0.0/0}] IpProtocol=tcp,FromPort=80,ToPort=80,Ipv6Ranges=[{CidrIpv6=::/0}] > /dev/null
aws ec2 authorize-security-group-ingress \
    --group-id $load_balancer_security_group_id \
    --ip-permissions IpProtocol=tcp,FromPort=1024,ToPort=65535,IpRanges=[{CidrIp=0.0.0.0/0}] IpProtocol=tcp,FromPort=1024,ToPort=65535,Ipv6Ranges=[{CidrIpv6=::/0}] > /dev/null
# does this need to be open to the ephemeral ports as well?

echo 'Creating ALB...'
aws elbv2 create-load-balancer \
    --name MLServer-LoadBalancer \
    --type application \
    --subnets $subnet_1_id $subnet_2_id \
    --security-groups $load_balancer_security_group_id > create_load_balancer_output.json
aws elbv2 create-target-group \
    --name MLServer-TargetGroup \
    --target-type ip \
    --protocol HTTP \
    --port 80 \
    --vpc-id $vpc_id > create_target_group_output.json
alb_arn=`cat create_load_balancer_output.json | grep LoadBalancerArn | awk '{print $2}' | sed s/\"//g | sed s/,//g`
tg_arn=`cat create_target_group_output.json | grep TargetGroupArn | awk '{print $2}' | sed s/\"//g | sed s/,//g`
aws elbv2 create-listener \
    --load-balancer-arn $alb_arn \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=$tg_arn > create_listener_output.json

################################################################################
# Push Docker image to ECR
################################################################################
# creates ECR repo
echo 'Pushing Docker Container to ECR...'
aws ecr create-repository \
	--repository-name ml-server > ecr_repo_output.json
# gets container URL
container_url=`python -c 'import json; obj=json.load(open("ecr_repo_output.json","r"));print(obj["repository"]["repositoryUri"])'`
# signs in to ECR
aws ecr get-login-password | docker login --username AWS --password-stdin $container_url
# push (previously built) Docker image to ECR
docker tag ml-server $container_url
docker push $container_url

################################################################################
# Create Fargate Service
################################################################################
# create IAM service role for Fargate cluster
echo 'Creating Fargate Cluster...'
aws iam create-role \
    --role-name MLServer-IAMRole \
    --assume-role-policy-document file://service_role_trust_policy.json > create_iam_role_output.json
iam_role_arn=`python -c 'import json; obj=json.load(open("create_iam_role_output.json","r"));print(obj["Role"]["Arn"])'`
aws iam attach-role-policy \
    --role-name MLServer-IAMRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

aws ecs create-cluster \
	--cluster-name MLServer-FargateCluster > ecs_cluster_output.json
# puts image URL into cli skeleton
python fill_in_cli_skeleton.py \
	--container_url $container_url \
	--cli_skeleton_filepath task_definition_cli_skeleton.json
aws ecs register-task-definition \
    --execution-role-arn $iam_role_arn \
	--cli-input-json file://filled_task_definition_cli_skeleton.json > task_definition_output.json
task_definition=`aws ecs list-task-definitions | grep arn | sed s/\"//g | sed s/\ //g`
aws ec2 create-security-group \
    --group-name MLServer-FargateCluster-SecurityGroup \
    --description "Security group for instances used by MLServer-FargateCluster-SecurityGroup" > create_cluster_security_group_output.json
cluster_security_group_id=`python -c 'import json; obj=json.load(open("create_cluster_security_group_output.json","r"));print(obj["GroupId"])'`
aws ec2 authorize-security-group-ingress \
    --group-id $cluster_security_group_id \
    --ip-permissions IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges=[{CidrIp=0.0.0.0/0}] IpProtocol=tcp,FromPort=80,ToPort=80,Ipv6Ranges=[{CidrIpv6=::/0}] > allow_alb_traffic_into_cluster_sg_output.json
aws ec2 authorize-security-group-ingress \
    --group-id $cluster_security_group_id \
    --ip-permissions IpProtocol=tcp,FromPort=1024,ToPort=65535,IpRanges=[{CidrIp=0.0.0.0/0}] IpProtocol=tcp,FromPort=1024,ToPort=65535,Ipv6Ranges=[{CidrIpv6=::/0}] > /dev/null
python fill_in_create_service_input_file.py \
    --task-definition $task_definition \
    --target-group-arn $tg_arn \
    --container-name MLServer \
    --cli-skeleton-filepath create_service_cli_skeleton.json
aws ecs create-service \
    --cluster MLServer-FargateCluster \
    --service-name prediction-server \
    --cli-input-json file://filled_create_service_cli_skeleton.json \
    --network-configuration "awsvpcConfiguration={subnets=[$subnet_1_id, $subnet_2_id],securityGroups=[$cluster_security_group_id],assignPublicIp=ENABLED}" > ecs_create_service_output.json

echo "Waiting for service to be created..."
sleep 60

################################################################################
# Make Service AutoScalable 
################################################################################
service_id=`cat ecs_create_service_output.json | grep serviceArn | awk '{print $2}' | awk '{gsub("^.*:service","service", $1); print}' | sed s/\"//g | sed s/,//g`
aws application-autoscaling register-scalable-target \
    --service-namespace ecs \
    --resource-id $service_id \
    --scalable-dimension ecs:service:DesiredCount \
    --min-capacity 2 \
    --max-capacity 10

# create resource_label for target-tracking-policy-configuration
alb_name=`echo "$alb_arn/" | awk '{gsub("^.*loadbalancer/","", $1); print}'`
tg_name=`aws elbv2 describe-target-groups | grep TargetGroupArn | awk '{print $2}' | awk '{gsub("^.*targetgroup","targetgroup", $1); print}' | awk '{gsub("\"|,", "", $1); print}'`
resource_label=`echo \"$alb_name$tg_name\"`

aws application-autoscaling put-scaling-policy \
    --service-namespace ecs \
    --resource-id $service_id \
    --scalable-dimension ecs:service:DesiredCount \
    --policy-type TargetTrackingScaling \
    --policy-name request-count-scaling-policy \
    --target-tracking-scaling-policy-configuration '{"TargetValue": 100, "PredefinedMetricSpecification": { "PredefinedMetricType": "ALBRequestCountPerTarget", "ResourceLabel": '$resource_label' }, "ScaleOutCooldown": 60, "ScaleInCooldown": 60 }' > put_autoscaling_policy_output.json

autoscaling_policy_arn=`cat put_autoscaling_policy_output.json | grep PolicyARN | awk '{print $2}' | sed s/\"//g | sed s/,//g`

# scale out
aws cloudwatch put-metric-alarm \
    --alarm-name MLServer-ScaleOut \
    --metric-name ALBRequestCountPerTarget \
    --namespace AWS/ECS \
    --statistic Sum \
    --evaluation-periods 1 \
    --period 60 \
    --threshold 10 \
    --comparison-operator GreaterThanOrEqualToThreshold \
    --datapoints-to-alarm 1 \
    --alarm-actions $autoscaling_policy_arn
# scale in
aws cloudwatch put-metric-alarm \
    --alarm-name MLServer-ScaleIn \
    --metric-name ALBRequestCountPerTarget \
    --namespace AWS/ECS \
    --statistic Sum \
    --evaluation-periods 1 \
    --period 60 \
    --threshold 10 \
    --comparison-operator LessThanThreshold \
    --datapoints-to-alarm 1 \
    --alarm-actions $autoscaling_policy_arn

################################################################################
# Get Public IP to of ALB
################################################################################
public_ip=`aws elbv2 describe-load-balancers | grep $alb_arn -A 2 | grep DNSName | awk '{print $2}' | sed s/\ //g | sed s/,//g | sed s/\"//g`
echo "Fargate cluster created. Use the IP ( $public_ip ) as input to test_api.py in the project root directory."

################################################################################
# Delete output files
################################################################################
echo 'Deleting unnecessary files...'
files_to_remove=`ls | grep output`
rm $files_to_remove
files_to_remove=`ls | grep filled`
rm $files_to_remove
echo 'Done'
