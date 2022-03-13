resource "oci_core_vcn" "_" {
  compartment_id = local.compartment_id
  cidr_block     = "10.0.0.0/16"
}

resource "oci_core_internet_gateway" "_" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn._.id
}

resource "oci_core_default_route_table" "_" {
  manage_default_resource_id = oci_core_vcn._.default_route_table_id
  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway._.id
  }
}

resource "oci_core_default_security_list" "_" {
  manage_default_resource_id = oci_core_vcn._.default_security_list_id

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  ingress_security_rules {
    description = "allow inbound ssh traffic"
    protocol    = "6" // tcp
    source      = "0.0.0.0/0"
    stateless   = false

    tcp_options {
      min = 22
      max = 22
    }
  }

  ingress_security_rules {
    description = "allow inbound http traffic"
    protocol    = "6" // tcp
    source      = "0.0.0.0/0"
    stateless   = false

    tcp_options {
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    description = "allow all inbound from client ip"
    protocol    = "all"
    source      = "${local.ifconfig_co_json.ip_addr}/32"
  }

  ingress_security_rules {
    stateless   = false
    source      = "10.0.0.0/16"
    source_type = "CIDR_BLOCK"
    # Get protocol numbers from https://www.iana.org/assignments/protocol-numbers/protocol-numbers.xhtml TCP is 6
    protocol = "6"
  }
}

resource "oci_core_subnet" "_" {
  compartment_id    = local.compartment_id
  cidr_block        = "10.0.0.0/24"
  vcn_id            = oci_core_vcn._.id
  route_table_id    = oci_core_default_route_table._.id
  security_list_ids = [oci_core_default_security_list._.id]
}
