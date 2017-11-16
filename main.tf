variable "myip" {
     default = "0.0.0.0/0"
}

variable "sshpassword" {
    default = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
}

# Southeast Asia	Singapore
# East Asia	Hong Kong
# Australia East	New South Wales
# Australia Southeast	Victoria
# China East	Shanghai
# China North	Beijing
# Central India	Pune
# West India	Mumbai
# South India	Chennai
# Japan East	Tokyo, Saitama
# Japan West	Osaka
# Korea Central	Seoul
# Korea South	Busan
variable "region" {
    default = "Korea Central"
}


# Configure the Microsoft Azure Provider
provider "azurerm" {
    subscription_id = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    client_id       = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    client_secret   = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    tenant_id       = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "aqibot" {
    name     = "aqibot"
    location = "${var.region}"

    tags {
        environment = "Terraform Aqibot"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "myterraformnetwork" {
    name                = "aqiVnet"
    address_space       = ["10.0.0.0/16"]
    location            = "${var.region}"
    resource_group_name = "${azurerm_resource_group.aqibot.name}"

    tags {
        environment = "Terraform Aqibot"
    }
}

# Create subnet
resource "azurerm_subnet" "myterraformsubnet" {
    name                 = "aqiSubnet"
    resource_group_name  = "${azurerm_resource_group.aqibot.name}"
    virtual_network_name = "${azurerm_virtual_network.myterraformnetwork.name}"
    address_prefix       = "10.0.0.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "myterraformpublicip" {
    name                         = "aqiPublicIP"
    location                     = "${var.region}"
    resource_group_name          = "${azurerm_resource_group.aqibot.name}"
    public_ip_address_allocation = "dynamic"

    tags {
        environment = "Terraform Aqibot"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "myterraformnsg" {
    name                = "aqiNetworkSecurityGroup"
    location            = "${var.region}"
    resource_group_name = "${azurerm_resource_group.aqibot.name}"

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "${var.myip}"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "Outbound"
        priority                   = 999
        direction                   = "Outbound"
        access                      = "Allow"
        protocol                    = "Tcp"
        source_port_range           = "*"
        destination_port_range      = "*"
        source_address_prefix       = "*"
        destination_address_prefix  = "*"
    }

    tags {
        environment = "Terraform Aqibot"
    }
}

# Create network interface
resource "azurerm_network_interface" "myterraformnic" {
    name                      = "aqiNIC"
    location                  = "${var.region}"
    resource_group_name       = "${azurerm_resource_group.aqibot.name}"
    network_security_group_id = "${azurerm_network_security_group.myterraformnsg.id}"

    ip_configuration {
        name                          = "aqiNicConfiguration"
        subnet_id                     = "${azurerm_subnet.myterraformsubnet.id}"
        private_ip_address_allocation = "dynamic"
        public_ip_address_id          = "${azurerm_public_ip.myterraformpublicip.id}"
    }

    tags {
        environment = "Terraform Aqibot"
    }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = "${azurerm_resource_group.aqibot.name}"
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
    name                = "diag${random_id.randomId.hex}"
    resource_group_name = "${azurerm_resource_group.aqibot.name}"
    location            = "${var.region}"
    account_type        = "Standard_LRS"

    tags {
        environment = "Terraform Aqibot"
    }
}

# Create virtual machine
resource "azurerm_virtual_machine" "myterraformvm" {
    name                  = "aqibot"
    location              = "${var.region}"
    resource_group_name   = "${azurerm_resource_group.aqibot.name}"
    network_interface_ids = ["${azurerm_network_interface.myterraformnic.id}"]
    vm_size               = "Basic_A0"

    storage_os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04.0-LTS"
        version   = "latest"
    }

    os_profile {
        computer_name  = "aqibotvm"
        admin_username = "azureuser"
        admin_password = "${var.sshpassword}"
    }

    os_profile_linux_config {
        disable_password_authentication = false
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = "${azurerm_storage_account.mystorageaccount.primary_blob_endpoint}"
    }

    tags {
        environment = "Terraform Aqibot"
    }
}

data "azurerm_public_ip" "datasourceip" { name = "aqiPublicIP" resource_group_name = "${azurerm_virtual_machine.myterraformvm.resource_group_name}" }

resource "null_resource" "init_aqibot" {
    triggers {
        instance = "${azurerm_virtual_machine.myterraformvm.id}"
    }
    connection {
                user = "azureuser"
                password = "${var.sshpassword}"
                host = "${data.azurerm_public_ip.datasourceip.ip_address}"
                type = "ssh"
            }
    provisioner "remote-exec" {
        inline = [
            "sudo apt update",
            "sudo apt-get install -y git python3-pip xdg-utils libxss1 libappindicator1 libindicator7",
            "sudo pip3 install itchat schedule requests python-dateutil",
            "sudo curl -O https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb",
            "sudo dpkg -i google-chrome*.deb",
            "sudo apt-get install -y -f",
            "crontab -l | { cat; echo \"*/3 * * * * sudo google-chrome --headless --disable-gpu --no-sandbox --screenshot http://aqicn.org/forecast/shanghai/cn\"; } | crontab -",
            "sudo git clone https://github.com/lonegunmanb/aqibot.git",
            "cd ~/aqibot"
        ]
    }
}

output "address" {
    value = "${data.azurerm_public_ip.datasourceip.ip_address}"
}
