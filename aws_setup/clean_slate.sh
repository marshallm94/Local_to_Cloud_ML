# delete Docker images & repo
repo_name=`aws ecr describe-repositories | grep repositoryName | awk '{print $2}' | sed s/\"//g | sed s/,//g`
aws ecr batch-delete-image \
    --repository-name $repo_name \
    --image-ids imageTag=latest > /dev/null
aws ecr delete-repository --repository-name $repo_name > /dev/null

# detach & delete IGW
igw_id=`aws ec2 describe-internet-gateways | grep InternetGatewayId | awk '{print $2}' | sed s/\"//g | sed s/,//g`
vpc_id=`aws ec2 describe-internet-gateways | grep VpcId | awk '{print $2}' | sed s/\"//g`
aws ec2 detach-internet-gateway \
    --internet-gateway-id $igw_id \
    --vpc-id $vpc_id > /dev/null
aws ec2 delete-internet-gateway \
    --internet-gateway-id $igw_id > /dev/null

# delete SG's
aws ec2 describe-security-groups > describe_security_group_output.json
alb_sg=`python get_security_group_name.py --filepath describe_security_group_output.json`
aws ec2 delete-security-group --group-id $alb_sg

# delete IAM Role
iam_role=`aws iam list-roles | grep MLServer | grep RoleName | awk '{print $2}' | sed s/\"//g | sed s/,//g`
policy_arn=`aws iam list-attached-role-policies --role-name $iam_role | grep PolicyArn | awk '{print $2}' | sed s/\"//g`
aws iam detach-role-policy \
    --role-name $iam_role \
    --policy-arn $policy_arn
aws iam delete-role --role-name $iam_role
