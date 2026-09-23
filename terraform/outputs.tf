################
resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../ansible/inventory.ini"
  file_permission = "0600"

  content = <<-EOT
    [webservers]
    ${join("\n", aws_instance.app[*].private_ip)}

    [db]
    ${aws_instance.db.private_ip}
  EOT
}

output "alb_dns_name" {
  description = "Public DNS name of the application load balancer."
  value       = aws_lb.app.dns_name
}

output "app_instance_ids" {
  description = "IDs of the two private application instances."
  value       = aws_instance.app[*].id
}

output "db_instance_id" {
  description = "ID of the private database instance."
  value       = aws_instance.db.id
}

output "db_private_ip" {
  description = "Private IP address of the database instance."
  value       = aws_instance.db.private_ip
}

output "ansible_inventory_path" {
  description = "Path to the inventory generated on this computer."
  value       = local_file.ansible_inventory.filename
}
