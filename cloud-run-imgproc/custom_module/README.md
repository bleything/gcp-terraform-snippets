imgproc Custom Modules Example
================================================================================

In this example we take the resources we created in the other examples and put
them into a module. This isn't necessarily an approach you'd take in actual
code; the intent is to demonstrate how modules work while sticking with a
familiar example.

Modules abstract collections of resources into a single meta-resource that you
can use to create multiple copies of the infrastructure. In this case it's
unlikely you'd want several parallel instances of the imgproc example so it's
not that useful except as a learning tool. Also, I'm not your real dad and if
you want multiple copies of imgproc I'm not going to stop you.

Anatomy of the Example
--------------------------------------------------------------------------------

This example is more complex than the others so let's talk about what's going on
in here. First we have the [`main.tf`](main.tf) that contains our provider
config and invokes [the module](modules/imgproc). Next we declare a couple of
outputs in [`outputs.tf`](outputs.tf). This allows us to extract values from the
module and output them at the end of a terraform run.

Inside the module you'll find some familiar friends:

* [`main.tf`](modules/imgproc/main.tf)
* [`variables.tf`](modules/imgproc/variables.tf)
* [`outputs.tf`](modules/imgproc/outputs.tf)

These names represent the predominant convention in the Terraform
community. Terraform itself doesn't care but the humans who use it do. Best to
stick to convention!

You might be thinking "wait this looks exactly like what we did in the
[`with_variables`](../with_variables) example... and you'd be right. A terraform
module is just a directory with some terraform files in it. Your top-level
terraform files create what's known as the "root module". That's what you're in
right now. The module stored in [`modules/imgproc`](modules/imgproc) is known as
a "child module". More details can be found [in the Modules docs].

[in the Modules docs]: https://www.terraform.io/docs/language/modules/index.html

The upshot is that if you want to modularize some code, all you do is copy it
into a directory, declare some inputs and outputs, and you're good to go. It
took much longer to write this paragraph than it did to refactor the code into a
module.
