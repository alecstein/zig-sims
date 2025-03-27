MacOS instructions

```sh
brew install raylib
```

```sh
zig build run
```

or if you want it to be fast,

```sh
zig build -Doptimize=ReleaseFast run
```

<img width="912" alt="Screenshot 2025-03-22 at 12 36 55 PM" src="https://github.com/user-attachments/assets/5d7654ac-c53c-4898-86d1-0819fced7b08" />

# TODOs

Write the total entropy as S_max = S_x_max + S_p_max and find the difference between the distributions to measure S(t).

* For mixing-momenta, just use the expression for delta p_n and integrate out the piston entirely and see if the simulation gives the same thing. you should be able to do this efficiently.
* see if you can find a system this is similar to. is the piston problem dual to another?
