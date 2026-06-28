# Ambilight Hue Control

A tvOS application that provides simple control over Philips TV ambilight functionality through Hue integration.

## Features

- **Simple Control Interface**: Toggle ambilight on/off with intuitive buttons
- **Visual Feedback**: Dynamic gradient background when ambilight is active
- **Secure Pairing**: Complete TV pairing workflow with PIN-based authentication
- **Settings Management**: Configure TV connection and reset pairing as needed
- **Real-time State**: Automatically syncs with current TV ambilight status

## Screenshots

The app features a clean interface with:
- Main control buttons for On/Off switching
- Settings gear icon for configuration
- Colorful gradient background when ambilight is enabled
- Configuration prompts for first-time setup

## Requirements

- **Platform**: tvOS 17.5+
- **Development**: Xcode with Swift 5+
- **Hardware**: Philips TV with ambilight support and network connectivity

## Installation

### For Development

1. Clone the repository
2. Install dependencies:
   ```bash
   pod install
   ```
3. Open `ambilighthue.xcworkspace` in Xcode
4. Build and run on tvOS Simulator or Apple TV device

### For Users

1. Install the app on your Apple TV
2. Launch the app
3. Follow the pairing setup to connect to your Philips TV
4. Enter the PIN displayed on your TV screen
5. Start controlling your ambilight!

## Setup & Pairing

The app uses Philips TV's built-in API for secure communication:

1. **Initial Setup**: App prompts for TV configuration on first launch
2. **TV Discovery**: Enter your TV's IP address in settings
3. **Pairing Request**: App sends pairing request to TV
4. **PIN Entry**: Enter the 4-digit PIN shown on your TV screen
5. **Authentication**: App securely stores credentials for future use

## Technical Details

- **Architecture**: SwiftUI with protocol-based design for testability
- **Networking**: Alamofire for HTTP communication with TV API
- **Security**: Digest authentication with custom SSL trust management
- **Storage**: UserDefaults for persistent TV configuration
- **Testing**: Comprehensive unit tests with HTTP mocking

## API Integration

The app communicates with Philips TV API endpoints:
- `/6/pair/request` - Initiate pairing process
- `/6/pair/grant` - Complete pairing with PIN
- `/6/HueLamp/power` - Control ambilight state (GET/POST)

## Development

### Building
```bash
xcodebuild -workspace ambilighthue.xcworkspace -scheme ambilighthue -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)'
```

### Testing
```bash
xcodebuild test -workspace ambilighthue.xcworkspace -scheme ambilighthue -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)'
```

### Dependencies
- **Alamofire**: HTTP networking
- **ViewInspector**: SwiftUI testing (test target only)

## Troubleshooting

**App shows "TV not configured"**
- Ensure your Philips TV is on the same network
- Check TV's IP address in network settings
- Verify TV supports API access (newer models)

**Pairing fails**
- Make sure TV displays the PIN prompt
- Enter PIN quickly (60-second timeout)
- Restart both app and TV if needed

**Controls don't work**
- Check network connectivity
- Try resetting pairing in settings
- Verify ambilight is enabled in TV settings

## Contributing

The project uses:
- Protocol-based architecture for clean separation of concerns
- Comprehensive unit testing with mocking
- SwiftUI best practices for tvOS development

## License

This project is available for personal use and development.