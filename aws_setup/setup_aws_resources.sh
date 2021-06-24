# creates repo
aws ecr create-repository \
	--repository-name ml-server > ecr_repo_output.json

# gets repo URL
repo_url=`python -c 'import json; obj=json.load(open("ecr_repo_output.json","r"));print(obj["repository"]["repositoryUri"])'`

# signs in to ECR
aws ecr get-login-password | docker login --username AWS --password-stdin $repo_url

docker tag ml-server $repo_url
docker push $repo_url

# ECS Version
aws ecs create-cluster \
	--cluster-name ECSMLServerCluster \

# aws ecs create-task-set 
# aws ecs run-task

# Fargate Version
# aws ecs create-cluster \
# 	--cluster-name fargate-ml-api > fargate_cluster_output.json
# 
# aws ecs register-task-definition \
# 	--cli-input-json file://task_definition.json
# 
# aws ecs list-task-definitions
# 
# aws ecs create-service \
# 	--cluster fargate-ml-api \
# 	--service-name fargate-service \
# 	--task-definition sample-fargate:1 \ #this should be obtained programmatically
# 	--desired-count 1 \
# 	--launch-type "FARGATE" \



