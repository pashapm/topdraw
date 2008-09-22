TopDraw
Version {VERS} -- {DATE}
http://code.google.com/p/topdraw
Dan Waylonis (waylonis@google.com)

== Introduction ==
Top Draw is an image generation program.  By using simple text scripts, based on the JavaScript programming language, Top Draw can create surprisingly complex and interesting images.  The cool part is that the program has built in support for taking your image and installing it as your desktop image.  There's even a Viewer application that can be installed in the menubar to automatically run with the parameters (e.g., script, update interval) that you've specified.
The Top Draw scripting language leverages Apple's Quartz and CoreImage rendering engines for the graphical muscle.  In addition to the drawing commands that are supported by the HTML "canvas" tag, there is support for particle systems, plasma clouds, random noise, multi-layer compositing and much more.

Because it uses JavaScript in a safe "sandbox", you can run any script without fear of malicious action.

== Getting Started ==
1. When you launch Top Draw, it will automatically copy some example script files to ~/Library/Application Support/Google/TopDraw/Scripts.
2. You can open multiple script files and render each of them independently into the Preview window.
3. If you see something you like, you can easily install the image onto your Desktop from the Drawing menu.
4. You can launch and/or install the Viewer from the appropriately named Viewer menu item.  If you launch the viewer, you'll see a colored rectangle show up in the right hand area of your menu bar.  If you click on the rectangle, choose the Preferences menu item to configure the behavior of the Viewer.  You can also choose the Render menu and pick any of the listed scripts to Render and install immediately.

== Documentation ==
Documentation for Top Draw and the Viewer application can be found in the Help menu of Top Draw.

== Editing, logging, and creating ==
There's a simple colorizing text editor which will highlight interesting keywords as you type, including the Top Draw objects.  Blocks of text can be selected and (un)indented by hitting the Tab key.  Errors will be highlighted in the text and also described in the Logging Window.  Also, if you add the "log(<any string>)" function to your script, that information will appear in the Logging Window.

One fun feature is that you can use the rendering engine to create an image of nearly any size and export it from Top Draw into a variety of formats.  See the documentation on the Image object and the exportImage() function.

== Technical ==
Both the Top Draw application and the Viewer use a separate TopDrawRenderer process to actually do all of the work.  This allows for a smaller footprint as well as eliminating the risk of memory leaks.

The last 10 images rendered will be saved in ~/Library/Application Support/Google/TopDraw.

== Requirements ==
TopDraw requires Mac OS X 10.5 (Leopard) or later as it uses the JavaScriptCore.framework to evaluate the JavaScript.

