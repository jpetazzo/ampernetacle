# [Official documentation](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/terraformproviderconfiguration.htm)

We can use two authentication options: 

## 1. API Key Authentication (default) 

[Generate API Signing Key](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/apisigningkey.htm#two) 

or [Upload the Public Key](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/apisigningkey.htm#three)

Copy config file from page "Configuration file preview" into your `~/.oci/config` file.
```bash
[DEFAULT]
user=ocid1.user.oc1..aaaaaaa*******************
fingerprint=fc:73:05:0e:***********************
tenancy=ocid1.tenancy.oc1..aaaaaaaaihi*********
region=il-jerusalem-1
key_file=<path to your private keyfile> (Generated or downloaded from Oracle Cloud)
```
If need add another accounts, replace [DEFAULT] to your profile name.

Configure provider:
```bash
provider "oci" {
  tenancy_ocid = <tenancy_ocid> # Can get from config ~/.oci/config
  config_file_profile = "DEFAULT" # Or another profile name 
}
```

## 2. [Security Token Authentication](https://developer.hashicorp.com/terraform/tutorials/oci-get-started/oci-build?in=terraform%2Foci-get-started)

```bash
oci session authenticate
```
- Follow the prompts to enter the region where you have OCI tenancy (Israel - 32). 
- A browser window automatically opens and prompts you for your OCI user name and password. 
- Enter them and click the "Sign In" button. Then return to your terminal. 
- It displays a success message, which means that you have configured the OCI CLI with a default profile.
- After first run will be create file ~/.oci/config and token with DEFAULT profile, all next runs ask name of profile and add additional profiles into config file and tokens.
- The token has a 1-hour Time To Live (TTL). If it expires, refresh it by providing the profile name.
```bash
oci session refresh --profile <profile-name>
```

Configure provider:
```bash
provider "oci" {
  region              = region=il-jerusalem-1
  auth                = "SecurityToken"
  config_file_profile = <profile> # Name of profile 
}
```
