See https://jeroen-de-groot.com/2020/11/25/deploying-sitecore-with-terraform-part-2/ for detailed deployment instructions and an explanation of the resources which are getting created.

Quick steps
1. Create secret.tfvars and set the variables which require deployment specific values
2. terraform init
3. terraform plan -var-file="secret.tfvars"
4. terraform apply -var-file="secret.tfvars"
