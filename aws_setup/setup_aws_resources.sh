################################################################################
# Push Docker image to ECR
################################################################################
# creates ECR repo
aws ecr create-repository \
	--repository-name ml-server > ecr_repo_output.json

# gets repo URL
repo_url=`python -c 'import json; obj=json.load(open("ecr_repo_output.json","r"));print(obj["repository"]["repositoryUri"])'`

# signs in to ECR
aws ecr get-login-password | docker login --username AWS --password-stdin $repo_url

# push (previously built) Docker image to ECR
docker tag ml-server $repo_url
docker push $repo_url

################################################################################
# Configure Networking
################################################################################
# attach IGW to VPC
igw_id=`aws ec2 create-internet-gateway | grep InternetGatewayId | sed s/^.*\://g | sed s/\"//g | sed s/,//g`
vpc_id=`aws ec2 describe-vpcs | grep VpcId | sed s/^.*\://g | sed s/\"//g | sed s/,//g`
aws ec2 attach-internet-gateway \
    --vpc-id $vpc_id \
    --internet-gateway-id $igw_id


# choose two subnets/AZ's for the application
subnet_1_id=`aws ec2 describe-subnets | grep SubnetId | head -n 1 | sed s/^.*\://g | sed s/\"//g | sed s/,//g`
subnet_2_id=`aws ec2 describe-subnets | grep SubnetId | head -n 2 | tail -n 1 | sed s/^.*\://g | sed s/\"//g | sed s/,//g`

aws elbv2 create-target-group help \
    --name MLServerTargetGroup \
    --target-type ip

# creating security group and configuring to forward traffic from the IGW --> Load Balancer
aws ec2 create-security-group \
    --group-name FargateMLServerLoadBalancer-SecurityGroup \
    --description "Security group for the load balancer used by FargateMLServerCluster" > create_security_group_output.json
load_balancer_security_group_id=`python -c 'import json; obj=json.load(open("create_security_group_output.json","r"));print(obj["GroupId"])'`
aws ec2 authorize-security-group-ingress \
    --group-id $load_balancer_security_group_id \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 > /dev/null
aws elbv2 create-load-balancer help \
    --load-balancer-name MLServerLoadBalancer \
    --subnets $subnet_1_id $subnet_2_id \
    --security-groups $load_balancer_security_group_id

################################################################################
# Create Fargate Service
################################################################################
# create IAM service role for Fargate cluster
aws iam create-role \
    --role-name FargateMLServerRole \
    --assume-role-policy-document file://service_role_trust_policy.json > create_iam_role_output.json
iam_role_arn=`python -c 'import json; obj=json.load(open("create_iam_role_output.json","r"));print(obj["Role"]["Arn"])'`
aws iam attach-role-policy \
    --role-name FargateMLServerRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

aws ecs create-cluster \
	--cluster-name FargateMLServerCluster > ecs_cluster_output.json
# puts image URL into cli skeleton
python fill_in_cli_skeleton.py \
	--repo_url $repo_url \
	--cli_skeleton_filepath cli_skeleton.json
aws ecs register-task-definition \
    --execution-role-arn $iam_role_arn \
	--cli-input-json file://cli_skeleton_filled.json > task_definition_output.json
task_definition=`aws ecs list-task-definitions | grep arn | sed s/\"//g`
aws ec2 create-security-group \
    --group-name FargateMLServerSecurityGroup \
    --description "Security group for instances used by FargateMLServerCluster" > create_security_group_output.json
security_group_id=`python -c 'import json; obj=json.load(open("create_security_group_output.json","r"));print(obj["GroupId"])'`
aws ec2 authorize-security-group-ingress \
    --group-id $security_group_id \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 > /dev/null
aws ecs create-service \
    --cluster FargateMLServerCluster \
    --service-name fargate-service \
    --task-definition $task_definition \
    --desired-count 1 \
    --launch-type "FARGATE" \
    --load-balancer FILL_ME_IN \
    --network-configuration "awsvpcConfiguration={subnets=[subnet-32c0d06f],securityGroups=[$security_group_id],assignPublicIp=ENABLED}" > ecs_create_service_output.json

echo "Waiting for service to be created..."
sleep 60

################################################################################
# Get Public IP to test API
################################################################################
# get network interface id
cluster_task_arn=`aws ecs list-tasks --cluster FargateMLServerCluster | grep arn | sed s/\"//g | sed s/\ //g`
aws ecs describe-tasks \
    --cluster FargateMLServerCluster \
    --tasks $cluster_task_arn > FargateMLServerCluster_task_info.json
cluster_eni=`python -c 'import json; obj=json.load(open("FargateMLServerCluster_task_info.json","r"));print(obj["tasks"][0]["attachments"][0]["details"][1]["value"])'`
# get public ip of instance
public_ip_endpoint=`aws ec2 describe-network-interfaces --network-interface-id $cluster_eni | grep PublicIp | head -1 | sed s/.*\://g | sed s/\"//g`
echo "Fargate cluster created. Use the IP ( $public_ip_endpoint ) as input to test_api.py in the project root directory."

################################################################################
# Delete output files
################################################################################
echo 'Deleting output files...'
rm FargateMLServerCluster_task_info.json
rm cli_skeleton_filled.json
rm create_iam_role_output.json
rm create_security_group_output.json
rm ecr_repo_output.json
rm ecs_cluster_output.json
rm ecs_create_service_output.json
rm task_definition_output.json
echo 'Done'

