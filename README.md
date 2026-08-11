# Jogen

[![CI](https://github.com/yusukeshib/jogen/actions/workflows/ci.yml/badge.svg)](https://github.com/yusukeshib/jogen/actions/workflows/ci.yml)

Jogen is a macOS menu bar writing coach. Select text in another app, then click the nearby Jogen button for concise AI feedback.

## MVP behavior

- Works without selecting a custom input source
- Reviews only text the user deliberately selects
- Waits for the user to click the nearby Jogen button before making an API request
- Captures Unicode text through the macOS Accessibility API
- Supports Anthropic, OpenAI, and OpenRouter with a configurable model
- Keeps a separate API key for each provider in macOS Keychain
- Lets the user replace the review prompt
- Suppresses the popup when the model reports that no useful advice is needed
- Includes a local diagnostic mode for testing capture without an API request
- Ignores secure text fields
- Never rewrites text automatically

## Install

Download [**Jogen.dmg**](https://github.com/yusukeshib/jogen/releases/latest/download/Jogen.dmg), open it, and drag Jogen to Applications. Jogen requires macOS 13 or later.

On first launch, grant Jogen Accessibility access. Open **Jogen → Settings…** from the menu bar, choose Anthropic, OpenAI, or OpenRouter, enter its API key, and adjust the model and prompt if needed. Then select text in Chrome, Slack, TextEdit, or another app and click the Jogen button that appears nearby.

## Development

```sh
make run
```

Diagnostic capture is a runtime option rather than a user setting:

```sh
make run RUN_ARGS="--diagnostic"
```

The default prompt asks for grammar feedback and explanations in Japanese. Both the prompt and model ID are user-configurable.
