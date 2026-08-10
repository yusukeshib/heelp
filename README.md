# Jogen

Jogen is a macOS menu bar writing coach. It watches the focused text field in other apps, waits until typing settles, and shows concise AI feedback near the insertion point before the text is sent.

## MVP behavior

- Works without selecting a custom input source
- Captures Unicode text through the macOS Accessibility API
- Debounces changes before making an API request
- Uses Anthropic's Messages API with a configurable model
- Keeps the API key in macOS Keychain
- Lets the user replace the review prompt
- Includes a local diagnostic mode for testing capture without an API request
- Ignores secure text fields

## Run

```sh
make run
```

On first launch, grant Jogen Accessibility access. Open **Jogen → Settings…** from the menu bar, enter an Anthropic API key, and adjust the prompt if needed.

The default prompt asks for grammar feedback and explanations in Japanese. Both the prompt and model ID are user-configurable.
