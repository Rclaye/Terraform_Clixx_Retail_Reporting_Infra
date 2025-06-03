resource "aws_inspector_resource_group" "clixx_res" {
  tags = {
    Name = "clixx-asg-instance"
    Env  = "prod"
  }
  depends_on = [aws_autoscaling_group.clixx_asg]
}

resource "aws_inspector_assessment_target" "clixx_assessment" {
  name               = "Clixx Hardening Assessment"
  resource_group_arn = aws_inspector_resource_group.clixx_res.arn
}

resource "aws_inspector_assessment_template" "clixx_hardening_rules" {
  name       = "clixx_hardening_rules"
  target_arn = aws_inspector_assessment_target.clixx_assessment.arn
  duration   = 3600
  
  rules_package_arns = [
    "arn:aws:inspector:us-east-1:316112463485:rulespackage/0-gEjTy7T7",
    "arn:aws:inspector:us-east-1:316112463485:rulespackage/0-rExsr2X8",
    "arn:aws:inspector:us-east-1:316112463485:rulespackage/0-R01qwB5Q",
    "arn:aws:inspector:us-east-1:316112463485:rulespackage/0-gBONHN9h",
  ]
}

output "assessment_template_arn" {
  value = aws_inspector_assessment_template.clixx_hardening_rules.arn
}
