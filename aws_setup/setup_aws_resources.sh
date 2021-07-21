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

aws ecs create-cluster \
	--cluster-name FargateMLServerCluster > ecs_cluster_output.json

# puts image URL into cli skeleton
python fill_in_cli_skeleton.py \
	--repo_url $repo_url \
	--cli_skeleton_filepath cli_skeleton.json

# NOTE: this assumes the FargateMLServerRole has already been created (TODO: automate)
aws ecs register-task-definition \
    --execution-role-arn arn:aws:iam::595614743545:role/FargateMLServerRole \
	--cli-input-json file://cli_skeleton_filled.json > task_definition_output.json

task_definition=`aws ecs list-task-definitions | grep arn | sed s/\"//g`

# NOTE: this assumes the security group has already been set up. (TODO: automate)
aws ecs create-service \
    --cluster FargateMLServerCluster \
    --service-name fargate-service \
    --task-definition $task_definition \
    --desired-count 1 \
    --launch-type "FARGATE" \
    --network-configuration "awsvpcConfiguration={subnets=[subnet-32c0d06f],securityGroups=[sg-06098058f5f29e3a7],assignPublicIp=ENABLED}" > ecs_create_service_output.json

echo "Waiting for service to be created..."
sleep 180

# get network interface id
cluster_task_arn=`aws ecs list-tasks --cluster FargateMLServerCluster | grep arn | sed s/\"//g | sed s/\ //g`
aws ecs describe-tasks \
    --cluster FargateMLServerCluster \
    --tasks $cluster_task_arn > FargateMLServerCluster_task_info.json

cluster_eni=`python -c 'import json; obj=json.load(open("FargateMLServerCluster_task_info.json","r"));print(obj["tasks"][0]["attachments"][0]["details"][1]["value"])'`

# get public ip of instance
aws ec2 describe-network-interfaces --network-interface-id $cluster_eni | grep PublicIp | head -1 | sed s/.*\://g | sed s/\"//g > ../instance_public_ip.txt

echo "Fargate cluster created. Use the IP in ../instance_public_ip.txt to evaluate the test set."
