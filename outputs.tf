output "instance_id" {
  value = aws_instance.dev.id
}
output "root_volume_id" {
  value = aws_instance.dev.root_block_device[0].volume_id
}
output "ssh_host" {
  value = var.name
}
output "ssm_command" {
  value = "aws ssm start-session --profile ${var.aws_profile} --region ${var.region} --target ${aws_instance.dev.id}"
}
