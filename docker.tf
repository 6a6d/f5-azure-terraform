# Docker VM for pool members
resource "azurerm_virtual_machine" "backendvm" {
    name                  = "backendvm"
    location              = azurerm_resource_group.main.location
    resource_group_name   = azurerm_resource_group.main.name
    network_interface_ids = [azurerm_network_interface.backend01-ext-nic.id]
    vm_size               = "Standard_DS1_v2"

    storage_os_disk {
        name              = "backendOsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04.0-LTS"
        version   = "latest"
    }

    os_profile {
        computer_name  = "backend01"
        admin_username = "azureuser"
        admin_password = var.upassword
        custom_data    = <<-EOF
            #!/bin/bash
            apt-get update -y
            apt-get install -y docker.io
            docker run -d -p 80:80 --net=host --restart unless-stopped -e F5DEMO_APP=website -e F5DEMO_NODENAME='F5 Azure' -e F5DEMO_COLOR=ffd734 -e F5DEMO_NODENAME_SSL='F5 Azure (SSL)' -e F5DEMO_COLOR_SSL=a0bf37 chen23/f5-demo-app:ssl
        EOF
    }

    os_profile_linux_config {
        disable_password_authentication = false
    }

    tags = {
        Name        = "${var.environment}-backend01"
        environment = var.environment
        owner       = var.owner
        group       = var.group
        costcenter  = var.costcenter
        application = var.application
    }
}