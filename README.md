# DrumRotation

###### Scary warning: Most of these addons were made long ago during Feenix days, then a lot was changed/added to prepare for Corecraft. Since it died, they still haven't been extensively tested on modern servers.

### [Downloads](https://github.com/Shanghi/DrumRotation/releases)

***

## Purpose:
* Automatically builds and updates drum rotations for both battle and war drums depending on what people currently have and prefer to use. It stays updated, handling disconnected or dead people, group member changes, people messing up and using them at the wrong time, and people running out of drums. Ideally, if you somehow get in a group of 5 drummers, then 4 will be chosen for war drums and 1 for battle drums (if someone is carrying some).
* Customize how you're alerted when it's your turn with any combination of these options: play a sound, show a resizable/moveable icon, show a bar across the screen, show a raid-warning style message, or be whispered by the previous drummer if they have the addon.
* Automatically adds people as known drummers when seeing them use drums.
* Won't accidentally spam messages like macros commonly do, and won't say extra messages like telling someone to use their drums after combat ends or if you mess up and use drums right after someone else.


## Using:
1. Type **`/drum options`** to pick how you're alerted when it's your turn, and optionally type some known drummers in the list on the right (they'll be added automatically if they have the addon or are seen drumming).
2. Use drums normally - no macro needed

| Commands | Description |
| --- | --- |
| /drum options                 | _open the options window_ |
| /drum \<"say"\|"show">          | _say the drum rotation to the group, or show it to yourself - mostly for the benefit of people without the addon_ |
| /drum \<"join"\|"leave"> [name] | _temporarily add/remove [name] from drumming - leave off [name] to add/remove yourself_ |
| /drum&nbsp;\<"add"\|"remove">&nbsp;\<name> | _add/remove \<name> as a known drummer, permanently_ |
| /drum \<"battle"\|"war">        | _shortcut to set your preference for using drums of battle or war_ |
| /drum info ["raid"]           | _show information about each drummer (cooldowns/drums they have/preferences/etc) -<br/>adding "raid" will show the entire raid instead of just your group_ |
| /drum share                   | _share your known drummers list with the group (through the hidden addon channel)_ |


## Screenshot:
![!](https://i.imgur.com/3jIZXLi.jpg)


## Problems and solutions:
1. Someone wants to be the first drummer but the addon decided they're 2nd or later:

	This can happen if multiple people have the "prefer drumming first" option checked, but the first drummer doesn't really matter. Let them go first and the addon will adapt just like if someone goes out of order in a fight.

2. Someone never uses drums when it's their turn (or needs to be doing something else):

	You can temporarily exclude them by typing **`/drum leave <name>`** then add them back later with **`/drum join <name>`** - only one person needs to do this.

## Limitations:
* People without the addon are assumed to only have Drums of Battle. If you want them to do something different, you can temporarily exclude them with **`/drum leave <name>`** and then hopefully convince them to get the addon if you'll be in their group a lot!
* Cooldown tracking for people without the addon depends on a list of items that share cooldowns with drums and on the ability to see them in the combat log. Right now, besides drums, only Crystal Yield is on that list because I don't know what else people would actually use.