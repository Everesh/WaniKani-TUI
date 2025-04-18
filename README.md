# WaniKani TUI
[WaniKani](https://www.wanikani.com) Reviews in your terminal

---

### CLI
![cli preview gif](https://github.com/user-attachments/assets/a71298d7-3dbb-4fd2-8ae8-bd9d380f2b94)

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

