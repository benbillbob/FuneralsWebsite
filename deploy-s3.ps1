param(
    [string]$BucketName = "funeralsingerssydney.au",
    [string]$SiteDir = "funeral",
    [string]$Profile,
    [string]$Region,
    [switch]$ApplyBucketPolicy
)

$ErrorActionPreference = "Stop"

function Invoke-Aws {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Args
    )

    $fullArgs = @($Args)

    if ($Profile) {
        $fullArgs += @("--profile", $Profile)
    }

    if ($Region) {
        $fullArgs += @("--region", $Region)
    }

    Write-Host "> aws $($fullArgs -join ' ')" -ForegroundColor DarkGray
    & aws @fullArgs

    if ($LASTEXITCODE -ne 0) {
        throw "AWS CLI command failed: aws $($fullArgs -join ' ')"
    }
}

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    throw "AWS CLI is not installed or not on PATH. Install it first: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
}

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$resolvedSiteDir = Join-Path $repoRoot $SiteDir
$policyFile = Join-Path $repoRoot "bucket-policy.json"

if (-not (Test-Path $resolvedSiteDir)) {
    throw "Site directory not found: $resolvedSiteDir"
}

Write-Host "Deploying '$resolvedSiteDir' to s3://$BucketName ..." -ForegroundColor Cyan
Invoke-Aws -Args @("s3", "sync", $resolvedSiteDir, "s3://$BucketName", "--delete")

Write-Host "Setting static website index/error documents ..." -ForegroundColor Cyan
Invoke-Aws -Args @("s3", "website", "s3://$BucketName", "--index-document", "index.html", "--error-document", "error.html")

if ($ApplyBucketPolicy) {
    if (-not (Test-Path $policyFile)) {
        throw "bucket-policy.json not found at: $policyFile"
    }

    Write-Host "Applying bucket policy from bucket-policy.json ..." -ForegroundColor Cyan
    Invoke-Aws -Args @("s3api", "put-bucket-policy", "--bucket", $BucketName, "--policy", "file://$policyFile")
}

Write-Host "Deployment complete." -ForegroundColor Green
Write-Host "If website hosting is enabled for this bucket, URL format is:" -ForegroundColor Green
Write-Host "http://$BucketName.s3-website-<region>.amazonaws.com" -ForegroundColor Green
