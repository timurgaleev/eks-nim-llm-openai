variable "name" {
  description = "Name of the VPC and EKS Cluster"
  default     = "k8s-nim"
  type        = string
}

variable "region" {
  description = "region"
  default     = "us-west-2"
  type        = string
}

variable "ngc_api_key" {
  description = "NGC API Key"
  type        = string
  sensitive   = true
}

variable "nim_models" {
  description = "NVIDIA NIM Models"
  type = list(object({
    name    = string
    id      = string
    enable  = bool
    num_gpu = string
  }))
  default = [
    {
      name    = "llama-3-1-8b-instruct"
      num_gpu = "4"
      id      = "nvcr.io/nim/meta/llama-3.1-8b-instruct"
      enable  = false
    },
    {
      name    = "llama3-8b-instruct"
      num_gpu = "1"
      id      = "nvcr.io/nim/meta/llama3-8b-instruct"
      enable  = true
    }
    # Add more models as needed
  ]
}

variable "eks_cluster_version" {
  description = "EKS Cluster version"
  default     = "1.30"
  type        = string
}

# VPC with 2046 IPs (10.1.0.0/21) and 2 AZs
variable "vpc_cidr" {
  description = "VPC CIDR. This should be a valid private (RFC 1918) CIDR range"
  default     = "10.1.0.0/21"
  type        = string
}

# RFC6598 range 100.64.0.0/10
# Note you can only /16 range to VPC. You can add multiples of /16 if required
variable "secondary_cidr_blocks" {
  description = "Secondary CIDR blocks to be attached to VPC"
  default     = ["100.64.0.0/16"]
  type        = list(string)
}
