import argparse
import json

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
            description='Get the route table ID to be deleted.'
            )
    parser.add_argument(
            '--filepath',
            help='The path to the JSON file that is the output of `aws ec2 describe-route-tables`.'
            )
    args = parser.parse_args()

    with open(args.filepath, 'r') as f:
        obj = json.load(f)

    for group in obj["RouteTables"]:
        for route_dict in group['Routes']:
            if 'blackhole' in route_dict.values():
                print(group['RouteTableId'])
                # only taking the first one
                break


