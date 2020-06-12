#! /usr/bin/env bash

# This script finds the last generation of hackage-packages.nix in nixpkgs and
# rebuilds it based on the configuration-hackage2nix.yaml in nixpkgs.
# Assumptions

# 1. Have cabal installed.
# 2. Being run out of the cabal2nix repo.
# 3. A checkout or symlink to checkout of nixpkgs under ./nixpkgs
# 4. A checkout or symlink to checkout of all-cabal-hashes under ./hackage

# What you should do:
# 1. Change pkgs/development/haskell-modules/configuration-hackage2nix.yaml to your liking.
# 2. Run ./regenerate-nixpkgs.sh
# 3. Enjoy your adapted pkgs/development/haskell-modules/hackage-packages.nix


# Possible improvements for this script:
# 1. Use nix-shell to provide dependencies.
# 2. Clone all-cabal-hashes if missing.
# 3. Share code with update-nixpkgs.
# 4. Integrate preferred-versions into hackage2nix.
# 5. Use cabal tarballs in hackage2nix.

set -eu

exit_trap()
{
  local lc="$BASH_COMMAND" rc=$?
  test $rc -eq 0 || echo "*** error $rc: $lc"
}

trap exit_trap EXIT

cd "$(dirname "$0")"

cd nixpkgs
msg=$(git log pkgs/development/haskell-modules/hackage-packages.nix | grep -A1 -B6 "This update was generated by hackage2nix .* from Hackage revision" | head -n8)
nixpkgsCommit=$(echo $msg | sed 's/.*commit \([a-z0-9]*\).*/\1/')
nixpkgsCommitDate=$(echo $msg | sed 's/.*Date: \(.*\) hackage-packages.nix.*/\1/')
usedCabal2nix=$(echo $msg | sed 's/.*hackage2nix .*-g\(.*\) from Hackage revision.*/\1/')
usedCabalHashes=$(echo $msg | sed 's/.*all-cabal-hashes\/commit\/\(.*\)\./\1/')
echo "Last commit updating hackage-packages.nix was $nixpkgsCommit at $nixpkgsCommitDate."
export NIX_PATH=nixpkgs=$PWD
cd ..
echo "Checking out $usedCabal2nix for cabal2nix ..."
git fetch --all -q
git checkout $usedCabal2nix -q
cabal2nix=$(git describe --dirty)
echo "Checked out."

cd hackage
echo "Checking out $usedCabalHashes for hackage ..."
git fetch --all -q
git checkout $usedCabalHashes -q
echo "Checked out."
rm -f preferred-versions
for n in */preferred-versions; do
  cat >>preferred-versions "$n"
  echo >>preferred-versions
done
hackage=$(git rev-parse --verify HEAD)
cd ..

# This command needs a recent development version of cabal-install. I don't
# think this works properly in version 2.0.0.0 already.
echo "Running hackage2nix on nixpkgs ..."
cabal -v0 new-run hackage2nix -- --nixpkgs="$PWD/nixpkgs" +RTS -M4G -RTS
echo "hackage-packages.nix regenerated."
