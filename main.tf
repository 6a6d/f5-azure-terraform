# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    # keepers = {
    #     # Generate a new ID only when a new resource group is defined
    #     resource_group = azurerm_resource_group.resourcegroup.name
    # }

    byte_length = 2
}

# Create a Resource Group for the new Virtual Machine
resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}_rg"
  location = var.location
}

# Create a Virtual Network within the Resource Group
resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = [var.cidr]
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

# Create the first Subnet within the Virtual Network
resource "azurerm_subnet" "Mgmt" {
  name                 = "Mgmt"
  virtual_network_name = azurerm_virtual_network.main.name
  resource_group_name  = azurerm_resource_group.main.name
  address_prefix       = var.subnets["subnet1"]
}

# Create the second Subnet within the Virtual Network
resource "azurerm_subnet" "External" {
  name                 = "External"
  virtual_network_name = azurerm_virtual_network.main.name
  resource_group_name  = azurerm_resource_group.main.name
  address_prefix       = var.subnets["subnet2"]
}

# Obtain Gateway IP for each Subnet
locals {
  depends_on = ["azurerm_subnet.Mgmt", "azurerm_subnet.External"]
  mgmt_gw    = cidrhost(azurerm_subnet.Mgmt.address_prefix, 1)
  ext_gw     = cidrhost(azurerm_subnet.External.address_prefix, 1)
}



resource "azurerm_public_ip" "lbpip" {
  name                = "${var.prefix}-lb-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Dynamic"
  domain_name_label   = "${var.prefix}lbpip"
}

# Create Availability Set
resource "azurerm_availability_set" "avset" {
  name                         = "${var.prefix}avset"
  location                     = azurerm_resource_group.main.location
  resource_group_name          = azurerm_resource_group.main.name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true
}

# Create Azure LB
resource "azurerm_lb" "lb" {
  name                = "${var.prefix}lb"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  frontend_ip_configuration {
    name                 = "LoadBalancerFrontEnd"
    public_ip_address_id = azurerm_public_ip.lbpip.id
  }
}

resource "azurerm_lb_backend_address_pool" "backend_pool" {
  name                = "BackendPool1"
  resource_group_name = azurerm_resource_group.main.name
  loadbalancer_id     = azurerm_lb.lb.id
}

resource "azurerm_lb_probe" "lb_probe" {
  resource_group_name = azurerm_resource_group.main.name
  loadbalancer_id     = azurerm_lb.lb.id
  name                = "tcpProbe"
  protocol            = "tcp"
  port                = 8443
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "lb_rule" {
  name                           = "LBRule"
  resource_group_name            = azurerm_resource_group.main.name
  loadbalancer_id                = azurerm_lb.lb.id
  protocol                       = "tcp"
  frontend_port                  = 443
  backend_port                   = 8443
  frontend_ip_configuration_name = "LoadBalancerFrontEnd"
  enable_floating_ip             = false
  backend_address_pool_id        = azurerm_lb_backend_address_pool.backend_pool.id
  idle_timeout_in_minutes        = 5
  probe_id                       = azurerm_lb_probe.lb_probe.id
  depends_on                     = [azurerm_lb_probe.lb_probe]
}

# Create a Network Security Group with some rules
resource "azurerm_network_security_group" "main" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "allow_SSH"
    description                = "Allow SSH access"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_HTTP"
    description                = "Allow HTTP access"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_HTTPS"
    description                = "Allow HTTPS access"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_RDP"
    description                = "Allow RDP access"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_APP_HTTPS"
    description                = "Allow HTTPS access"
    priority                   = 140
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Name        = "${var.environment}-bigip-sg"
    environment = var.environment
    owner       = var.owner
    group       = var.group
    costcenter  = var.costcenter
    application = var.application
  }
}

# Create the first network interface card for Management
resource "azurerm_network_interface" "vm03-mgmt-nic" {
  name                      = "${var.prefix}-vm03-mgmt-nic"
  location                  = azurerm_resource_group.main.location
  resource_group_name       = azurerm_resource_group.main.name
  #network_security_group_id = azurerm_network_security_group.main.id

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.Mgmt.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.f5vm03mgmt
    public_ip_address_id          = azurerm_public_ip.vm03mgmtpip.id
  }

  tags = {
    Name        = "${var.environment}-vm03-mgmt-int"
    environment = var.environment
    owner       = var.owner
    group       = var.group
    costcenter  = var.costcenter
    application = var.application
  }
}



resource "azurerm_network_interface" "backend01-ext-nic" {
  name                      = "${var.prefix}-backend01-ext-nic"
  location                  = azurerm_resource_group.main.location
  resource_group_name       = azurerm_resource_group.main.name
  #network_security_group_id = azurerm_network_security_group.main.id

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.External.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.backend01ext
    primary                       = true
  }

  tags = {
    Name        = "${var.environment}-backend01-ext-int"
    environment = var.environment
    owner       = var.owner
    group       = var.group
    costcenter  = var.costcenter
    application = "app1"
  }
}

# Associate the Network Interface to the BackendPool
resource "azurerm_network_interface_backend_address_pool_association" "bpool_assc_vm01" {
  depends_on = [
    azurerm_lb_backend_address_pool.backend_pool,
    azurerm_network_interface.vm01-ext-nic,
  ]
  network_interface_id    = azurerm_network_interface.vm01-ext-nic.id
  ip_configuration_name   = "secondary"
  backend_address_pool_id = azurerm_lb_backend_address_pool.backend_pool.id
}

resource "azurerm_network_interface_backend_address_pool_association" "bpool_assc_vm02" {
  depends_on = [
    azurerm_lb_backend_address_pool.backend_pool,
    azurerm_network_interface.vm02-ext-nic,
  ]
  network_interface_id    = azurerm_network_interface.vm02-ext-nic.id
  ip_configuration_name   = "secondary"
  backend_address_pool_id = azurerm_lb_backend_address_pool.backend_pool.id
}

# Setup Onboarding scripts
data "template_file" "vm_onboard" {
  template = file("${path.module}/onboard.tpl")

  vars = {
    uname          = var.uname
    upassword      = var.upassword
    DO_URL         = var.DO_URL
    AS3_URL        = var.AS3_URL
    TS_URL         = var.TS_URL
    libs_dir       = var.libs_dir
    onboard_log    = var.onboard_log
  }
}



## OUTPUTS ###
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