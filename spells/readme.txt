How to create a spell for mmo

1. create a folder with the name of your Spell
2. create <spells_name>.lua, Info.ini

3. ini explanation

[Spell] -> this is always the same
Author=<your_name_here>
Description=<in_short_what_it_does>
Magic=<amount_of_magic_it_will_consume>
Cooldown=<time_you_have_wait_until_you_can_spell_it_again>
Cast_time=<time_you_need_to_cast_the_spell>

4. the lua file
first line should be

command, player = ...

with that you will get the command and the player object

5. write your code xD
