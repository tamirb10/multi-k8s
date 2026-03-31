module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "multi-k8s-vpc"
  cidr = "10.0.0.0/16"
# תגיות חובה כדי שאמזון תדע איפה להקים את ה-ALB
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true 
}
# זה המודול שמחליף את כל ה-JSON הידני והכאב ראש


module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31" # גרסה חדשה שתומכת ב-Auto Mode

  cluster_name    = "multi-k8s-cluster"
  cluster_version = "1.31"
  cluster_endpoint_public_access = true
  bootstrap_self_managed_addons = false
  create_kms_key              = false
  cluster_encryption_config   = {}
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # הגדרות האוטופיילוט:
  cluster_compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  
  enable_cluster_creator_admin_permissions = true
}


# --- 3. יצירת ה-Role (תעודת הזהות) ---
resource "aws_iam_role" "lb_controller" {
  name = "EKS-LoadBalancer-Role-Auto"

  # יחסי אמון: ה-Role סומך על הקלאסטר (באמצעות ה-OIDC)
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = { Federated = module.eks.oidc_provider_arn }
      Condition = {
        StringEquals = {
          "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })
}

# הצמדת ה"רשימת הרשאות" (Policy) ל-Role
resource "aws_iam_role_policy_attachment" "lb_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy" # הרשאה בסיסית
  role       = aws_iam_role.lb_controller.name
}

# הרשאות ספציפיות ליצירת Load Balancers (החלק הקריטי!)
resource "aws_iam_role_policy" "lbc_extra" {
  name = "LBC-Extra-Permissions"
  role = aws_iam_role.lb_controller.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:DescribeAccountAttributes",
        "ec2:DescribeAddresses",
        "ec2:DescribeInternetGateways",
        "elasticloadbalancing:*"
      ]
      Resource = "*"
    }]
  })
}

# --- 4. ה"דבק" (Access Entry) - החיבור הסופי שמונע לולאה ---
resource "aws_eks_access_entry" "lb_controller" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.lb_controller.arn
  type          = "EC2_LINUX"
}

