# -- Randomization --
import std/random
# -- Datastructures -- 
import std/sets
import std/deques
import std/sequtils

# --- Parameters ---
const TILE_SET = [' ', '~', '#'] 
const OUTPUT_SIZE = 30

# Calculate the number of possible tiles
const NUM_TILES = TILE_SET.len()

# --- Declare all custom types used in this program ---
type
    # Direction is a 0-based set of labels of neighbours
    Direction* = enum
        UP=0, DOWN, LEFT, RIGHT

    # Ruleset is an easily indexable set of valid adjacencies
    # i.e. ruleset[0][UP] is a hashset of tiles that are allowed above tile 0
    Ruleset* = ref 
        seq[array[int(low(Direction))..int(high(Direction)), HashSet[int]]]
     
    # Map is a 2D datastore, used to allow for convenience function
    Map[T] = ref 
        seq[seq[T]]
       
    # Point is a 2D vector
    Point* = object
        x: int 
        y: int


##
## Write a string to stdout without a newline character
##
template print(s: varargs[string, `$`]) =
  for x in s:
    stdout.write(x)

## 
## Initializes a map to a w*h 2D sequence with every value being `initVal`
##
proc initTo[T](self: Map[T], w: int, h: int, initVal: T) =
    self[] = newSeq[seq[T]](h)
    for y, row in self[]:
        for _ in 0..w-1:
            self[y].add(initVal)
##
## Pretty prints a map to stdout
##
proc echo(self: Map) = 
    for y in self[]:
        for x in y:
            print(x, ' ')
        echo("")

##
## Gets the length of a Map
##
proc len(self: Map): int =
    if self[].len() == 0:
        return 0
    else:
        return self[].len() * self[0].len()


##
## Builds a sequence of neighbours as a tuple of location and direction
##
proc getNbrIds[T](self: Map[T], p: Point): seq[(Point, Direction)] = 
    var nbrs: seq[(Point, Direction)] = @[]
    
    if p.x > 0:
        nbrs.add((Point(x: p.x-1, y: p.y), LEFT))
    if p.x < self[0].len()-1:
        nbrs.add((Point(x: p.x+1, y: p.y), RIGHT))
    if p.y > 0:
        nbrs.add((Point(x: p.x, y: p.y-1), UP))
    if p.y < self[].len()-1:
        nbrs.add((Point(x: p.x, y: p.y+1), DOWN))
    
    return nbrs

##
## Gets a value from a map using a Point
##
proc getCellVal[T](self: Map[T], p: Point): T =
    return self[p.y][p.x]


##jdumouch
## Pretty prints the ruleset to stdout
##
proc echo(self: Ruleset) =
    for i, rules in self[]:
        echo("Tile ", i)
        for j, dir in rules:
            print(Direction(j), "\t[ ")
            for rule in dir:
                print(rule, " ")
            echo("]")
        echo("")

##
## Builds a ruleset using a sample map as input
##
## Rulesets are used to perform a wave function collapse 
##
proc buildFromSample(self: Ruleset, map: Map[int]) =
    self[] = newSeq[array[0..3, HashSet[int]]](NUM_TILES)
    for y, row in map[]:
        for x, refTile in row:
            let nbrs = map.getNbrIds(Point(x:x,y:y))
            for (loc, dir) in nbrs:
                let adjTile = map.getCellVal(loc)
                self[refTile][int(dir)].incl(adjTile)

