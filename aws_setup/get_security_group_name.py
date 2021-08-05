import argparse
import json

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
            description='Get the security group ID to be deleted.'
            )
    parser.add_argument(
            '--filepath',
            help='The path to the JSON file that is the output of `aws ec2 describe-security-groups`.'
            )
    args = parser.parse_args()

    with open(args.filepath, 'r') as f:
        obj = json.load(f)

    for group in obj["SecurityGroups"]:
        if 'MLServer' in group['GroupName']:
            print(group['GroupId'])
