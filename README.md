本项目提供步步高朗文4980电子词典游戏模拟器的 libretro 核心。


本项目基于：
* [BA4988 模拟器](https://gitee.com/BA4988/BBK-simulator)，作者：无云。


使用该核心需从词典导出字体和系统区的 ROM 文件：
- 8.BIN (0x800000-0x9fffff)
- E.BIN (0xe00000-0xffffff)
并放入 RetroArch 的 system/gam4980 目录下（例如: ~/.config/retroarch/system/gam4980/8.BIN）。


This project provides a libretro core to play games from BBK Longman
4980 electronic dictionary.  2 ROM files (8.BIN and E.BIN) are needed,
which can be dumped from 0x800000-0x9fffff and 0xe00000-0xffffff.
