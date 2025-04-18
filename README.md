# WaniKani TUI
[WaniKani](https://www.wanikani.com) Reviews in your terminal

---

### TUI
![tui preview gif](https://github.com/user-attachments/assets/3b103af1-2c86-4c72-8a2c-1e0cb10ddc47)

---

### CLI
![cli preview gif](https://github.com/user-attachments/assets/702ee7f6-d743-44d4-80a2-fa578720d481)

---

### Installation
1. Grab the repo:
    ```sh
    git clone https://github.com/Everesh/WaniKani-TUI.git
    ```
2. Move to the new dir:
    ```sh
    cd WaniKani-TUI
    ```
3. Install required gems:
    ```sh
    bundle install
    ```
4. Set up your [WaniKani API key](https://www.wanikani.com/settings/personal_access_tokens):
    - required flags: `all_data:read`, `reviews:create`
    ```sh
    echo "WANIKANI_API_KEY=<your-api-key>" > .env
    ```
5. Run either the CLI or TUI app
    ```sh
    bundle exec ruby <cli.rb/tui.rb>
    ```
---

### Features
- __Romaji Parsing__: Accepts romaji alongside kana for reading inputs
- __Typo Tolerance__: Accepts typos for meaning inputs
