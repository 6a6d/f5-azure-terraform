# Create virtual machine
resource "azurerm_virtual_machine" "jumpbox" {
    count                 = length(var.azs)
    name                  = format("%s-jumpbox-%s-%s",var.prefix,count.index,random_id.randomId.hex)
    location              = azurerm_resource_group.main.location
    resource_group_name   = azurerm_resource_group.main.name
    network_interface_ids = [azurerm_network_interface.jb_nic[count.index].id]
    vm_size               = "Standard_DS1_v2"
    zones                 = [element(var.azs,count.index)]

    # Uncomment this line to delete the OS disk automatically when deleting the VM
    # if this is set to false there are behaviors that will require manual intervention
    # if tainting the virtual machine
    delete_os_disk_on_termination = true

    # Uncomment this line to delete the data disks automatically when deleting the VM
    delete_data_disks_on_termination = true
    storage_os_disk {
        name              = format("%s-jumpbox-%s-%s",var.prefix,count.index,random_id.randomId.hex)
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    os_profile {
        computer_name  = format("%s-jumpbox-%s-%s",var.prefix,count.index,random_id.randomId.hex)
        admin_username = "azureuser"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/azureuser/.ssh/authorized_keys"
            key_data = file(var.publickeyfile)
        }
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
    }

    tags = {
        environment = var.environment
    }
}

# Create network interface
resource "azurerm_network_interface" "jb_nic" {
    count                     = length(var.azs)
    name                      = format("%s-jb-nic-%s-%s",var.prefix,count.index,random_id.randomId.hex)
    location                  = azurerm_resource_group.main.location
    resource_group_name       = azurerm_resource_group.main.name
    network_security_group_id = azurerm_network_security_group.jb_sg.id

    ip_configuration {
        name                          = format("%s-jb-nic-%s-%s",var.prefix,count.index,random_id.randomId.hex)
        subnet_id                     = azurerm_subnet.public[count.index].id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.jb_public_ip[count.index].id
    }

    tags = {
        environment = var.environment
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "jb_sg" {
    name                = format("%s-jb_sg-%s",var.prefix,random_id.randomId.hex)
    location            = azurerm_resource_group.main.location
    resource_group_name = azurerm_resource_group.main.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = var.environment
    }
}


# Create public IPs
resource "azurerm_public_ip" "jb_public_ip" {
    count               = length(var.azs)
    name                = format("%s-jb-%s-%s",var.prefix,count.index,random_id.randomId.hex)
    location            = azurerm_resource_group.main.location
    resource_group_name = azurerm_resource_group.main.name
    allocation_method   = "Static" # Static is required due to the use of the Standard sku
    sku                 = "Standard" # the Standard sku is required due to the use of availability zones
    zones               = [element(var.azs,count.index)]

    tags = {
        environment = var.environment
    }
}
