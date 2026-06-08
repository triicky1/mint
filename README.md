# Custom Linux Mint

## Installation

```sh
sudo apt install git curl
mkdir -p $HOME/.local/bin
curl -fLo "$HOME/.local/bin/yadm" https://github.com/TheLocehiliosan/yadm/raw/master/yadm && chmod a+x "$HOME/bin/yadm"
source ~/.profile
yadm clone --bootstrap https://github.com/triicky1/mint
```
