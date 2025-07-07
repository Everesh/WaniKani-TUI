# WanikaniTUI

Terminal-based client for the [WaniKani web app](https://www.wanikani.com/about), built using the curses library.

For when you need to do your reviews over SSH

## Preview

### Default Theme
![preview gif](https://github.com/user-attachments/assets/9903fdb5-5ee2-4c58-8cda-90b58c011697)

### WaniKani Theme
![preview gif wanikani theme](https://github.com/user-attachments/assets/e66685ab-366a-4ec9-b005-7557622efd12)

## Installation

1. Get yourself `Ruby` and `Python` interpreters
2. Move to the project dir
3. Install all the dependencies:
```sh
gem install bundler
bundle install
pip install pillow numpy
```
4. Get yourself the required `NotoSansJP-Regular.ttf` at [fonts.google](https://fonts.google.com/noto/specimen/Noto+Sans+JP) and copy it to `./tui/cjk_renderer/`

## Running the App
```sh
bundle exec ruby bin/tui.rb
```

### First Run
For the app to initialize, you will have to provide it with a [WK api key](https://www.wanikani.com/settings/personal_access_tokens). Simply create one, grant it `all_data:read`, `assignments:start` and `reviews:create` and paste it into the prompt(ctrl + shift + V)... Or type it out manually, if you are into that.
- .ᐟ If something breaks, report it here and try deleting your `db.sqlite3` file, located at `~/.local/share/WaniKaniTUI/` or `%LOCALAPPDATA%\WaniKaniTUI` depending on your platform!

### Controls
- Generic:
  - `ENTER` to submit answer
  - `ESC` to bring out the menu
  - `ctrl + p` to pass current task
- Menu:
  - `w`, `k`, `↑` to move up
  - `s`, `j`, `↓` to move down
  - `ENTER`, `l`, `→` to select option

## Additional Customization
Don't like the colors? What about the braille rendering, is it spaced correctly?

You can change all that and more!

![preview custom theme](https://github.com/user-attachments/assets/fa590a77-5a73-4487-8a1b-7bf664412494)

Simple create your own config file and save it to `~/.local/share/WaniKaniTUI/` or `%LOCALAPPDATA%\WaniKaniTUI` depending on your platform!

Example with all the available flags at `./examples/config.yml`

## Internal Structure

### Database
![database img](https://github.com/user-attachments/assets/7b3752d4-695c-46a2-843c-2ffb4720c945)
