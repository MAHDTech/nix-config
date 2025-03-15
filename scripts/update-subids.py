#!/usr/bin/env python3

import grp
import os
import argparse
import sys


# Enable for additional debug messages.
DEBUG = os.getenv("DEBUG", "False").upper() == "TRUE"


def eprint(*args, **kwargs):
    """
    eprint.

    Prints message to stderr instead of stdout
    """
    print(*args, file=sys.stderr, **kwargs)


def parse_args():
    """
    parse_args.

    Parses the provided command line arguments and returns as 'args'
    """
    parser = argparse.ArgumentParser(description="Make API calls to an OAuth URL")

    parser.add_argument(
        "-g",
        "--group",
        help="The group of users to add sub ids for", required=False
    )

    parser.add_argument(
        "-x",
        "--execute",
        type=bool,
        default=False,
        action=argparse.BooleanOptionalAction,
        help="Enable the script to make changes. Without this dry-run mode is enabled.", required=False
    )

    args = parser.parse_args()

    if DEBUG:
        eprint("The parsed arguments")
        eprint(args)

    return args


def get_ids(filename):
    """
    Returns a list of ids from a file subuid/subgid format
    """

    eprint("\nCollecting ids from file: {}".format(filename))

    ids = []

    with open(filename, "r") as file:

        for line in file:
            id = line.split(":", 3)
            print("Appending %s to list" % id[0])
            ids.append(id[0])

        file.close()

    return ids


def set_ids(filename, ids):
    """
    Gives each id a non-overlapping set of subuids or subgids.
    """

    # All ids start from this point.
    start_id = 100000
    range = 65536

    if not DRY_RUN:
        try:
            file = open(filename, "w")

            for id in ids:
                sub_id_range = "{}:{}:{}".format(id, start_id, range)
                eprint("Setting sub id range for {} to {}".format(id, sub_id_range))
                file.write(sub_id_range + "\n")
                start_id = start_id + range

            file.close()

        except Exception as e:
            eprint("Failed to write to file: {}".format(e))
            exit(1)

    else:
        for id in ids:
            sub_id_range = "{}:{}:{}".format(id, start_id, range)
            eprint("DRY RUN: Setting sub id range for {} to {}".format(id, sub_id_range))
            start_id = start_id + range


if __name__ == "__main__":

    eprint("\nSetting up user sub-ids...")

    # Parse any provided command line arguments.
    args = parse_args()

    # If execute was not passed, dry-run is enabled.
    if args.execute:
        eprint("\nDry run disabled, changes will be made.")
        DRY_RUN = False
    else:
        eprint("\nDry run enabled, no changes will be made.")
        DRY_RUN = True

    # If a custom group was provided, use that
    if args.group:
        docker_group = args.group
    # Otherwise default to the local docker group.
    else:
        docker_group = "docker"

    # Initialise an empty list to start.
    docker_users = []

    # Get all the existing uids on file
    subuids = get_ids("/etc/subuid")

    # Get all the existing gids on file
    subgids = get_ids("/etc/subgid")

    try:
        grp.getgrnam(docker_group)
        for user in grp.getgrnam(docker_group).gr_mem:
            docker_users.append(user)

        if DEBUG:
            eprint("\nThe Docker users")
            eprint("Docker users: {}".format(docker_users))

    except KeyError:
        eprint("The Docker group {} does not exist, skipping".format(docker_group))

    # Dedup a single list of users
    unique_users = set(docker_users) - set(subuids)
    total_users = subuids + list(unique_users)

    # Dedup a single list of groups for all the users.
    unique_groups = set(docker_users) - set(subgids)
    total_groups = subgids + list(unique_groups)

    # Display the summary
    eprint("\nSummary:")
    eprint("Collected %d total users for processing" % len(total_users))
    if DEBUG:
        eprint("\nTotal users: {}".format(total_users))
    eprint("Collected %d total groups for processing" % len(subuids))
    if DEBUG:
        eprint("\nTotal groups: {}".format(total_groups))

    # For each user, give then a range of subuids
    eprint("\nSetting sub user ids")
    set_ids("/etc/subuid", total_users)

    # For each group, give then a range of subgids
    eprint("\nSetting sub group ids")
    set_ids("/etc/subgid", total_groups)

