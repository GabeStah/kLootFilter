# kLootFilter

Allows simple loot filtering, preventing specified items from being looted.

## Features

- Specify filtered items in a simple drag and drop interface.
- Filtered items can be used as a `blacklist` (default), where all other items except those that are filtered are looted.
- Alternatively, filtered items can be used as a `whitelist`, in which all items that _are not_ filtered are ignored.
- Dramatically speeds up looting compared to standard built-in `Auto Loot` speed.
- Optionally output a message when `kLootFilter` ignores an item due to filtering.

## Caveats

- Due to how loot filtering must function within the WoW API, `kLootFilter` __does not__ function if the built-in `Auto Loot` Interface option is enabled.

## Configuration

Open the `Options` menu through the standard `ESC > Interface > kLootFilter`, or with a slash command: `/klf` or `/klootfilter`.

### Adding Filtered Items

Within the `Options`, simply drag and drop an item from your inventory to an open `Filtered Item` box to add it to the filtered list.

### Removing Filtered Items

Left-click (or drag) an item currently being filtered to remove it from the filtered list.