# docker_deploy

This cookbook works with `Chef 12 Stack`.

## Running test-kitchen

Strongly recommend you to install chefdk.

Make sure that you export necessary environment variables.

```sh
chef exec gem install kitchen-sync

export AWS_SUBNET_ID=subnet-foobar AWS_SSH_KEY_ID=foobar-ec2 AWS_SSH_KEY=~/.ssh/foobar-ec2.pem AWS_SG_ID=sg-foobar NO_OPSWORKS=1 KITCHEN_SYNC_MOE=sftp
chef exec kitchen verify
```
