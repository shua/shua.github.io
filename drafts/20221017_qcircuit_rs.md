<pmeta id="created">2022-10-17</pmeta>
<pmeta id="title">Quantum Circuits in Rust</pmeta>

I spent a little time trying to model quantum circuits as rust types.

Quantum circuits are made up of qubits, which can be represented as points in C<sup>2</sup>.
I chose to model a complex number with two `f64`s
```
#[derive(Clone, Copy)]
struct C128(f64, f64);
```
Conceptually, you should thing of `C128(a, b)` as encoding `a + bi` (where naturally `i = \sqrt{-1}`).
We'll need to be able to multiply, add and negate these, and the implementation of those for my `C128` is not very interesting:
```
// this is a+bi + c+di = (a+c) + (b+d)i
impl Add for C128 {
	type Output = C128;
	fn add(self, rhs: C128) -> C128 {
		C128(self.0+rhs.0, self.1+rhs.1)
	}
}

// (a+bi) * (c+di) = ac + (bc)i + (ad)i + (bd)ii = (ac - bd) + (bc + ad)i
impl Mul for C128 {
	type Output = C128;
	fn add(self, rhs: C128) -> C128 {
		C128(self.0*rhs.0 - self.1*rhs.1, self.0*rhs.1 + self.1*rhs.0)
	}
}

// etc for - (a+bi) = (-a) + (-b)i
```

Now, qubits can be encoded as either a matrix with two complex numbers, or as the sum of two basis vectors in `C^2` space.
I've seen this represented in literature in what's known as "bra-ket notation" like `|q> = a|0> + b|1>`.
I can encode this as a vector in `C^2` using two `C128` values.
```
struct QBit(C128, C128)
```
where `QBit(a, b)` is encoding `a|0> + b|1>`.


Lastly a quantum circuit works on qubits, and logical quantum circuits generally use a set of common operations on these qubits which we'll represent as gates in a circuit diagram.
These gates can be combined in series or in parallel in a quantum circuit.
Often the diagrams used look something like below:
```
     A     B     C   D    E
    +-+  +----+
q1 -|H|--|    |-----(X)---------
    +-+  |CNOT|      |  +----+
q2 ------|    |-. .--o--| \. |==
         +----+  \   |  +----+
q3 -------------' '--o----------
```
- you cannot copy values of qubits, only swap them
- even more strictly, all gates have the same number of output as input qubits
- some gates work on single qubits, some on two qubits, and some on more

What's not visible, but is part of the literature, is that gates must be unitary matrices.
It's useful for me, because I only have to encode square matrix multiplication, not arbitrary `n` by `m`.
What's also not visible, is that qubit state can be entagled, so, for instance, the output of of qubits from the section marked `B` may be dependent on `q3` even though `q3` wasn't involved in any gates in `A` or `B`.

This all means that the state of the system can be described as the entangled state of all three qubits.
Maybe more concretely, we'll need a `2^N` by `2^N` matrix to represent each vertical slice of gates, which can be thought of as a mapping for the `N` previous qubit states to the `N` next qubit states.
It's mapping every combination of 1 and 0 for `N` states, which is why it's `2^N` by `2^N`.

