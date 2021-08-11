import argparse
import json

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
            description='Fill in the CLI skeleton for an AWS Service.'
            )
    parser.add_argument(
            '--task-definition',
            help='The task definition to be run using the cluster.'
            )
    parser.add_argument(
            '--target-group-arn',
            help='The target group ARN to which traffic from the ALB should be forwarded.'
            )
    parser.add_argument(
            '--container-name',
            help='The container name to which traffic should be forwarded.'
            )
    parser.add_argument(
            '--container-port',
            default = 80,
            help='The container port to which traffic should be forwarded.'
            )
    parser.add_argument(
            '--cli-skeleton-filepath',
            help='The path to the CLI skeleton that needs to be filled in.'
            )
    args = parser.parse_args()

    filled_filepath = args.cli_skeleton_filepath
    with open(filled_filepath, 'r') as f:
        obj = json.load(f)

    obj["taskDefinition"] = args.task_definition
    obj["loadBalancers"][0]['targetGroupArn'] = args.target_group_arn
    obj["loadBalancers"][0]['containerName'] = args.container_name
    obj["loadBalancers"][0]['containerPort'] = args.container_port

    name, _ = args.cli_skeleton_filepath.split('.')
    filled_filepath = 'filled_' + name + '.json'
    with open(filled_filepath, 'w') as f:
        json.dump(obj, f, indent=4)
