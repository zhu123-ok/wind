# LMOCSO source provenance

The four `.m` files here are unmodified reference copies from BIMK/PlatEMO,
commit `e2d58cb4850acf1af5c48dffb669e86e9a89da9e`. Exact URLs and SHA-256
hashes are recorded in `source.json`. Do not add this directory to the
experiment path: its LMOCSO class has the same name as the project adapter.

Reference: Y. Tian, X. Zheng, X. Zhang, Y. Jin, “Efficient Large-Scale
Multiobjective Optimization Based on a Competitive Swarm Optimizer”,
IEEE Transactions on Cybernetics 50(8), 3696–3708, 2020.
DOI: https://doi.org/10.1109/TCYB.2019.2906383

Preserve the BIMK research-use notices. Publications using this code should
acknowledge PlatEMO and cite both LMOCSO and the PlatEMO platform paper
(Tian et al., IEEE Computational Intelligence Magazine 12(4), 2017, 73–87).

## Project adaptation

`../../LMOCSO.m` and `../../lmocso_*.m` preserve:

- Three-objective NBI reference points, including adjustment of the requested
  initial population (100 becomes 91). Subsequent populations have one member
  per occupied reference direction, with no artificial filling to 100.
- Shift-based density fitness; larger values win pairwise competitions.
- Accelerated competitive-swarm position/velocity updates and polynomial
  mutation (eta=20, probability=1/D) of both losers and winners. Velocities
  remain attached to their encodings through environmental selection.
- Objective-only first-front filtering, translated objectives, and APD
  selection with theta=(FE/maxFE)^2. Reference vectors remain fixed.
- A singleton population competes with itself; odd populations leave one
  unpaired member in the parent pool.

Differences and integration boundaries:

1. Normalized [0,1] real encodings, exactly three objectives, the shared
   WindFLO geometry repair and evaluator. Repair does not overwrite particle
   encodings or velocities. Failed repairs have nonfinite objectives and are
   excluded before environmental selection; an entirely invalid initial
   population raises an explicit error. This is not a generic constrained
   benchmark implementation of the upstream CV branch.
2. Every evaluated layout, including mutated winners, cache hits and failed
   repairs, counts as one FE. Final offspring batches are truncated in upstream
   order (updated losers then mutated winners) to respect the exact budget.
3. Constant fitness dimensions use an epsilon scale. Cosines are clamped to
   [-1,1]; zero objective vectors associate deterministically with the first
   reference vector. Duplicate/constant fronts avoid upstream NaNs.
4. A bounded external archive and convergence callbacks follow the project
   survivor-history convention. The archive does not guide particle updates.
5. Toolbox-free norm/dot-product calculations replace pdist2. Only the NBI
   three-objective branch of UniformPoint is adapted.

`test_lmocso` checks the adapted variation directly against the unmodified
upstream Operator using lightweight evaluation/particle stubs; it compares
reference points to UniformPoint, checks SDE and scalar APD calculations,
exact budgets and seed reproducibility, then reevaluates real WindFLO layouts.
These checks do not establish performance superiority or full random-trajectory
equivalence to PlatEMO.
