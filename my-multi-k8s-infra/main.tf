# 1. יצירת רשת (VPC) מאובטחת
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "multi-k8s-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true # נדרש כדי ש-Fargate יוכל למשוך אימג'ים מהאינטרנט
  single_nat_gateway = true # חוסך עלויות (FinOps!) כי לא צריך NAT לכל Zone
}

# 2. יצירת ה-EKS במצב Fargate (Serverless)
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "18.31.0" # הגרסה היציבה

  cluster_name    = "multi-k8s-cluster"
  cluster_version = "1.29"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # הגדרת Fargate בגרסה 18
  fargate_profiles = {
    default = {
      name = "default"
      selectors = [
        { namespace = "default" },
        { namespace = "kube-system" }
      ]
    }
  }
}

module "lb_controller_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "~> 5.0"

  create_role      = true
  role_name        = "AmazonEKSLoadBalancerControllerRole"
  
  # מחבר את ה-Role לקלאסטר שלך דרך ה"תעודת זהות" (OIDC)
  provider_url     = module.eks.oidc_provider 

  # כאן אנחנו מחברים את ה-Policy שיצרת ידנית בשלב 1
  # שים לב: תחליף את ה-ACCOUNT_ID במספר החשבון שלך
  role_policy_arns = ["arn:aws:iam::650251704539:policy/AWSLoadBalancerControllerIAMPolicy"]

  # אבטחה: רק הקונטרולר בתוך הקלאסטר רשאי להשתמש בזה
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
}