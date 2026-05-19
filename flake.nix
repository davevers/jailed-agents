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

        makeJailedCrush =
          {
            name ? "jailed-crush",
            pkg ? llm-agents.packages.${system}.crush,
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
              "~/.config/crush"
              "~/.local/share/crush"
            ];
          };

        makeJailedOpencode =
          {
            name ? "jailed-opencode",
            pkg ? llm-agents.packages.${system}.opencode,
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
              "~/.config/opencode"
              "~/.local/share/opencode"
              "~/.local/state/opencode"
            ];
          };

        makeJailedGeminiCli =
          {
            name ? "jailed-gemini-cli",
            pkg ? llm-agents.packages.${system}.gemini-cli,
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
              "~/.gemini"
            ];
          };

        makeJailedHermesAgent =
          {
            name ? "jailed-hermes-agent",
            pkg ? llm-agents.packages.${system}.hermes-agent,
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
              "~/.hermes"
            ];
          };

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

        makeJailedClaudeCode =
          {
            name ? "jailed-claude-code",
            pkg ? llm-agents.packages.${system}.claude-code,
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
              "~/.claude"
              "~/.claude.json"
            ];
          };

      in
      {
        lib = {
          inherit commonJailOptions;

          inherit makeJailedAgent;
          inherit makeJailedClaudeCode;
          inherit makeJailedCrush;
          inherit makeJailedGeminiCli;
          inherit makeJailedHermesAgent;
          inherit makeJailedOpencode;
          inherit makeJailedPi;

          internals = {
            inherit jail;
          };
        };

        packages = {
          jailed-claude-code = makeJailedClaudeCode { };
          jailed-crush = makeJailedCrush { };
          jailed-gemini-cli = makeJailedGeminiCli { };
          jailed-hermes-agent = makeJailedHermesAgent { };
          jailed-opencode = makeJailedOpencode { };
          jailed-pi = makeJailedPi { };
        };

        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.nixd
            pkgs.nixfmt
            pkgs.statix
            (makeJailedOpencode {
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
