# create a resource group if it doesn't exist
resource "azurerm_resource_group" "demoterraform" {
  name     = "${var.terraform_resource_group}"
  location = "${var.terraform_azure_region}"
}

# create virtual network
resource "azurerm_virtual_network" "demoterraformnetwork" {
  name                = "tfvn"
  address_space       = ["10.0.0.0/16"]
  location            = "${var.terraform_azure_region}"
  resource_group_name = "${azurerm_resource_group.demoterraform.name}"
}

# create subnet
resource "azurerm_subnet" "demoterraformsubnet" {
  name                 = "tfsub"
  resource_group_name  = "${azurerm_resource_group.demoterraform.name}"
  virtual_network_name = "${azurerm_virtual_network.demoterraformnetwork.name}"
  address_prefix       = "10.0.2.0/24"
}

# create public IPs
resource "azurerm_public_ip" "demoterraformips" {
  name                         = "demoterraformip"
  location                     = "${var.terraform_azure_region}"
  resource_group_name          = "${azurerm_resource_group.demoterraform.name}"
  public_ip_address_allocation = "static"
  domain_name_label            = "${azurerm_resource_group.demoterraform.name}"

  tags {
    environment = "TerraformDemo"
  }
}

# create load balancer
resource "azurerm_lb" "demoterraformlb" {
  name                = "demoterraformlb"
  location            = "${var.terraform_azure_region}"
  resource_group_name = "${azurerm_resource_group.demoterraform.name}"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = "${azurerm_public_ip.demoterraformips.id}"
  }
}

resource "azurerm_lb_backend_address_pool" "bpepool" {
  resource_group_name = "${azurerm_resource_group.demoterraform.name}"
  loadbalancer_id     = "${azurerm_lb.demoterraformlb.id}"
  name                = "BackEndAddressPool"
}

resource "azurerm_lb_nat_pool" "lbnatpool" {
  count = "${var.terraform_vmss_count}"
  resource_group_name = "${azurerm_resource_group.demoterraform.name}"
  name                           = "ssh"
  loadbalancer_id                = "${azurerm_lb.demoterraformlb.id}"
  protocol                       = "Tcp"
  frontend_port_start            = 50000
  frontend_port_end              = 50119
  backend_port                   = 22
  frontend_ip_configuration_name = "PublicIPAddress"
}

# create virtual machine
resource "azurerm_virtual_machine_scale_set" "demoterraformvm" {
  name                  = "terraformvm"
  location              = "${var.terraform_azure_region}"
  resource_group_name   = "${azurerm_resource_group.demoterraform.name}"
  upgrade_policy_mode = "Manual"

  sku {
    name     = "Standard_A0"
    tier     = "Standard"
    capacity = "${var.terraform_vmss_count}"
  }

  storage_image_reference {
    publisher = "CoreOS"
    offer     = "CoreOS"
    sku       = "Stable"
    version   = "latest"
  }

  storage_os_disk {
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name_prefix = "core"
    admin_username = "core"
    admin_password = "Password1234"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  network_profile {
    name    = "terraformnetworkprofile"
    primary = true

    ip_configuration {
      name      = "TestIPConfiguration"
      subnet_id = "${azurerm_subnet.demoterraformsubnet.id}"
      load_balancer_backend_address_pool_ids = ["${azurerm_lb_backend_address_pool.bpepool.id}"]
      load_balancer_inbound_nat_rules_ids = ["${element(azurerm_lb_nat_pool.lbnatpool.*.id, count.index)}"]
    }
  }

  tags {
    environment = "staging"
  }
}