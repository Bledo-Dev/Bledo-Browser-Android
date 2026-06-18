# Bledo Browser

A modern web browser with a clean, dark-themed interface. Bledo is a non-Chromium based browser that uses Python's requests library to fetch web pages and BeautifulSoup for HTML parsing.

## Features

- **Tabbed Browsing**: Open multiple tabs and navigate between them easily
- **Navigation Controls**: Back, forward, reload, and home buttons
- **Address Bar**: Enter URLs directly or search
- **Dark Theme**: Modern dark interface for comfortable browsing
- **Status Bar**: Shows loading progress and status messages
- **Non-Chromium**: Does not use any Chromium-based rendering engine

## Important Notes

This browser uses a non-Chromium approach by fetching web pages using the `requests` library and displaying them with basic HTML parsing. This means:

- JavaScript execution is not supported
- Complex CSS rendering is limited
- Modern web applications may not function correctly
- Pages are displayed as text content with basic formatting

This is a fundamental limitation of avoiding Chromium-based rendering engines while using Python.

## Installation

1. Make sure you have Python 3.8 or higher installed
2. Install dependencies:
   ```
   pip install -r requirements.txt
   ```

## Building the Executable

To compile the browser into a standalone .exe file:

1. Place your logo image as `logo.png` in the project directory
2. Run the build script:
   ```
   build.bat
   ```

The compiled executable will be created in the `dist` folder.

## Running the Browser

To run the browser without compiling:

```bash
python bledo_browser.py
```

## Logo

To use your custom logo:
1. Save your logo image as `logo.png` in the `C:\BledoWIndows` directory
2. The browser will automatically load it as the window icon

## Requirements

- Python 3.8+
- PyQt5
- requests
- beautifulsoup4
- pyinstaller (for building .exe)

## License

This project is provided as-is for educational purposes.
