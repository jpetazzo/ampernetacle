param(
    [Parameter()]
    [String]$address
)
$url  =  "https://$($address):6443"

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
Start-Sleep -Seconds 5
while ( -not (Invoke-WebRequest $url)){ Start-Sleep -Seconds 1 }
Start-Sleep -Seconds 5