# Jogen

Jogen is a macOS menu bar writing coach. Select text in another app and Jogen shows concise AI feedback near the selection.

## MVP behavior

- Works without selecting a custom input source
- Reviews only text the user deliberately selects
- Captures Unicode text through the macOS Accessibility API
- Debounces selection changes before making an API request
- Uses Anthropic's Messages API with a configurable model
- Keeps the API key in macOS Keychain
- Lets the user replace the review prompt
- Suppresses the popup when the model reports that no useful advice is needed
- Includes a local diagnostic mode for testing capture without an API request
- Ignores secure text fields
- Never rewrites text automatically

## Run

```sh
make run
```

On first launch, grant Jogen Accessibility access. Open **Jogen → Settings…** from the menu bar, enter an Anthropic API key, and adjust the prompt if needed. Then select text in Chrome, Slack, TextEdit, or another app.

The default prompt asks for grammar feedback and explanations in Japanese. Both the prompt and model ID are user-configurable.
