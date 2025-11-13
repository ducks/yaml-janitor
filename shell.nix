{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    ruby_3_3
    bundler
  ];

  shellHook = ''
    echo "yaml-janitor development environment"
    echo "Ruby version: $(ruby --version)"
    echo ""
    echo "Available commands:"
    echo "  bundle install       - Install dependencies"
    echo "  bundle exec rake     - Run tests"
    echo "  bin/yaml-janitor     - Run the linter"
    echo ""

    # Set up gem home in project directory
    export GEM_HOME="$PWD/.gems"
    export PATH="$GEM_HOME/bin:$PATH"
  '';
}
