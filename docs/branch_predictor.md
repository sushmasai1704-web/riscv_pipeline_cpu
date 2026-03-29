# Branch Predictor Module

**File:** `rtl/branch_predictor.v`  
**Type:** 2-bit saturating counter Branch History Table (BHT) + Branch Target Buffer (BTB)  
**Entries:** 2^INDEX_BITS (default: 256)

## Overview

The branch predictor speculatively redirects the PC at the IF stage — before the branch
is decoded or executed. This eliminates the 2-cycle penalty on correctly predicted branches.
On a misprediction, the pipeline flushes IF/ID and ID/EX and redirects to the correct target.

## Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk` | input | 1 | Clock |
| `rst_n` | input | 1 | Active-low reset |
| `pc` | input | 32 | Current fetch PC (IF stage) |
| `predict_req` | input | 1 | Request a prediction (tie high) |
| `predict_taken` | output | 1 | 1 = predict taken, 0 = not-taken |
| `predict_target` | output | 32 | Predicted branch target address |
| `predict_valid` | output | 1 | 1 = BTB has a valid entry for this PC |
| `ex_pc` | input | 32 | PC of branch resolving in EX stage |
| `ex_branch` | input | 1 | 1 = instruction in EX is a branch/jump |
| `ex_taken` | input | 1 | Actual outcome (1 = taken) |
| `ex_target` | input | 32 | Actual branch target address |
| `ex_valid` | input | 1 | 1 = update is valid this cycle |

## Internal Structure

### Branch History Table (BHT)

256 entries of 2-bit saturating counters, indexed by PC[9:2]:
```
2'b00  Strongly not-taken   saturates here
2'b01  Weakly not-taken
2'b10  Weakly taken
2'b11  Strongly taken       saturates here

Reset state: 2'b01 (Weakly not-taken)
Prediction:  taken if BHT[index][1] == 1
```

### Branch Target Buffer (BTB)

256 entries storing the last known target address for each index, plus a valid bit.
predict_valid is only asserted when btb_valid[index] is set.

## Prediction Logic (Combinational)
```
index = PC[9:2]

if btb_valid[index]:
    predict_valid  = 1
    predict_taken  = BHT[index][1]
    predict_target = BTB[index]
else:
    predict_valid  = 0
    predict_taken  = 0
    predict_target = 0
```

## Update Logic (Sequential)

Triggered when ex_valid && ex_branch:
```
if ex_taken:
    if BHT[ex_index] != 2'b11:  BHT[ex_index]++
else:
    if BHT[ex_index] != 2'b00:  BHT[ex_index]--

BTB[ex_index]       = ex_target
btb_valid[ex_index] = 1
```

## Timing

On a hit:  zero penalty, next instruction fetched from correct path.
On a miss: 2-cycle penalty — IF and ID stages flushed with NOPs.

## Parameter

| Parameter | Default | Effect |
|---|---|---|
| `INDEX_BITS` | 8 | Table size = 2^INDEX_BITS entries |

## Observed Behaviour

On the included test program (2 branches, cold predictor):
```
Branch count     : 2
Mispredictions   : 1
Mispredict rate  : 50.0%
```

Both BHT entries start at 2'b01 (weakly not-taken). The 50% miss rate is
expected on a cold predictor — the counter needs one iteration to warm up.
