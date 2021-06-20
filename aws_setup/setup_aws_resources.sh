aws ecr create-repository \
	--repository-name local-to-cloud-ml > ecr_repo_output.json

aws ecs create-cluster \
	--cluster-name basic-ml-api

