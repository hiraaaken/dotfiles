# dotfiles

## templates/

新規プロジェクト作成時、`.devcontainer/` の雛形として使う。

```sh
cp -r ~/dotfiles/templates/devcontainer-node .devcontainer
```

コピー後、プロジェクトに合わせて `name` や `forwardPorts` 等をカスタマイズする。
