output "argocd_namespace" {
  description = "Namespace where Argo CD is deployed"
  value       = kubernetes_namespace_v1.argocd.metadata[0].name
}

output "external_secrets_namespace" {
  description = "Namespace where External Secrets Operator is deployed"
  value       = kubernetes_namespace_v1.external_secrets.metadata[0].name
}
