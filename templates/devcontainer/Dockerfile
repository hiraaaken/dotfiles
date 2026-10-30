# 言語を含まない汎用の土台。言語やツールはプロジェクトの mise.toml で決め、post-create.sh で入れる
# （手元とコンテナで同じ mise.toml から同じバージョンが入る）。
# 作るたびに中身が変わらないよう、ベースイメージと mise のバージョンは固定する
FROM debian:13.7-slim

ARG USERNAME=dev
ARG USER_UID=1000
ARG MISE_VERSION=v2026.9.6

# ビルドに要るもの（ネイティブモジュールなど）と、git・最小のエディタ（git commit 用）
RUN apt-get update && apt-get install -y --no-install-recommends \
        bash-completion \
        build-essential \
        ca-certificates \
        curl \
        git \
        less \
        procps \
        vim-tiny \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://mise.run | MISE_VERSION=${MISE_VERSION} MISE_INSTALL_PATH=/usr/local/bin/mise sh

# root 以外で作業する（node_modules などの持ち主をそろえ、コンテナ内で sudo を使わない）
RUN useradd --create-home --shell /bin/bash --uid ${USER_UID} ${USERNAME} \
    && chmod 755 /home/${USERNAME}

# シェルの設定を読まない docker exec（エディタの LSP など）からもツールが見えるよう、shims を PATH に置く。
# ツールの置き場所は固定し、ほかのユーザー（Neovim のエージェント用の nvim-agent など）からも使えるようにする
ENV LANG=C.UTF-8 \
    EDITOR=vi \
    MISE_YES=1 \
    MISE_DATA_DIR=/home/${USERNAME}/.local/share/mise \
    # pnpm のストアをコンテナの中に置く（ホームとプロジェクトのファイルシステムが違うと、
    # pnpm はプロジェクトのマウントの一番上に .pnpm-store を作り、手元に置かれてしまう）
    pnpm_config_store_dir=/home/${USERNAME}/.local/share/pnpm/store \
    npm_config_store_dir=/home/${USERNAME}/.local/share/pnpm/store \
    PATH=/home/${USERNAME}/.local/share/mise/shims:${PATH}

USER ${USERNAME}
