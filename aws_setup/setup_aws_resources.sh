# creates repo
aws ecr create-repository \
	--repository-name ml-server > ecr_repo_output.json

# gets repo URL
repo_url=`python -c 'import json; obj=json.load(open("ecr_repo_output.json","r"));print(obj["repository"]["repositoryUri"])'`

# signs in to ECR
aws ecr get-login-password | docker login --username AWS --password-stdin $repo_url

# push (already built) Docker image to ECR
docker tag ml-server $repo_url
docker push $repo_url
