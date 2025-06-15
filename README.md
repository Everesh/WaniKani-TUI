# WanikaniTUI

## Preview

### Default Theme
![preview gif](https://github.com/user-attachments/assets/9903fdb5-5ee2-4c58-8cda-90b58c011697)

### WaniKani Theme
![preview gif wanikani theme](https://github.com/user-attachments/assets/e66685ab-366a-4ec9-b005-7557622efd12)

## Installation

### Automated
1. Set up the environment:
```sh
./setup.sh
```
2. If it yells at you, that you are missing either `Ruby` or `Python`... fix that •ᴗ•
3. Get yourself the required `NotoSansJP-Regular.ttf` at [fonts.google](https://fonts.google.com/noto/specimen/Noto+Sans+JP) and copy it to `./tui/cjk_renderer/`

### Manual
If... let's be honest, when... the automated installation inevitably fails
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
The app will most definitely ask you for your [WK api key](https://www.wanikani.com/settings/personal_access_tokens). Simply create one, grant it `all_data:read`, `assignments:start` and `reviews:create` and paste it into the prompt(ctrl + shift + V). Or type it out manually, if you are into that.
- .ᐟ If you ever get stuck in engine initialization loop, report it here and delete your `db.sqlite3` located at `~/.local/share/WaniKaniTUI/` or `%LOCALAPPDATA%\WaniKaniTUI` depending on your platform!

## Additional Customization
Don't like the colors? or just a single one? What about the braille rendering, is it spaced correctly?

You can change all that and more!

Simple create your own config file and save it to `~/.local/share/WaniKaniTUI/` or `%LOCALAPPDATA%\WaniKaniTUI` depending on your platform!

Example with all the available flags at `./examples/config.yml`

## Internal Structure

### Database
![database img](https://github.com/user-attachments/assets/7b3752d4-695c-46a2-843c-2ffb4720c945)
