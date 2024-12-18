module "efs" {
  source  = "terraform-aws-modules/efs/aws"
  version = "~> 1.6"

  creation_token = local.name
  name           = local.name

  # Mount targets / security group
  mount_targets = {
    for k, v in zipmap(local.azs, slice(module.vpc.private_subnets, length(module.vpc.private_subnets) - 2, length(module.vpc.private_subnets))) : k => { subnet_id = v }
  }
  security_group_description = "${local.name} EFS security group"
  security_group_vpc_id      = module.vpc.vpc_id
  security_group_rules = {
    vpc = {
      # relying on the defaults provided for EFS/NFS (2049/TCP + ingress)
      description = "NFS ingress from VPC private subnets"
      cidr_blocks = module.vpc.private_subnets_cidr_blocks
    }
  }

  tags = local.tags
}

resource "kubernetes_storage_class_v1" "efs" {
  metadata {
    name = "efs"
  }

  storage_provisioner = "efs.csi.aws.com"
  parameters = {
    provisioningMode = "efs-ap" # Dynamic provisioning
    fileSystemId     = module.efs.id
    directoryPerms   = "777"
  }

  mount_options = [
    "iam"
  ]

  depends_on = [
    module.eks_blueprints_addons.aws_efs_csi_driver
  ]
}

resource "kubernetes_namespace" "nim" {
  metadata {
    name = "nim"
  }

  depends_on = [module.eks]
}

resource "kubernetes_persistent_volume_claim_v1" "efs_pvc" {
  metadata {
    name      = kubernetes_namespace.nim.metadata[0].name
    namespace = "nim"
  }
  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = kubernetes_storage_class_v1.efs.metadata[0].name
    resources {
      requests = {
        storage = "100Gi"
      }
    }
  }
}

#---------------------------------------------------------------
# NIM LLM Helm Chart
#---------------------------------------------------------------
resource "null_resource" "download_nim_deploy" {
  triggers = {
    script_executed = fileexists("${path.module}/nim-llm/Chart.yaml") ? "false" : "true"
  }

  provisioner "local-exec" {
    command = <<-EOT
      if [ ! -d "${path.module}/nim-llm" ]; then
        echo "Downloading nim-deploy repo ..."
        TEMP_DIR=$(mktemp -d)
        git clone https://github.com/NVIDIA/nim-deploy.git "$TEMP_DIR/nim-deploy"
        cp -r "$TEMP_DIR/nim-deploy/helm/nim-llm" ${path.module}/nim-llm
        rm -rf "$TEMP_DIR"
        echo "Download completed."
      else
        echo "nim-llm directory already exists. Skipping download."
      fi
    EOT
  }
}

#--------------------------------------------------------------------
# Helm Chart for deploying NIM models
#--------------------------------------------------------------------
locals {
  enabled_models = {
    for model in var.nim_models : model.name => model
    if model.enable
  }
}


resource "helm_release" "nim_llm" {
  for_each         = local.enabled_models
  name             = "nim-llm-${each.key}"
  chart            = "${path.module}/nim-llm"
  create_namespace = true
  namespace        = kubernetes_namespace.nim.metadata[0].name
  timeout          = 360
  wait             = false
  values = [
    templatefile(
      "${path.module}/helm-values/nim-llm.yaml",
      {
        model_id    = each.value.id
        name        = each.value.name
        num_gpu     = each.value.num_gpu
        ngc_api_key = var.ngc_api_key
        pvc_name    = kubernetes_persistent_volume_claim_v1.efs_pvc.metadata[0].name
      }
    )
  ]

  depends_on = [
    null_resource.download_nim_deploy,
    module.eks_blueprints_addons.ingress_nginx
  ]
}

#--------------------------------------------------------------------
# Helm Chart for deploying Open WebUI
#--------------------------------------------------------------------
resource "helm_release" "openai_webui" {
  name             = "openai-webui"
  chart            = "open-webui"
  repository       = "https://helm.openwebui.com/"
  create_namespace = true
  namespace        = "openai-webui"
  timeout          = 300
  wait             = true

  values = [
    jsonencode({
      replicaCount = 1
      image = {
        repository = "ghcr.io/open-webui/open-webui"
        pullPolicy = "IfNotPresent"
        tag        = "main" # Match the tag used in the YAML
      }
      service = {
        type          = "ClusterIP"
        port          = 80
        containerPort = 8080
      }
      persistence = {
        enabled = false # Disable persistence if it’s not required
      }
      openaiBaseApiUrl = "http://nim-llm-llama3-8b-instruct.nim.svc.cluster.local:8000/v1"
      extraEnvVars = [
        {
          name  = "OPENAI_API_KEY"
          value = "dummy" # Replace with actual API key
        }
      ]
      resources = {
        requests = {
          cpu    = "500m"
          memory = "500Mi"
        }
        limits = {
          cpu    = "1000m"
          memory = "1Gi"
        }
      }
      ollama = {
        enabled = false # Disable Ollama if not required
      }
      pipelines = {
        enabled = false # Disable Pipelines if not required
      }
      tika = {
        enabled = false # Disable Apache Tika if not required
      }
    })
  ]

  depends_on = [
    module.eks,
    helm_release.nim_llm
  ]
}
