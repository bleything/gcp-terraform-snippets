Cloud Run Image Processing Tutorial
================================================================================

Several approaches to the [Processing Images from Cloud Storage] tutorial.

#### [`no_variables`](no_variables/main.tf)

In this example we take advantage of the fact that you can specify the target
project in the provider's config and resources will default to that project.

#### [`with_variables`](with_variables/main.tf)

In this example we parameterize the project ID by declaring an input variable
(see [`variables.tf`](with_variables/variables.tf)). We use a
[`terraform.tfvars`](with_variables/terraform.tfvars) file to pass in the
variable value but you could just as easily use an environment variable or CLI
flag. See [the Input Variables docs] for more.

Note that putting variables in a file called `variables.tf` is a common and
recommended convention while `terraform.tfvars` is a magical name that is
automatically picked up by Terraform.

#### [`custom_module`](custom_module)

In this example we wrap the resources in a module. This was done to demonstrate
how a module looks but is not really how you'd use modules in reality. Modules
abstract collections of resources into a single meta-resource that you can use
to create multiple copies of the collection.

In terms of this project, a module would only be useful if you wanted to create
multiple instances of the imgproc application, each with their own storage
buckets and cloud run service.

This example is provided only so you can see how you create and use a module and
is not intended as a robust or recommended solution to the tutorial.

[Processing Images from Cloud Storage]: https://cloud.google.com/run/docs/tutorials/image-processing
[the Input Variables docs]: https://www.terraform.io/docs/language/values/variables.html#assigning-values-to-root-module-variables

Setup
--------------------------------------------------------------------------------

These examples require a little bit of setup ahead of time:

1. create a new project
1. associate a billing account
1. create a terraform service account
1. give that SA `roles/owner` (I know. Don't do this on your real systems.)
1. create a key for the SA and save it locally as `terraform-sa.key`
1. enable the Service Usage and Cloud Resource Manager APIs

That could like this:

    $ gcloud init
    [interactively create project and init local config]

    $ export GOOGLE_PROJECT=<project id>
    $ gcloud beta billing projects link $GOOGLE_PROJECT --billing-account <billing account ID>
    $ gcloud iam service-accounts create terraform
    $ gcloud projects add-iam-policy-binding $GOOGLE_PROJECT \
      --member serviceAccount:terraform@${GOOGLE_PROJECT}.iam.gserviceaccount.com \
      --role roles/owner
    $ gcloud iam service-accounts keys create \
      --iam-account terraform@${GOOGLE_PROJECT}.iam.gserviceaccount.com \
      terraform-sa.key
    $ gcloud services enable serviceusage.googleapis.com
    $ gcloud services enable cloudresourcemanager.googleapis.com

Note that the examples expect the key file to be in the same directory as this
README.
