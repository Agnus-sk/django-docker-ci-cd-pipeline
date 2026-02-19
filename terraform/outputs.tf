output "public_ip" {
  description = "Public IP of EC2 instance"
  value       = aws_instance.django_server.public_ip
}
