#!/usr/bin/env bash
su ec2-user
sudo yum update
sudo yum upgrade -y
sudo yum install amazon-cloudwatch-agent -y