# WanikaniTUI

## Preview

### Default theme
![preview gif](https://github.com/user-attachments/assets/9903fdb5-5ee2-4c58-8cda-90b58c011697)

### WaniKani theme
![preview gif wanikani theme](https://github.com/user-attachments/assets/e66685ab-366a-4ec9-b005-7557622efd12)

## Installation

### Automated
```sh
./setup.sh
```
- If it yells at you, that you are missing either ruby or python... fix that •ᴗ•
- Get yourself the required `NotoSansJP-Regular.ttf` at [fonts.google](https://fonts.google.com/noto/specimen/Noto+Sans+JP) and copy it to `./tui/cjk_renderer/`

### Manual
If... let's be honest, when the automated installation inevitably fails
- Get yourself ruby and python interpreters
- Move to the project dir
```sh
gem install bundler
bundle install
pip install pillow numpy
```
- Get yourself the required `NotoSansJP-Regular.ttf` at [fonts.google](https://fonts.google.com/noto/specimen/Noto+Sans+JP) and copy it to `./tui/cjk_renderer/`

### Runing the app
```sh
bundle exec ruby bin/tui.rb
```

#### First Run
The app will most definetly ask you for your [WK api key](https://www.wanikani.com/settings/personal_access_tokens). Simply create one, grant it *all_data:read, assignments:start and reviews:create* and paste it to the prompt.
- .ᐟ If you ever get stuck in engine initialization loop, report it here and delete your db.sqlite3 located at `~/.locale/share/WaniKaniTUI/` or `%LOCALAPPDATA%\WaniKaniTUI` depending on your platform!

### Additional customization
Don't like the colors? or just a single one? What about the braille rendering, is it spaced correctly?
You can change all that and more. Simple create your own config file and save it to `~/.locale/share/WaniKaniTUI/` or `%LOCALAPPDATA%\WaniKaniTUI` depending on your platform!

Example with all the available flags at `./examples/config.yml`
