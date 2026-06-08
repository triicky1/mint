# Manual Steps for Submodules Setup (OhMyZsh plugins)
If you want to include these plugins as part of your repository but still track their separate history (i.e., you want them to remain Git repositories inside your dotfiles repository), you should use Git submodules.

## Steps to Set This Up:
1. **Remove the directories from the index after installing new plugins:**
If the plugin directories already exist in your repository (which should be the case if your dotfiles is already set up), remove them from the Git index (but keep them in your local working directory). This prevents Git from tracking them as regular files.

```sh
git rm --cached .oh-my-zsh/custom/plugins/example-plugin
```
This step is crucial because it allows you to add the plugin as a submodule instead of treating it as a regular directory.

2. **Add Plugins as Git Submodule (One-Time Setup)**
This **will** ensure that your plugins are automatically installed and can be updated easily whenever you clone your dotfiles repository or pull the latest changes.

Run the following commands to add each plugins as a submodule:

```sh
git submodule add https://github.com/user/example-plugin .oh-my-zsh/custom/plugins/example-plugin
```

This will create a submodule inside your repository and track the external repositories properly.

# Automatic Steps for Submodules Setup (OhMyZsh plugin installation)
To install new plugins and automatically add them as submodules, run:
```sh
add_plugin https://github.com/user/example-plugin
```