when isMainModule:
    randomize() # Seed the randomizer

    echo("\nUsing input:")
    let input = new Map[int];
    input[] = @[@[1, 1, 1, 1, 1, 1, 1],
                @[1, 0, 0, 1, 2, 2, 1],
                @[1, 0, 0, 1, 2, 2, 1],
                @[1, 1, 1, 1, 1, 1, 1]]
    echo(input)

    echo("\nBuilding ruleset:")
    var ruleset = new Ruleset;
    ruleset.buildFromSample(input)
    echo(ruleset)

    # Domains stores the possible states ( the `superpositions` of each cell)
    var domains = new Map[HashSet[int]]
    
    # Create a full domain and initialize each domain value to it
    let fullSet: HashSet[int] = (0..NUM_TILES-1).toSeq().toHashSet()
    domains.initTo(OUTPUT_SIZE, OUTPUT_SIZE, fullSet) 
    
    echo("\nCollapsing output:")
    block collapsing:
        while true:
            # Iterate over the array, finding the lowest entropy value
            # This doubles as a check that collapse is complete
            # Another Note: Each rule _should_ be weighted, affecting entropy
            var minEntropy = high(int)
            for row in domains[]:
                for cell in row:
                    if cell.len() == 1: continue
                    if cell.len() == 0: echo("Invalid domain found") # OOPS
                    minEntropy = (if minEntropy < cell.len(): minEntropy else: cell.len())
            
            # No entropy other than 1 is found (collapsed state)
            if minEntropy == high(int):
                break collapsing

            # ==== Pick an element matching lowest entropy ====
            # Invariant: At least one cell is len == minEntropy
            # Note: a random cell of lowest entropy should be chosen, not the first as I have
            var selectedPos: Point
            for y, row in domains[]:
                for x, cell in row:
                    if cell.len() == minEntropy:
                        selectedPos = Point(x:x, y:y)
            
            # ===== Collapse lowest entropy into random state =====
            let choice = domains.getCellVal(selectedPos).toSeq()[rand(minEntropy-1)]
            domains[selectedPos.y][selectedPos.x] = @[choice].toHashSet()

            # ===== Propagate the changes ======
            let nbrs = domains.getNbrIds(selectedPos)
            var queue: Deque[Point] = initDeque[Point]()
            queue.addLast(selectedPos)
            
            # Iterate over each cell in the queue 
            # Check the neighbours and adjust their domains
            while queue.len() > 0:
                # Pop the first entry in the queue and check if its neighbours need adjusting
                let cell = queue.popFirst()
                let domain = domains.getCellVal(cell)
                let nbrs = domains.getNbrIds(cell)
                
                # We iterate over each tile in `cell`'s domain, unioning together what is allowed to be
                # adjacent in the neighbours direction 
                # e.g. if we are checking RIGHT neighbour, we iterate over all tiles in `cell` domain.
                #       suppose cell domain = { 0, 1 }
                #       if ruleset[0][RIGHT] = {1}
                #       and ruleset[1][RIGHT] = {2}
                #       The allowed tiles to the right are {1, 2}
                #       By intersecting {1,2} with RIGHT's domain, we narrow RIGHT's domain
                #       down to AT LEAST {1,2} but also potentially less, depending what it was
                for (nbrPos, nbrDir) in nbrs:
                    # nbrConstraint will store the union of all allowed tiles defined in rules
                    var nbrConstraint: HashSet[int] = initHashSet[int]()
                    # Check each rule for each tile in `cell` in neighbours direction
                    for tile in domain:
                        let ruleDomain = ruleset[tile][int(nbrDir)]
                        nbrConstraint = ruleDomain.union(nbrConstraint)
                    # Get the intersection of the allowed domain and current domain
                    let nbrDomain = domains.getCellVal(nbrPos) 
                    let newDomain = nbrDomain.intersection(nbrConstraint)
                    
                    # If the intersection has no tiles, we need to backtrack or abort
                    if newDomain.len() == 0:
                        # We are going to abort so I don't have to implement backtracking
                        echo("Invalid state. Aborting.")
                        break collapsing

                    # If the domain actually changed, we need to check nbr's neighbours now
                    if newDomain != nbrDomain:
                        domains[nbrPos.y][nbrPos.x] = newDomain
                        queue.addLast(nbrPos)
    
    # Use TILE_SET as a lookup to build an output from all the collapsed domains
    # Invariant: All domains are length 1
    var output = new Map[char];
    output.initTo(OUTPUT_SIZE,OUTPUT_SIZE,' ')
    for y, row in domains[]:
        for x, cell in row:
            let cellVal: int = cell.toSeq()[0]
            output[y][x] = TILE_SET[cellVal]

    output.echo()
