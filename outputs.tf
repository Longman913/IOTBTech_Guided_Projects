output "vpc_id" {
  value = aws_vpc.main.id
}
output "public_subnet_id" {
  value = aws_subnet.public.id
}
output "master_public_ip" {
  value = aws_instance.linux.public_ip
}
output "managed_public_ip" {
  value = aws_instance.linux2.public_ip
}
