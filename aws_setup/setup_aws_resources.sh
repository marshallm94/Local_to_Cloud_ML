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
	--cluster-name ECSMLServerCluster > ecs_cluster_output.json

# TODO: Would making this Fargate based be simpler? Would it be more appropriate?
# TODO: create an EC2 launch template
# TODO: create an autoscaling group
# TODO: launch an instance

aws ec2 run-instances \
    --image-id \
    --count 1 \
    --instance-type t2.micro

aws autoscaling create-auto-scaling-group \
    --auto-scaling-group-name MLServerAutoScalingGroup \
    --min-size 

python fill_in_cli_skeleton.py \
	--repo_url $repo_url \
	--cli_skeleton_filepath cli_skeleton.json

aws ecs register-task-definition \
	--cli-input-json file://cli_skeleton_filled.json > task_definition_output.json

task_definition=`aws ecs list-task-definitions | grep arn | sed s/\"//g`

echo $task_definition
aws ecs run-task \
	--cluster ECSMLServerCluster \
	--count 1 \
	--launch-type EC2 \
	--task-definition $task_definition

