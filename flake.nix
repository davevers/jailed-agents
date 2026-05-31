{
  description = "Secure Nix sandbox for LLM agents - Run AI coding agents in isolated environments with controlled access";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    jail-nix.url = "sourcehut:~alexdavid/jail.nix";
    llm-agents.url = "github:numtide/llm-agents.nix";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      jail-nix,
      llm-agents,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        jail = jail-nix.lib.init pkgs;
        commonPkgs = with pkgs; [
          bashInteractive
          curl
          wget
          jq
          git
          which
          ripgrep
          gnugrep
          gawkInteractive
          ps
          findutils
          gzip
          unzip
          gnutar
          diffutils
          gnused
        ];

        commonJailOptions = with jail.combinators; [
          network
          time-zone
          no-new-session
        ];

        makeJailedAgent =
          {
            name,
            pkg,
            configPaths,
            extraPkgs ? [ ],
            extraReadwriteDirs ? [ ],
            extraReadonlyDirs ? [ ],
            env ? { },
            baseJailOptions ? commonJailOptions,
            basePackages ? commonPkgs,
          }:
          jail name pkg (
            with jail.combinators;
            (
              baseJailOptions
              ++ (map (p: readonly (noescape p)) extraReadonlyDirs)
              ++ [ mount-cwd ]
              ++ (map (p: readwrite (noescape p)) (configPaths ++ extraReadwriteDirs))
              ++ [ (add-pkg-deps basePackages) ]
              ++ [ (add-pkg-deps extraPkgs) ]
              ++ (pkgs.lib.mapAttrsToList set-env env)
            )
          );

        makeJailedPi =
          {
            name ? "jailed-pi",
            pkg ? llm-agents.packages.${system}.pi,
            extraPkgs ? [ ],
            extraReadwriteDirs ? [ ],
            extraReadonlyDirs ? [ ],
            env ? { },
            baseJailOptions ? commonJailOptions,
            basePackages ? commonPkgs,
          }:
          makeJailedAgent {
            inherit
              name
              pkg
              extraPkgs
              extraReadwriteDirs
              extraReadonlyDirs
              baseJailOptions
              basePackages
              env
              ;
            configPaths = [
              "~/.pi"
            ];
          };

        makeJailedCodex =
          {
            name ? "jailed-codex",
            pkg ? llm-agents.packages.${system}.codex,
            extraPkgs ? [ ],
            extraReadwriteDirs ? [ ],
            extraReadonlyDirs ? [ ],
            env ? { },
            baseJailOptions ? commonJailOptions,
            basePackages ? commonPkgs,
          }:
          makeJailedAgent {
            inherit
              name
              pkg
              extraPkgs
              extraReadwriteDirs
              extraReadonlyDirs
              baseJailOptions
              basePackages
              env
              ;
            configPaths = [
              "~/.codex"
            ];
          };
      in
      {
        lib = {
          inherit commonJailOptions;
          inherit makeJailedAgent;
          inherit makeJailedPi;
          inherit makeJailedCodex;

          internals = {
            inherit jail;
          };
        };

        packages = {
          jailed-pi = makeJailedPi { };
          jailed-codex = makeJailedCodex { };
        };

        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.nixd
            pkgs.nixfmt
            pkgs.statix
            (makeJailedCodex {
              extraPkgs = [
                pkgs.nixd
                pkgs.nixfmt
                pkgs.statix
              ];
            })
          ];
        };
      }
    );
}
