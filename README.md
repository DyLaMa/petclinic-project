# PetClinic Project - TP4 CI/CD GitOps

## Description
Projet d'automatisation du déploiement de Spring PetClinic sur AWS avec CI/CD et GitOps.

## IAM Configuration
L'utilisateur github-actions-user utilise la politique github-actions-full-policy.

## Reconstruction après nettoyage
Le pipeline va tout reconstruire automatiquement.

## Fix : Recreate S3 and DynamoDB completely
Le bucket S3 et la table DynamoDB ont été recréés.

## Fix : ECR repository deleted
Le repository ECR a été supprimé manuellement.

## FINAL : Clean resources and trigger pipeline
Toutes les ressources AWS ont été supprimées.
Le pipeline va tout recréer automatiquement.

## ✅ FINAL : All resources destroyed
Toutes les ressources AWS ont été supprimées avec succès.
