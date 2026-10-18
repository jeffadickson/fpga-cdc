# Lesson: What the counter clock actually sees

An interactive demo of a 4-bit counter whose bits cross into another clock
domain with no synchronizer.

Open `index.html` in any browser. No build step and no network access are needed.

## What the demo shows

- Each bit switches at its own time (routing skew), and can toggle several times
  before it settles (ringing or metastable bits).
- The counter's clock samples all four bits at each rising edge. Each column of
  the grid is one edge, so you can see the 0/1 values it interprets.
- A column that decodes to a value other than the old or new count is a jump.

## Things to try

1. Binary 7 → 8, skew 200 ps, toggles on. Watch the grid for reads of 15 or 0.
2. Turn toggles off. Jumps remain, because skew alone is enough.
3. Switch to Gray code with toggles off. There are no jumps: one bit changes per
   step, so a sampler sees only the old or new count.
4. Switch Gray on with toggles on. Jumps return. A glitch on a bit that should
   not change, or three toggles on one bit, can produce a non-adjacent code.
   Gray code limits the damage; it does not replace a synchronizer.

## Assumptions and limits

- This is a timing model, not a circuit simulation. The skew range, toggle
  counts and 150 ps bounce window are assumptions.
- The 4,000-run statistics are drawn from a uniform skew distribution.
- For circuit-level evidence, see `tests/cdc/` in this repo.

## Reference

Ginosar, "Metastability and Synchronizers: A Tutorial," IEEE Design & Test, 2011,
p. 29 (bit-by-bit synchronization of a bus).
