data "azurerm_public_ip" "vm01mgmtpip" {
    name                = azurerm_public_ip.vm01mgmtpip.name
    resource_group_name = azurerm_resource_group.main.name
    depends_on          = [azurerm_virtual_machine_extension.f5vm01-run-startup-cmd]
}

data "azurerm_public_ip" "vm02mgmtpip" {
    name                = azurerm_public_ip.vm02mgmtpip.name
    resource_group_name = azurerm_resource_group.main.name
    depends_on          = [azurerm_virtual_machine_extension.f5vm02-run-startup-cmd]
}

data "azurerm_public_ip" "lbpip" {
    name                = azurerm_public_ip.lbpip.name
    resource_group_name = azurerm_resource_group.main.name
    depends_on          = [azurerm_virtual_machine_extension.f5vm02-run-startup-cmd]
}

output "sg_id" {
    value = azurerm_network_security_group.main.id
}

output "sg_name" {
    value = azurerm_network_security_group.main.name
}

output "mgmt_subnet_gw" {
    value = local.mgmt_gw
}

output "ext_subnet_gw" {
    value = local.ext_gw
}

output "ALB_app1_pip" {
    value = data.azurerm_public_ip.lbpip.ip_address
}

output "f5vm01_id" {
    value = azurerm_virtual_machine.f5vm01.id
}

output "f5vm01_mgmt_private_ip" {
    value = azurerm_network_interface.vm01-mgmt-nic.private_ip_address
}

output "f5vm01_mgmt_public_ip" {
    value = data.azurerm_public_ip.vm01mgmtpip.ip_address
}

output "f5vm01_ext_private_ip" {
    value = azurerm_network_interface.vm01-ext-nic.private_ip_address
}

output "f5vm02_id" {
    value = azurerm_virtual_machine.f5vm02.id
}

output "f5vm02_mgmt_private_ip" {
    value = azurerm_network_interface.vm02-mgmt-nic.private_ip_address
}

output "f5vm02_mgmt_public_ip" {
    value = data.azurerm_public_ip.vm02mgmtpip.ip_address
}

output "f5vm02_ext_private_ip" {
    value = azurerm_network_interface.vm02-ext-nic.private_ip_address
}

output "jumpbox_ip" {
    value = azurerm_public_ip.jb_public_ip[*].ip_address
}

output "controller_ip" {
    value = azurerm_public_ip.controller_public_ip[*].ip_address
}

output "docker_ip" {
    value = azurerm_public_ip.docker_public_ip[*].ip_address
}