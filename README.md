# Brightness
Tool to control the brightness and gamma ramp of your display. Can also modify the backlight of your non-Apple displays.

I recommend copying the executable somewhere you can access it from the command line, be it /bin by facility; although the best is for example to put it in /opt, and make sure that it is accessible by adding a line like that in your .bash_profile (type `nano ~/.bash_profile`):

`export PATH=/opt:$PATH`

Anyway you can do it the way you like. Then you can use it to modify the brightness, gamma, temperature and so on of your display. Let's go through a few use cases:

`brightness +10`: This increases the backlight from 10%. Note that it will work only for your externally connected (non-Apple, DDC/CI compliant display). For your internal display, use the proper shortcuts on your keyboard or use an external utility like Spark or Karabiner to remap the brightness keys to non-Apple keyboards.

`brightness -5`: Decreases the brightness by 5. If the brightness drops below 0%, then the display will be darkened in software; that is, no modifications to the backlight, but the gamma ramp is modified to make everything darker. This allows to further lower the brightness of displays which are still to bright at their lowest level.

`brightness 50`: Sets the brightness to 50, like you would by fiddling with the keys on your external screen.

`brightness g1.3`: applies a gamma correction of 1.3 (decreasing the actual perceived gamma to 1.0/1.3 = 0.77 times the original as designed by your manufacturer). Typically, colors will appear clearer with values greater than 1, while preserving very dark colors (like black, red, etc.), and thus contrast unlike Apple's Ambient Light Compensation. It is perfect to get a very clear display on the sun, with details shown in all the dynamic range, from the darkest tones to the greatest ones.

`brightness t4500`: modifies the screen temperature to 4500K (warm lamp). It is assumed that your display is calibrated for 6500K (as are almost all Apple displays), so passing 6500 does not affect anything. Recommended values are 5500 (warm white corresponding to the sunlight; you quickly forget that you even applied it although it is still easier to the eyes) and 4500 (in the evening, to favor a good upcoming night). You may go below, such as 2800 if you are reading at night, and you might go greater than 6500 if you want to simulate a blueish display.

`brightness b20`: increases the black level by 20%. Unlike gamma correction, this does reduce the contrast. Still a combination of the two could get something easier to your eyes.

`brightness`: does not modify any parameter, just reapplies the previous gamma parameters and keeps running (the parameters are restored once the program is terminated, by pressing Ctrl+C for instance). If the parameters correspond to the defaults, the app closes immediately.

`brightness +20 g1.5 t5500 b5`: combines multiple parameters. The other (nonspecified) parameters stay the same as the last time.

`brightness --def g1.2`: restores most parameters to the defaults (except the delay and the LCD backlight) and then applies a gamma correction of 1.2. If you had only passed g1.2, and previously applied a temperature correction, the temperature would be modified there too; with --def, the temperature and any unspecified parameter reverts to default.

`brightness d30`: this software needs to keep running if it applies modifications to the gamma ramp (anything except the LCD backlight), because once closed OS X restores the default display ramp. The software can keep sleeping, although it is useful to have it wake up once in a while to check that the gamma ramp hasn't been modified externally (which can happen when you change the resolution for example). The default 30 second should be perfect, as it consumes virtually no CPU time (in the order of a millisecond/hour).

`brightness --silent --nosave t5500`: modifies the display temperature, but doesn't show any prompt in the top-right corner of the screen nor save the parameters for the next time (meaning running `brightness` alone will not set the temperature to 5500K).

For a better use, we recommend using an external program that can keep the brightness tool running, without having to keep a terminal open. For instance, you might use Spark and set a shortcut like shown below. By selecting "AppleScript" and a command like `do shell script "killall brightness; /Users/florian/Software/brightness +5 >/dev/null 2>&1 &"`, you start the software and keep it running without blocking the Spark daemon. Killing any previous instance is useful too, because it would create conflicts.

<p align="center">
  <img width="734px" src="http://mobile-dev.ch/images/Brightness-screenshot-02.png" alt="Spark screenshot"/>
</p>

You may therefore create shortcuts to increase the brightness, decrease it, set the temperature for reading and such.

Later on, if I get enough courage and spare time, I'd like to develop an GUI app that stays running as an icon in the top bar and allows to define profiles (temperature/gamma params) and quickly switching between them, while being able to listen for global shortcuts that would allow to modify the brightness or profile. If you are interested, feel free to get in touch with me.

Spark for OS X, by Shadow Lab: http://www.shadowlab.org/Software/spark.php
