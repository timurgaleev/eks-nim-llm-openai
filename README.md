# Building an AI-Optimized Platform on Amazon EKS with NVIDIA NIM and OpenAI Models


## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_eks_cluster_version"></a> [eks\_cluster\_version](#input\_eks\_cluster\_version) | EKS Cluster version | `string` | `"1.31"` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the VPC and EKS Cluster | `string` | `"k8s-nim"` | no |
| <a name="input_ngc_api_key"></a> [ngc\_api\_key](#input\_ngc\_api\_key) | NGC API Key | `string` | `"API_KEY_REPLACE_ME"` | no |
| <a name="input_nim_models"></a> [nim\_models](#input\_nim\_models) | NVIDIA NIM Models | <pre>list(object({<br>    name    = string<br>    id      = string<br>    enable  = bool<br>    num_gpu = string<br>  }))</pre> | <pre>[<br>  {<br>   "enable": true,<br>    "id": "nvcr.io/nim/meta/llama3-8b-instruct",<br>    "name": "llama3-8b-instruct",<br>    "num_gpu": "1"<br>  }<br>]</pre> | no |
| <a name="input_region"></a> [region](#input\_region) | region | `string` | `"us-west-2"` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | VPC CIDR. This should be a valid private (RFC 1918) CIDR range | `string` | `"10.1.0.0/21"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_configure_kubectl"></a> [configure\_kubectl](#output\_configure\_kubectl) | Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig |
| <a name="output_grafana_secret_name"></a> [grafana\_secret\_name](#output\_grafana\_secret\_name) | The name of the secret containing the Grafana admin password. |
