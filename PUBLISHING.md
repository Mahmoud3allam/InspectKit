# Publishing InspectKit to Swift Package Manager

## Step-by-Step Guide

### 1. Prepare Your Local Repository

First, initialize a git repository if you haven't already:

```bash
cd /path/to/InspectKit
git init
git add .
git commit -m "Initial commit: InspectKit iOS network debugging tool"
```

### 2. Create a GitHub Repository

1. Go to [github.com/new](https://github.com/new)
2. Create a new repository named `InspectKit`
3. **Do NOT initialize with README** (we have one)
4. Copy the repository URL

### 3. Push to GitHub

```bash
# Add remote (replace with your repo URL)
git remote add origin https://github.com/yourusername/InspectKit.git

# Rename branch to main (if needed)
git branch -M main

# Push
git push -u origin main
```

### 4. Create Your First Release

Releases create git tags that SPM uses to resolve versions:

```bash
# Create and push a git tag
git tag -a v1.0.0 -m "Initial release of InspectKit"
git push origin v1.0.0
```

Or create via GitHub UI:
1. Go to your repo
2. Click **Releases** → **Create a new release**
3. Set tag to `v1.0.0`
4. Set title to "InspectKit 1.0.0"
5. Add release notes describing features
6. Click **Publish release**

### 5. Test SPM Resolution (Optional but Recommended)

Create a test project to verify your package resolves correctly:

```bash
# Create a test app
mkdir -p ~/TestInspectKit
cd ~/TestInspectKit
swift package init --type app

# Edit Package.swift, add dependency:
# .package(url: "https://github.com/yourusername/InspectKit.git", from: "1.0.0")

# Try to resolve
swift package resolve
```

Or test in Xcode:
1. Create a new iOS project
2. File → Add Packages
3. Paste: `https://github.com/yourusername/InspectKit.git`
4. Select "v1.0.0" and add to your app target

### 6. Submit to Swift Package Index (Optional)

Make your package more discoverable:

1. Visit [swiftpackageindex.com](https://swiftpackageindex.com)
2. Click "Add a package"
3. Paste your GitHub URL
4. Optionally add keywords, description, etc.

This generates nice documentation and makes your package easier to find.

## Version Management

### Semantic Versioning

Follow [semantic versioning](https://semver.org/):
- `v1.0.0` — initial release
- `v1.1.0` — new features, backward compatible
- `v1.0.1` — bug fixes
- `v2.0.0` — breaking changes

### Creating Updates

After making changes:

```bash
git add .
git commit -m "Description of changes"
git tag -a v1.1.0 -m "Add support for custom configuration"
git push origin main
git push origin v1.1.0
```

## Best Practices

### Documentation
- ✅ Keep README.md up to date
- ✅ Include installation instructions
- ✅ Provide usage examples
- ✅ Document breaking changes in release notes

### Code Quality
- ✅ Test on multiple iOS versions (13.0+)
- ✅ Ensure no warnings in compilation
- ✅ Keep public API minimal and clear
- ✅ Use meaningful type names (e.g., `InspectKit` not `Inspector`)

### Maintenance
- ✅ Monitor issues and discussions
- ✅ Respond to pull requests
- ✅ Keep dependencies minimal
- ✅ Document workarounds for iOS limitations

## Troubleshooting

### "Package resolution failed"
- Verify `Package.swift` is at root level
- Check that git tag is in format `vX.Y.Z`
- Ensure your Repository is public on GitHub

### "Target not found"
- Verify source files are in `Sources/InspectKit/`
- Check that `.target()` path matches directory structure
- Run `swift package describe` to validate

### "Module not found" in Xcode
- Clear build cache: ⌘+Shift+K
- Clear Derived Data: `rm -rf ~/Library/Developer/Xcode/DerivedData/*`
- Re-add the package dependency

## After Publishing

### Monitor Usage
- Watch for issues and bug reports
- Track number of dependents on GitHub
- Monitor Swift Package Index statistics

### Keep it Updated
- Fix bugs promptly
- Add features based on feedback
- Stay compatible with new iOS versions
- Update dependencies regularly

### Consider These Enhancements
- Add unit tests (create `Tests/` directory)
- Set up CI/CD pipeline (GitHub Actions)
- Add more granular documentation
- Create demo app (separate repo or folder)

## Quick Reference

```bash
# See current tags
git tag

# Delete a tag locally
git tag -d v1.0.0

# Delete a tag remotely
git push origin --delete v1.0.0

# Update package index manually
# (Visit swiftpackageindex.com/add-package)
```

## Next Steps

1. ✅ Create GitHub repo
2. ✅ Push code
3. ✅ Create v1.0.0 release
4. ✅ Test with a demo app
5. ✅ Submit to Swift Package Index
6. ✅ Share with iOS community!

Happy publishing! 🚀
