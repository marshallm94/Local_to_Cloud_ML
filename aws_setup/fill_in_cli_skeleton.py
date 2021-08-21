import argparse
import json

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
            description='Fill in the CLI skeleton for an AWS Task Definition.'
            )
    parser.add_argument(
            '--container_url',
            help='The full URL for the Docker image to be used in the Task definition'
            )
    parser.add_argument(
            '--cli_skeleton_filepath',
            help='The path to the CLI skeleton that needs to be filled in.'
            )
    args = parser.parse_args()

    filled_filepath = args.cli_skeleton_filepath
    with open(filled_filepath, 'r') as f:
        obj = json.load(f)

    obj['containerDefinitions'][0]['image'] = args.container_url

    name, _ = args.cli_skeleton_filepath.split('.')
    filled_filepath = 'filled_' + name + '.json'
    with open(filled_filepath, 'w') as f:
        json.dump(obj, f, indent=4)
