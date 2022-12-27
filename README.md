<div align="center">
<img src="https://cdn.discordapp.com/attachments/735132698603159562/1057328546848190585/plugin_icon.png"  width=125px alt="plugin icon"></img>
<h2>Count It! Plugin for Roblox</h2>
<p>
Ever dreamt of flexing to your friends with the amount of work you put into your game but in a <b>refined</b> and <b>elegant</b> way instead of a simple print? Then here is your chance!
</p>
    <a href="">See the original post</a>
    ·
    <a href="#Demonstration">See the demo</a>
    ·
    <a href="https://github.com/proudCobolWriter/roblox-luau-countit-plugin/issues/new/choose">Report bug or request feature</a>
<img src="https://github-readme-stats.vercel.app/api/pin/?username=proudCobolWriter&repo=roblox-luau-countit-plugin&theme=dark&title_color=fff&text_color=fff&icon_color=fff" />
</div>

---

<kbd>**Count it!**</kbd> was brought to light to give you a quick overview of your place by displaying statistics such as how much lines of code and scripts there are amid each service, how much duplicate scripts there are and even viruses, and all of that in a fancy GUI!

This plugin also allows you to keep track of how many lines and characters you have written in a day which is a pretty cool feature I believe!

## Demonstration:

<img src="https://cdn.discordapp.com/attachments/735132698603159562/1057338591006687272/gif2.gif" alt="example use"></img>

## [Folder](./src/) hierarchy

```lua
root ---@folder
├── PluginInit ---@script PluginInit  Setups plugin and handles plugin-studio interactions
├── LinesOfCodeFrameInit ---@module LinesOfCodeFrameInit  Initializes LinesOfCode Frame
├── ResponsiveFrame ---@module ResponsiveFrame  Handles the position and the size of a given frame
├── MonitorScripts ---@module MonitorScripts  Self-explanatory, watches script changes via ScriptEditorService
├── Util ---@module Util  Just a bunch of utility functions to complement the plugin and keep things clean
├── VirusSignatures ---@module VirusSignatures  Identifies viruses
├── CountLines ---@module CountLines  Returns advanced script statistics about the game
└── GraphCreator ---@module GraphCreator  Creates and animates graphs using TweenService
```

> **Note**
> The aforementioned functions can be found [here](./src/).
