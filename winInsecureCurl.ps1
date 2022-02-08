add-type @"
    using System.Net; 
    using System.Security.Cryptography.X509Certificates; 
    public class TrustAllCertsPolicy : ICertificatePolicy { 
        public bool CheckValidationResult( 
            ServicePoint srvPoint, X509Certificate certificate, 
            WebRequest request, int certificateProblem) { 
            return true; 
        } 
    } 
"@ 
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy 
while ( -not (Invoke-WebRequest -uri https://${oci_core_instance._[1].public_ip}:6443)){ Start-Sleep 1 }