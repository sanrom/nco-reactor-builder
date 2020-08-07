# NuclearCraft Overhaul Reactor Builder

Run
`wget -f https://raw.githubusercontent.com/sanrom/nco-reactor-builder/master/config2_parser.lua`
`wget -f https://raw.githubusercontent.com/sanrom/nco-reactor-builder/master/reactor_builder.lua`
in OpenComputers to install the scripts!

## Features

- [x] Fission SFRs
- [ ] Fission MSRs
- [ ] Turbines
- [ ] ~~Heat Exchangers~~
- [ ] ~~Fusion Reactors~~
- [x] NCPF Files (Thiz Reactor Planner)
- [ ] JSON Files (Hellrage Reactor Planner)
- [ ] Casing
- [ ] Automatic cell filtering

## Requirements

For the config2 parser, there are no hard requirements, except a lot of ram to load big files

For the reactor builder, a robot with the following components/upgrades are **required**:
- Inventory Controller Upgrade
- At least one Inventory Upgrade
- Angel Upgrade
- Hover Upgrade (Tier 1)
- Screen
- Graphics Card
- Keyboard

The following componets/upgrades are *recommended*:
- Multiple Inventory Upgrades: more inventory space on the robot means less back and forth to the storage chest
- Good amount of RAM, especially for larger reactors
- Chunkloader Upgrade: to let the robot build while you are not around

## Setup

![Demo Bot sitting on top of chest](examples/demobotwithaxes.png)

To function properly, the robot will need access to an inventory below its starting position. You can insert extra blocks into this inventory for the robot to pick them up as it needs. If the robot runs out of blocks in it's internal inventory while it is building, it will check that inventory for blocks.

If you want to see the outline of the reactor before building it, run `reactor_builder -o <filename>`. The robot will move along the x, y, and z axes respectively to show the *internal* size of the reactor. The robot requires 1 block additional space around those bounds (where the casing will be).

## Command Syntax

`reactor_builder [-d/g/o/s/I/p] <filename>`

-d/--debug: Enable debug mode, prints additional information
-g/--ghost: Enable ghost mode (robot does all moves, but does not place blocks) (still checks for inventory space and blocks)
-o/--outline: Trace the outline of the reactor before building anything. Robot will move along x, y and z axis and return home
-s/--stationary/--disableMovement: Disables robot movement (also enables ghost mode)
-I/--disableInvCheck: Disables the inventory check
-p/--disablePrompts: Disables all prompts, defaulting reactor ID to 1. Useful for running programs into output files. If in an error state, will always exit the program
-l/--pauseOnLayer: pauses the robot on each layer to allow manually filtering cells

## Color Status Codes

Red: Error State, check the robot
Yellow: Returning to inventory to pick up items
Green: Building normally
Clear/No Color: Program finished/terminated