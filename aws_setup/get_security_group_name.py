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
    parser.add_argument(
            '--sg_group_name_search',
            help='The character string to search for in the security group name.'
            )
    args = parser.parse_args()

    with open(args.filepath, 'r') as f:
        obj = json.load(f)

    for group in obj["SecurityGroups"]:
        if args.sg_group_name_search in group['GroupName']:
            print(group['GroupId'])
