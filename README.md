# TextTitles

A [Processing](https://processing.org/)-based application for creating lower-third titles for live video broadcasts using simple text files.

![Screenshot](https://github.com/luminationlabs/TextTitles/blob/main/assets/screenshot.png?raw=true)

## Overview

TextTitles is a powerful yet simple tool designed for live video production environments. It allows operators to quickly display and manage lower-third titles using plain text files, making it perfect for live broadcasts, streams, or presentations.

## Features

- Full-screen display on any connected monitor
- Simple text file-based title management
- Support for multi-line titles with customizable formatting
- Preview of the next title
- JSON configuration for fine-tuned control
- Automatic file monitoring for real-time updates
- Automatic saving of the current title position within each file
- Support for both text and image files
- Smooth transitions between titles (fade or slide)
- Remembers last used directory and settings
- Cross-platform compatibility (Windows, macOS, Linux)

## Requirements

- A multi-monitor setup is recommended so you can control it from one monitor while using the other for presentation (not required for testing)
- Chroma keying (hardware or software) is required to remove the blue background color

## Installation

1. Download the latest release for your operating system from the [releases page](https://github.com/luminationlabs/TextTitles/releases)
2. Extract the archive to your desired location
3. Run the TextTitles application

## Usage

1. Create a folder where you want to store your titles, and fill it with title text files and/or images
2. Launch TextTitles
3. Select the folder with your files
4. Use the "File List" window to select a file
5. Use the left and right arrow keys to navigate between titles within a file.
6. When the "File List" window is active, the up and down arrow keys can be used to navigate between files.

### Configuration Format

When a text file is first opened, it will inherit some default configuration (either from the previously-opened file or application defaults). After moving to a new file or exiting the application, the configuration will be saved to the file as a JSON object at the top of the file. It will look something like this:

```
{
  "textSize": 70,
  "lineHeight": 1.25,
  "secondLineItalics": true,
  "currentIndex": 11,
  "transitionType": "fade",
  "secondLineReduction": 0.25
}

Johnny Appleseed
Technical Director

Jason Bourne
Stunt Coordinator
...
```

These configuration options can be adjusted using a text editor.

## Configuration Options

- textSize: Base font size for the titles (will be scaled down if necessary to fit the screen width)
- secondLineReduction: Amount to reduce the font size of the second line. 0 = no reduction, 0.25 = 25% reduction (75% of textSize)
- secondLineItalics: Boolean to enable/disable italics for second line of text
- lineHeight: Vertical spacing between lines
- transitionType: Animation style for title changes (either "fade" or "slide")

Note: The font size will be scaled down automatically to fit each line within the screen width, but it will **not** be scaled down if too many lines cause the text to vertically overflow the black title area. It's your responsibility to lower the font size for a file if using titles that contain more than 2 lines.

## Building from Source

To edit the application or build locally:

1. Download the latest source release
2. Install Processing 4.3 or later
3. Open the TextTitles.pde file in Processing
4. Click "Run"
5. For a standalone build, choose "Export Application" from the File menu

## License

The MIT License (MIT)

## Support

No support is provided. If you find a bug, you can try opening an issue on GitHub.

Pull requests are welcome for bug fixes and improvements that would be helpful to others.
