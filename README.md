# Reference Viewer
Aseprite extension to open a reference image

## Installation
### Get the extension
Download the *reference_viewer.aseprite-extension* from [itch](https://enmarimo.itch.io/reference-viewer).

OR

Create the extension from the repository. In *Windows*, open a *PowerShell* and run:
```
git clone https://github.com/enmarimo/aseprite_reference_viewer
cd aseprite_reference_viewer
scripts\create_extension.ps1
```
It will create the extension inside *build\\* folder.

### Install the extension
In Aseprite open the Preferences dialog window by clicking on **Edit > Preferences...** in the top bar menu.

Then, in the **Extensions** tab click on the **Add Extension** button and find the *reference_viewer.aseprite-extension* downloaded before.

## Usage
To open the *Reference Viewer* click on the **View > Reference Viewer** menu.

The *Reference Viewer* dialog window will open. The window can be resized and moved. Then click **Select File** to open an image (aseprite will warn you about the script accessing an external image).

With an image opened, it is possible to:
* zoom in and out using the slider or the mouse wheel.
* click on the Fit button to fit the image into the dialog window.
* move the image by dragging it.

## Contributing
Any suggestions and comments are welcome, but keep in mind this project is mostly a hobby and I don't guarantee any kind of support or response.

If you want to expand/improve this project feel free to fork the repository or create a new one. For now I don't plan on accepting pull requests as I want to keep this as a personal
project and I would prefer to avoid organizing/maintaining other people's code (sorry for the inconvenience).
