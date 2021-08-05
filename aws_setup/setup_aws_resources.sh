################################################################################
# Push Docker image to ECR
################################################################################
# creates ECR repo
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
# Configure Networking
################################################################################
# create & attach IGW to VPC to allow public access
igw_id=`aws ec2 create-internet-gateway | grep InternetGatewayId | sed s/^.*\://g | sed s/\"//g | sed s/,//g`
vpc_id=`aws ec2 describe-vpcs | grep VpcId | sed s/^.*\://g | sed s/\"//g | sed s/,//g`
aws ec2 attach-internet-gateway \
    --vpc-id $vpc_id \
    --internet-gateway-id $igw_id

# create route table & point all outgoing traffic to IGW
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

#aws ec2 associate-route-table \
#    --route-table-id $route_table_id \
#    --subnet-id $subnet_1_id > /dev/null

# creating security group and configuring to forward traffic from the IGW --> Load Balancer
aws ec2 create-security-group \
    --group-name MLServerALB-SecurityGroup \
    --description "Security group for the MLServerALB" > create_security_group_output.json
load_balancer_security_group_id=`python -c 'import json; obj=json.load(open("create_security_group_output.json","r"));print(obj["GroupId"])'`
# aws ec2 authorize-security-group-ingress \
#     --group-id $load_balancer_security_group_id \
#     --protocol tcp \
#     --port 80 \
#     --cidr 0.0.0.0/0 > /dev/null
 
 # configure load balancer
 # https://docs.aws.amazon.com/elasticloadbalancing/latest/application/tutorial-application-load-balancer-cli.htmlhttps://docs.aws.amazon.com/elasticloadbalancing/latest/application/tutorial-application-load-balancer-cli.html
 
 # 1. aws elbv2 create-load-balancer
 # 2. aws elbv2 create-target-group
 # 3. aws elbv2 register-targets help
 # 4. aws elbv2 create-listener help
 
aws elbv2 create-load-balancer help
aws elbv2 create-load-balancer \
    --name MLServer-LoadBalancer \
    --subnets $subnet_1_id $subnet_2_id \
    --security-groups $load_balancer_security_group_id > create_load_balancer_output.json
# create target group 
aws elbv2 create-target-group \
    --name MLServer-TargetGroup \
    --target-type ip \
    --protocol HTTP \
    --port 80 \
    --vpc-id $vpc_id > create_target_group_output.json

#       Example 3: To register targets with a target group by IP address
#
#       The  following  register-targets  example  registers  the  specified IP
#       addresses with a target group. The target group must have a target type
#       of ip.
#
#          aws elbv2 register-targets \
#              --target-group-arn arn:aws:elasticloadbalancing:us-west-2:123456789012:targetgroup/my-tcp-ip-targets/8518e899d173178f \
#              --targets Id=10.0.1.15 Id=10.0.1.23


################################################################################
# Create Fargate Service
################################################################################
# create IAM service role for Fargate cluster
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
task_definition=`aws ecs list-task-definitions | grep arn | sed s/\"//g`
aws ec2 create-security-group \
    --group-name MLServer-FargateCluster-SecurityGroup \
    --description "Security group for instances used by MLServer-FargateCluster-SecurityGroup" > create_security_group_output.json
security_group_id=`python -c 'import json; obj=json.load(open("create_security_group_output.json","r"));print(obj["GroupId"])'`
aws ec2 authorize-security-group-ingress \
    --group-id $security_group_id \
    --protocol tcp \
    --port 80 \
    --source-group $load_balancer_security_group_id
    #--cidr 0.0.0.0/0 > /dev/null
aws ecs create-service \
    --cluster MLServer-FargateCluster \
    --service-name prediction-server \
    --task-definition $task_definition \
    --desired-count 1 \
    --launch-type "FARGATE" \
    --network-configuration "awsvpcConfiguration={subnets=[$subnet_1_id, $subnet_2_id],securityGroups=[$security_group_id],assignPublicIp=ENABLED}" > ecs_create_service_output.json
    #--load-balancer FILL_ME_IN \

echo "Waiting for service to be created..."
sleep 60

################################################################################
# Get Public IP to test API
################################################################################
# get network interface id
cluster_task_arn=`aws ecs list-tasks --cluster MLServer-FargateCluster | grep arn | sed s/\"//g | sed s/\ //g`
aws ecs describe-tasks \
    --cluster MLServer-FargateCluster \
    --tasks $cluster_task_arn > MLServer-FargateCluster_task_info_output.json
cluster_eni=`python -c 'import json; obj=json.load(open("MLServer-FargateCluster_task_info_output.json","r"));print(obj["tasks"][0]["attachments"][0]["details"][1]["value"])'`
# get public ip of instance
public_ip_endpoint=`aws ec2 describe-network-interfaces --network-interface-id $cluster_eni | grep PublicIp | head -1 | sed s/.*\://g | sed s/\"//g | sed s/\ //g`
echo "Fargate cluster created. Use the IP ( $public_ip_endpoint ) as input to test_api.py in the project root directory."

################################################################################
# Delete output files
################################################################################
echo 'Deleting unnecessary files...'
files_to_remove=`ls | grep output`
rm $files_to_remove
rm filled_task_definition_cli_skeleton.json
echo 'Done'

