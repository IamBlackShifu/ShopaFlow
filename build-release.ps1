# ShopaFlow - Quick Icon Generator and Build Script
# This script helps you set up the app icon and build for release

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  ShopaFlow Play Store Deployment Tool" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Check if icon exists
$iconPath = "assets\icon\icon.png"
if (-Not (Test-Path $iconPath)) {
    Write-Host "❌ App icon not found at: $iconPath" -ForegroundColor Red
    Write-Host "`nPlease do ONE of the following:" -ForegroundColor Yellow
    Write-Host "1. Place your 1024x1024 PNG icon at: assets\icon\icon.png" -ForegroundColor White
    Write-Host "2. Use online tools:" -ForegroundColor White
    Write-Host "   - https://icon.kitchen/ (Flutter icon generator)" -ForegroundColor Gray
    Write-Host "   - https://www.canva.com (Design tool)" -ForegroundColor Gray
    Write-Host "   - https://www.figma.com (Design tool)" -ForegroundColor Gray
    Write-Host "`nAfter creating the icon, run this script again.`n" -ForegroundColor Yellow
    
    $create = Read-Host "Would you like to create a temporary placeholder icon? (y/n)"
    if ($create -eq "y") {
        Write-Host "Creating placeholder icon..." -ForegroundColor Yellow
        # Note: This requires ImageMagick or similar tool
        Write-Host "⚠️  Manual icon creation recommended for production!" -ForegroundColor Yellow
    }
    exit
}

Write-Host "✅ Found app icon at: $iconPath" -ForegroundColor Green

# Generate launcher icons
Write-Host "`n📱 Generating launcher icons..." -ForegroundColor Cyan
flutter pub run flutter_launcher_icons

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to generate icons" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Launcher icons generated successfully" -ForegroundColor Green

# Ask what to build
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Select build type:" -ForegroundColor Cyan
Write-Host "1. APK (for testing on devices)" -ForegroundColor White
Write-Host "2. App Bundle (for Google Play Store)" -ForegroundColor White
Write-Host "3. Both" -ForegroundColor White
Write-Host "4. Skip build (icon generation only)" -ForegroundColor White
Write-Host "========================================`n" -ForegroundColor Cyan

$choice = Read-Host "Enter choice (1-4)"

function Build-APK {
    Write-Host "`n🔨 Building release APK..." -ForegroundColor Cyan
    flutter build apk --release
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ APK built successfully!" -ForegroundColor Green
        Write-Host "📦 Location: build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor White
        
        $size = (Get-Item "build\app\outputs\flutter-apk\app-release.apk").Length / 1MB
        Write-Host ("📊 Size: {0:N2} MB" -f $size) -ForegroundColor White
    } else {
        Write-Host "❌ APK build failed" -ForegroundColor Red
        return $false
    }
    return $true
}

function Build-AppBundle {
    Write-Host "`n🔨 Building release App Bundle..." -ForegroundColor Cyan
    flutter build appbundle --release
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ App Bundle built successfully!" -ForegroundColor Green
        Write-Host "📦 Location: build\app\outputs\bundle\release\app-release.aab" -ForegroundColor White
        
        $size = (Get-Item "build\app\outputs\bundle\release\app-release.aab").Length / 1MB
        Write-Host ("📊 Size: {0:N2} MB" -f $size) -ForegroundColor White
    } else {
        Write-Host "❌ App Bundle build failed" -ForegroundColor Red
        return $false
    }
    return $true
}

switch ($choice) {
    "1" {
        Build-APK
    }
    "2" {
        Build-AppBundle
    }
    "3" {
        $apkSuccess = Build-APK
        if ($apkSuccess) {
            Build-AppBundle
        }
    }
    "4" {
        Write-Host "✅ Icon generation complete. Skipping build." -ForegroundColor Green
    }
    default {
        Write-Host "❌ Invalid choice" -ForegroundColor Red
        exit 1
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  📋 Next Steps for Play Store:" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "1. Take screenshots of your app (2-8 images)" -ForegroundColor White
Write-Host "2. Create feature graphic (1024x500 px)" -ForegroundColor White
Write-Host "3. Write store description" -ForegroundColor White
Write-Host "4. Create/host privacy policy" -ForegroundColor White
Write-Host "5. Go to https://play.google.com/console" -ForegroundColor White
Write-Host "6. Upload app bundle and complete listing" -ForegroundColor White
Write-Host "`n📖 See PLAYSTORE_DEPLOYMENT.md for detailed guide" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Cyan
