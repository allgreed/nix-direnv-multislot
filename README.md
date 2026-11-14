# nix-direnv-multislot
Multi-slot, git-aware (soon!), somewhat vegan

## wtf does "multislot" means?
Ben said to call it "multi**cache**" -- does that help?

The upstream implementation catches only a single environment (technically: environment *script*), while this one allows for **much** more

More [details in the original patch submission / issue](https://github.com/nix-community/nix-direnv/issues/645)

## Advantages
- if you switch between branches that have a `flake.nix` diff between each other it's still fast
- (**hopefully coming soon!**) worktree support -- the cache is shared between worktrees of the same git repository

## Disadvantages
- no `newer_files` reporting -- the semantics of "newer" doesn't hold, hit me up if you have an idea how this could sensibly work
- garbage collection is nerfed -- since there are effectively infinite slots the GC roots will accumulate over time. One can nuke the whole cache directory at that point, run gc, rebuild things.
- I'm having some issues with cache playing nice with a parent directory flake reference. Let's say I'm in /foo/ and I reference .#foo from /flake.nix -- the env is rebuilt every time.
- flakes only (`use_nix` fallbacks to the upstream impl)

## See [upstream](https://github.com/nix-community/nix-direnv)
It has a [proper README with examples and everything](https://github.com/nix-community/nix-direnv)!

## Bash overlay
If you trust `nix-direnv` and don't want to audit the whole project from scratch there's an option to build just the *diff* from upstream on a per-function basis.
A bit hacky? Mabye. ~130 lines to audit vs ~700? Deffinitely. Use it like so:

```
nix build .#bash_overlay
. $(pwd)/result/nix-direnv-multislot-overlay.sh
```
