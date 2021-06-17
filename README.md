Neovim Grimoire
===============

WIP
---

This document and the plugin itself are both works in progress. 

Overview
--------

A Grimoire is a book of magic and spells. 

This is mine. 

You could call it a developer's note book or just a notes app, but that belittles its power. Instant access to notes and snippets is magic. 

It takes some getting used to. Seven or eight tries in my case, but once you get used to it (and put more content into it) it feels like typing a simple incantation and what you're looking for simply manifests in front of you. 

I'm building this for myself, but figured I'd open source it in case anyone else wants to play with it. (Over time, I'm looking to make it more adaptive, but it's usable now with a little editing.)

* For the pedantic, no it's not instant by the strict definition, it just feels that way once you get used to the interaction. 

Installation
------------

- I'm using meilisearch for the search engine behind this. So it needs to be installed. 
- Right now, meilisearch needs it's initial index to be setup outside the Grimoire. The values that need to go into it are `id`, `name` (which is the filename), and `overview` which is the contents itself. 
- I haven't figured out how to install this with Plug or Packer yet. That'll happen in a future release. 
- For now, I'm just copying the files into:

        ~/.config/nvim/lua/grimoire.lua 
        ~/.config/nvim/plugin/grimoire.vim

- There's a bunch of hardcoded hotkeys under `local config.keys = {}` in the `~/.config/nvim/lua/grimoire.lua` file. These will be moved into a config file in the future. 


Usage
-----

TKTKTKTK

Shoutouts
---------

I got a huge amount of help from chat including:

- [aquafunkalisticbootywhap](https://twitch.tv/aquafunkalisticbootywhap)
- [cryogi](https://twitch.tv/cryogi)
- [GeekyGirlSarah](https://twitch.tv/GeekyGirlSarah)
- [i7](https://github.com/YannickFricke)


Other things I use
------------------

- I think this thing is stand-alone, but I need to verify that
- I'm using [vim-markdown](https://github.com/plasticboy/vim-markdown) for syntax highlighting



