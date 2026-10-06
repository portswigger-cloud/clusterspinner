# clusterspinner

This repository contains tools to set up an AWS Elastic Kubernetes Service cluster from scratch.
Features:

* Access your cluster from anywhere using teleport
* Manage Kubernetes configuration with ArgoCD and configuration changes committed to a git repository
* A high level of automation in the setup
* Easy to clean up and destroy all the created resources

## Architecture

There are three stages of terraform to set up the environment.

1. Create the terraform state bucket.
2. Run the account level terraform setup. This is designed to be done with a highly privileged AWS IAM Role and 
   will create a less privileged role for the next step.
3. Run the cluster level terraform setup. This can be done one or more times to set up independent clusters.

The terraform run in setup_cluster will set up ArgoCD in the newly created cluster that will attempt to clone 
and apply configuration from a public git repo. The content of this repo is generated using the 
[manifest-builder](https://github.com/nresare/manifest-builder) tool from the `config` directory.

The manifests are set up to bring up a Teleport cluster with endpoint that can be used to access the cluster.

## Prerequisites

* terraform, I install my terraform with `brew install terraform`

## Installation

### Create the terraform state bucket
* Decide on a globally unique name for your bucket and an aws region to set up the bucket in.
* Set up your AWS credentials with a role with the necessary permissions to create S3 buckets.
* Go to the `terraform/create_bucket` directory and run `terraform init`,
* Run `terraform apply -var=bucket_name=$BUCKET -var=region=$REGION`

### Set up account-wide resources
* Set up your AWS credentials with a role with broad permissions such as `AdministratorAccess`
* Go to the `terraform/setup_account` directory and run `terraform init -backend-config=bucket=$BUCKET -backend-config=region=$REGION`,
* Run `terraform plan` and `terraform apply`. This creates the crossplane permissions boundary and the roles Teleport assumes.

### Create the account level terraform setup
* Set up your AWS credentials with a role with broad permissions such as `AdministratorAccess`
* Go to the `terraform/with_admin_permissions` directory and run `terraform init -backend-config=bucket=$BUCKET -backend-config=region=$REGION`,
* Run `terraform plan` and `terraform apply`
* 
### Run the terraform to setup the cluster
* Assume the clusterspinner role that was created in the previous step.
* Go to the `terraform/setup_cluster` directory and run `terraform init -backend-config=bucket=$BUCKET -backend-config=region=$REGION`,
* Run `terraform plan` and `terraform apply`
  * You will be prompted for cluster names that you want to create. This can be modified in the future, so if this
      is a first setup, I would recommend just picking one name. I provided `["cluster0"]` in this case.
  * You will be prompted for trusted principals. This is a list of AWS IAM principal ARNs that will be allowed to assume
    the clusterspinner role that this invocation creates.
  * You also need to pick a github namespace for the manifest configuration. This can be a user or an organization.
* The last step typically takes a bit more than 10 minutes, so plenty of time
  to continue with the steps:

### Set up the manifest repository

* Create a respository in the github location you picked above named `$cluster-manifets`
* Install latest [manifest-builder](https://github.com/nresare/manifest-builder) tool
* I invoked `uv run manifest-builder -c config -o ../cluster0-manifests --create-commit --allow-dirty-config`
* Push the generated directory to the newly created repository

### Grant yourself Teleport access.

This is unfortunately not automated yet:
* Using your clusterspinner role, you can configure kubectl: `aws eks update-kubeconfig --region $REGION --name $CLUSTER`
* Invoke `kubectl -n teleport-cluster exec deploy/teleport-cluster-auth -- tctl users add $USER --roles=access,editor`
* This should print a one-time link that you can use to set your password and 2-factor authentication.

## License

Released under the [MIT License](LICENSE). Source files carry SPDX headers (`SPDX-License-Identifier: MIT`).

