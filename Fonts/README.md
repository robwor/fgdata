## fontmap.xml

Every new font file added to this folder needs to have an entry added to fontmap.xml as well.
Each entry in that file must be of the following format:
```xml
<font>
	<path>path/to/font/file/relative/to/Fonts/folder.ext</path>
	<family>Family name</family>
	<style>Font style (choices: normal, oblique, italic; default normal)</style>
	<variant>Font variant (choices: normal, small_caps; default: normal)</variant>
	<weight>
		Font weight (choices: integer value between 100 and 1000,
		thin (=100), ultralight (=200), light (=300), semilight (=350), book (=380), normal (=400), medium (=500),
		semibold (=600), bold (=700), ultrabold (=800), heavy (=900), ultraheavy (=1000); default: 400)
	</weight>
	<stretch>
		Font stretch (choices: ultra_condensed, extra_condensed, condensed, semi_condensed, normal,
		semi_expanded, expanded, extra_expanded, ultra_expanded; default: normal)
	</stretch>
</font>
```
The `<path>` tag can appear multiple times to give multiple font files the same attributes (useful e.g. when the font is present as both TXF and TTF formats).
Example:
```xml
<font>
	<path>Noto/NotoSans-BoldItalic.ttf</path>
	<family>Noto Sans</family>
	<style>italic</style>
	<weight>bold</weight>
</font>
<font>
	<path>monoMMM_5.ttf</path>
	<path>monoMMM_5.txf</path>
	<family>Mono MMM</family>
</font>
```
Structuring the fonts in a directory tree is also supported through the `<subdirectory>` tag which can be used to specify a subdirectory
containing another `fontmap.xml` file of the same format, the paths in any `fontmap.xml` files always being relative to the file containing
them.

Files of the same format are also needed in the `Fonts` folders of aircraft, addons and sceneries (if the fonts shall be used in a canvas.PangoText).

## TXF Font Pack

Most of these fonts were created from the X-windows
fonts that are distributed with Xfree86. The
exceptions are Sorority, Curlfont, Default and
Haeberli which came from Mark Kilgards' "texfont"
distribution.

I used Mark's program called 'gentexfont' to convert
X fonts into '.txf' format - which can be read into
the PLIB FNT component.

Large bold-faced fonts seem to work best. There
is little point in converting the italic versions
of these fonts since FNT can do a reasonable job
of italicising them on-the-fly.

Using large fonts gives them the best chance of
scaling them without undue aliasing either in
pixel or texel space. These fonts all fit pretty
well into 256x256 maps - using smaller maps would
require you to go for smaller font sizes - larger
maps would not fit into 3Dfx and similar hardware.

Medium and fine fonts look pretty terrible when scaled,
I have omitted all the fine fonts and some of the
worst medium fonts from the set that come with Xfree86.

You can preview these using the fnt_test program,
or use them from within other programs that use
Mark's TXF format.

