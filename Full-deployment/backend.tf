terraform{
    backend "s3"{
        bucket= "stackbuckstate-rclaye"
        key = "terraform.tfsate"
        region="us-east-1"
        }
}