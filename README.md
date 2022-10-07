(Naive) Wave Function Collapse
---
A very basic Nim implementation of the 'Wave Function Collapse' constraint solving algorithm.

#### Compilation
After installing nimble (I found choosenim to be the easiest way to install nim)
```
git clone git@github.com:RottenFishbone/nim-wfc.git
cd nim-wfc
nimble run
```

#### Parameters
`let input = ...` in `src/wfc.nim` allows you to provide a sample to build a ruleset.  
`const TILE_SET = [...]` allows you to select the characters to output with.   
**Note:** The number of unique tiles in `input` MUST match the size of `TILE_SET`.  
`const OUTPUT_SIZE = n` allows you to specify the (square) dimensions of the final output. Anything over 50 will take a while.

#### How it works
##### ruleset:
A ruleset is first built using the `input` map. This is done by iterating over each cell in `input` and storing its neighbours into a ruleset by `ruleset[cell_value][direction]`. Each rule is stored in a HashSet to avoid duplication.  
After iterating over ever cell in input, the result will be a `TILE_SETx4` 2D array of hashsets to allow for constraint comparisons during "collapse".

##### collapse:
A map of hashsets is kept for each cell, this represents the possible final tiles of any cell given the current state (i.e. the domain of a cell).
A random cell is chosen to be "collapsed", i.e. domain restricted to a single random value. 

After the inital collapse, we propagate constraints to each neighbour.
This takes the form of iterating over a queue of tiles which had their domain restricted. We pop from the front of the queue and check if the new domain has affected any of the neighbours. If any neighbour has been affected, we add that to the queue as well.
Once the queue is emptied, all cells are back to a state where they conform to the rules.
If any domain is still > 1 then we randomly collapse another one and repeat.

