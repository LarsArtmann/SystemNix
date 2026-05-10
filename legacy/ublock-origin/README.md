# uBlock Origin Configuration

This directory contains uBlock Origin browser extension configuration and automation.

## Structure

- `filters/` - Custom filter lists and rules
- `backup/` - Backup of extension settings
- `extensions/` - Extension installation metadata
- `install-guides/` - Browser-specific installation instructions

## Automation Features

1. **Custom Filter Management**: Automatically maintains custom filter lists
2. **Browser Detection**: Detects and configures supported browsers
3. **Backup System**: Regular backups of uBlock Origin settings
4. **Update Automation**: Keeps filter lists up to date

## Supported Browsers

- Safari (via extension from App Store)
- Chrome/Chromium
- Firefox
- Microsoft Edge
- Brave Browser

## Manual Installation

For browsers that require manual installation:

1. **Safari**: Install from Mac App Store
2. **Chrome**: Install from Chrome Web Store
3. **Firefox**: Install from Firefox Add-ons
4. **Edge**: Install from Microsoft Edge Add-ons

## Custom Filters

Custom filters are automatically applied and include:

- Enhanced privacy protection
- Social media tracking blockers
- Development-specific ad blockers
- Performance optimization filters

## Restoration

To restore settings on a new system:

```bash
./scripts/ublock-origin-setup.sh --restore
```
