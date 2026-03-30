resource "aws_ecr_repository" "client" {
  name                 = "multi-client"
  force_delete         = true # מאפשר ל-Terraform למחוק את ה-Repo גם אם יש בו אימג'ים (נוח ללמידה)
}

resource "aws_ecr_repository" "server" {
  name                 = "multi-server"
  force_delete         = true
}

resource "aws_ecr_repository" "worker" {
  name                 = "multi-worker"
  force_delete         = true
}
